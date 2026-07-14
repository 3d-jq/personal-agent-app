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
                result.success(true)
            } catch (e: Exception) {
                result.error("INIT_FAILED", e.message, null)
            }
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
                    result.error("START_FAILED", r.exceptionOrNull()?.message, null)
                    return@launch
                }
                val (session, _) = r.getOrThrow()
                sessions[sessionId] = session
                startReader(sessionId, session)
                result.success(true)
            } catch (e: Exception) {
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
