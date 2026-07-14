package com.example.personal_agent_app

import android.content.Context
import com.ai.assistance.operit.terminal.TerminalManager
import com.ai.assistance.operit.terminal.TerminalSession
import com.ai.assistance.operit.terminal.provider.type.HiddenExecResult
import com.ai.assistance.operit.terminal.provider.type.LocalTerminalProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap

/**
 * 终端沙箱宿主：借 OperitTerminalCore 在用户态 PRoot + Ubuntu 环境运行命令。
 *
 * - 环境准备委托 [TerminalManager.initializeEnvironment]（解包 rootfs、生成 common.sh、
 *   建立 busybox/proot 符号链接），与 Operit 行为一致、零逻辑重写。
 * - 可见交互终端用 [LocalTerminalProvider.startSession] 拿到原始 stdout/stdin 流，
 *   字节经 [EventChannel] 推给 Flutter 侧 xterm 渲染。
 * - AI 工具用的无头执行走 [LocalTerminalProvider.executeHiddenCommand]，返回
 *   [HiddenExecResult]（命令输出 + 退出码），不占用可见 PTY。
 */
class TerminalHost(
    private val context: Context,
    messenger: BinaryMessenger
) {
    companion object {
        const val CHANNEL = "com.example/terminal"
        const val EVENTS = "com.example/terminal/events"
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var provider: LocalTerminalProvider? = null
    private val sessions = ConcurrentHashMap<String, TerminalSession>()
    private val readJobs = ConcurrentHashMap<String, Job>()
    private var eventSink: EventChannel.EventSink? = null

    /** 用于把原生诊断日志推回 Dart（onNativeLog）。 */
    private val outboundChannel = MethodChannel(messenger, CHANNEL)

    init {
        EventChannel(messenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            }
        )
        // 把终端环境初始化的报错/警告经此桥推到 App 统一日志（运行日志页）。
        TerminalManager.nativeLogBridge = { level, _, message ->
            forwardNativeLog(level, message)
        }
    }

    /**
     * 把原生诊断日志经 [outboundChannel] 推给 Dart。Dart 侧 [TerminalChannel] 注册了
     * onNativeLog handler 并路由到 [LogService]。若 Dart 尚未注册（极早调用）则静默丢弃。
     */
    private fun forwardNativeLog(level: String, message: String) {
        try {
            outboundChannel.invokeMethod(
                "onNativeLog",
                mapOf("level" to level, "tag" to "TerminalNative", "message" to message)
            )
        } catch (_: Exception) {
            // Dart 端未注册 handler 或通道异常：不影响主流程，仅损失该条日志。
        }
    }

    /** 实际会被宿主 exec 的 bash 文件（已改放 /data/local/tmp 以绕过 noexec）。 */
    private fun execBashFile(): File {
        val tm = TerminalManager.getInstance(context)
        return File(tm.execBashPath())
    }

    /** 真正尝试 exec 一次 bash -c 'exit 0'，直接验证宿主能否执行（捕获 noexec/SELinux 拒绝）。 */
    private fun probeBashExec(): String {
        return try {
            val p = ProcessBuilder(execBashFile().absolutePath, "-c", "exit 0")
                .directory(context.filesDir)
                .redirectErrorStream(true)
                .start()
            val rc = p.waitFor()
            "execProbe=ok(exit=$rc)"
        } catch (e: Exception) {
            "execProbe=FAIL:${e.message ?: e.javaClass.simpleName}"
        }
    }

    /** 生成环境未就绪 / 初始化失败时的磁盘状态诊断，便于在 App 日志里直接看清根因。 */
    private fun diagnoseEnv(): String {
        val bash = execBashFile()
        val parent = bash.parentFile
        val busybox = File(parent, "busybox")
        val proot = File(parent, "proot")
        val loader = File(parent, "loader")
        val common = File(context.filesDir, "common.sh")
        val nativeDir = File(context.applicationInfo.nativeLibraryDir)
        val sos = nativeDir.listFiles()
            ?.filter { it.name.endsWith(".so") }
            ?.joinToString(",") { it.name } ?: "(无法读取)"
        return "binDir=${parent.absolutePath} bash(exists=${bash.exists()},exec=${bash.canExecute()}) " +
            "busybox=${busybox.exists()} proot=${proot.exists()} loader=${loader.exists()} " +
            "common.sh=${common.exists()} | ${probeBashExec()} | nativeLib(.so): $sos"
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensureReady" -> ensureReady(result)
            "start" -> startSession(result, call.arguments as? Map<String, Any?>)
            "write" -> writeInput(result, call.arguments as? Map<String, Any?>)
            "exec" -> execHidden(result, call.arguments as? Map<String, Any?>)
            "close" -> closeSession(result, call.arguments as? Map<String, Any?>)
            else -> result.notImplemented()
        }
    }

    private fun ensureReady(result: MethodChannel.Result) {
        scope.launch {
            try {
                TerminalManager.getInstance(context).initializeEnvironment()
                if (provider == null) provider = LocalTerminalProvider(context)
                // 返回真实状态 + 磁盘诊断：bash 软链/复制是否成功 + common.sh 是否存在的
                // 现场信息，避免 Operit 静默吞掉软链失败后误报"就绪"。浮层/工具直接展示诊断，
                // 不必再翻运行日志。
                val ready = envReallyReady()
                val diag = diagnoseEnv()
                if (!ready) {
                    forwardNativeLog("W", "终端未就绪: $diag")
                }
                result.success(mapOf("ready" to ready, "diag" to diag))
            } catch (e: Exception) {
                val diag = "INIT_FAILED: ${e.message}\n${diagnoseEnv()}"
                forwardNativeLog("E", diag)
                result.success(mapOf("ready" to false, "diag" to diag))
            }
        }
    }

    /** 真实验证沙箱可用：binDir/bash 存在且可执行、common.sh 存在，且宿主能真正 exec 它。 */
    private fun envReallyReady(): Boolean {
        val bash = execBashFile()
        val common = File(context.filesDir, "common.sh")
        if (!(bash.exists() && bash.canExecute() && common.exists())) return false
        // 关键：canExecute() 只检查权限位，不校验 noexec/SELinux。必须真 exec 一次，
        // 否则会出现「显示就绪但执行报 Permission denied」的假阳性。
        return try {
            val p = ProcessBuilder(bash.absolutePath, "-c", "exit 0")
                .directory(context.filesDir)
                .redirectErrorStream(true)
                .start()
            val rc = if (p.waitFor() == 0) true else false
            rc
        } catch (_: Exception) {
            false
        }
    }

    private fun startSession(result: MethodChannel.Result, args: Map<String, Any?>?) {
        val sessionId = (args?.get("sessionId") as? String) ?: "main"
        scope.launch {
            try {
                TerminalManager.getInstance(context).initializeEnvironment()
                if (provider == null) provider = LocalTerminalProvider(context)
                val r = provider!!.startSession(sessionId)
                if (r.isFailure) {
                    forwardNativeLog("E", "START_FAILED: ${r.exceptionOrNull()?.message}\n${diagnoseEnv()}")
                    result.error("START_FAILED", r.exceptionOrNull()?.message, null)
                    return@launch
                }
                val (session, _) = r.getOrThrow()
                sessions[sessionId] = session
                startReader(sessionId, session)
                result.success(true)
            } catch (e: Exception) {
                forwardNativeLog("E", "START_FAILED: ${e.message}\n${diagnoseEnv()}")
                result.error("START_FAILED", e.message, null)
            }
        }
    }

    private fun startReader(sessionId: String, session: TerminalSession) {
        val job = scope.launch {
            val buffer = ByteArray(8192)
            try {
                while (isActive) {
                    val count = session.stdout.read(buffer)
                    if (count < 0) break
                    if (count > 0) {
                        val chunk = buffer.copyOf(count)
                        eventSink?.success(chunk)
                    }
                }
            } catch (_: Exception) {
                // 进程结束 / 流关闭，正常退出
            }
        }
        readJobs[sessionId] = job
    }

    private fun writeInput(result: MethodChannel.Result, args: Map<String, Any?>?) {
        val sessionId = (args?.get("sessionId") as? String) ?: "main"
        val data = (args?.get("data") as? String) ?: ""
        try {
            val session = sessions[sessionId]
            if (session == null) {
                result.error("NO_SESSION", "Session not started: $sessionId", null)
                return
            }
            session.stdin.write(data.toByteArray(StandardCharsets.UTF_8))
            session.stdin.flush()
            result.success(true)
        } catch (e: Exception) {
            result.error("WRITE_FAILED", e.message, null)
        }
    }

    private fun execHidden(result: MethodChannel.Result, args: Map<String, Any?>?) {
        val command = (args?.get("command") as? String) ?: ""
        val timeoutMs = (args?.get("timeoutMs") as? Number)?.toLong() ?: 30000L
        val key = (args?.get("key") as? String) ?: "agent_exec"
        scope.launch {
            try {
                TerminalManager.getInstance(context).initializeEnvironment()
                if (provider == null) provider = LocalTerminalProvider(context)
                val r: HiddenExecResult = provider!!.executeHiddenCommand(command, key, timeoutMs)
                val map = mapOf(
                    "output" to r.output,
                    "exitCode" to r.exitCode,
                    "state" to r.state.name,
                    "error" to r.error
                )
                result.success(map)
            } catch (e: Exception) {
                forwardNativeLog("E", "EXEC_FAILED: ${e.message}\n${diagnoseEnv()}")
                result.error("EXEC_FAILED", e.message, null)
            }
        }
    }

    private fun closeSession(result: MethodChannel.Result, args: Map<String, Any?>?) {
        val sessionId = (args?.get("sessionId") as? String) ?: "main"
        scope.launch {
            try {
                provider?.closeSession(sessionId)
                sessions.remove(sessionId)
                readJobs.remove(sessionId)?.cancel()
                result.success(true)
            } catch (e: Exception) {
                result.error("CLOSE_FAILED", e.message, null)
            }
        }
    }

    fun dispose() {
        scope.cancel()
        sessions.clear()
        readJobs.clear()
    }
}
