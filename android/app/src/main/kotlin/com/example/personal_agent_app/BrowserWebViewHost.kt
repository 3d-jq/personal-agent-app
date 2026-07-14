package com.example.personal_agent_app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 浏览器自动化宿主：承载单个 [WebView]，并通过 MethodChannel 暴露
 * Playwright 风格的工具面（loadUrl / snapshot / click / type / ...）。
 *
 * 设计要点：
 * - 整个 app 生命周期内只持有一个共享 WebView 实例；
 * - 该实例同时被 [BrowserWebViewFactory] 以 PlatformView 形式嵌入 Flutter UI
 *   （可见的浏览器浮层），并被 MethodChannel 驱动（Agent 自动化）；
 * - 快照(snapshot)给页面可交互元素打 `data-bref` 属性，click/type 据此定位。
 */
class BrowserWebViewHost(context: Context) {
    val webView: WebView
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        webView = createWebView(context)
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun createWebView(context: Context): WebView {
        val wv = WebView(context)
        wv.settings.javaScriptEnabled = true
        wv.settings.domStorageEnabled = true
        wv.settings.allowFileAccess = true
        wv.settings.databaseEnabled = true
        wv.webViewClient = WebViewClient()
        wv.webChromeClient = WebChromeClient()
        return wv
    }

    /** 处理来自 Dart 侧的浏览器工具调用。 */
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadUrl" -> {
                val url = call.argument<String>("url") ?: ""
                runOnWebView {
                    webView.loadUrl(url)
                    result.success(true)
                }
            }
            "currentUrl" -> runOnWebView {
                // WebView.url 必须在主线程读取；未加载时为 null。
                result.success(webView.url ?: "")
            }
            "snapshot" -> {
                runOnWebView {
                    webView.evaluateJavascript(SNAPSHOT_JS) { value ->
                        result.success(value ?: "[]")
                    }
                }
            }
            "click" -> {
                val ref = call.argument<String>("ref") ?: ""
                runOnWebView {
                    webView.evaluateJavascript(
                        "var e=document.querySelector('[data-bref=\"$ref\"]'); if(e){e.click(); 'clicked'}else{'ref_not_found:$ref'}"
                    ) { result.success(it ?: "ok") }
                }
            }
            "type" -> {
                val ref = call.argument<String>("ref") ?: ""
                val text = call.argument<String>("text") ?: ""
                runOnWebView {
                    val js =
                        "var e=document.querySelector('[data-bref=\"$ref\"]');" +
                            "if(e){e.value='${escapeJs(text)}';" +
                            "e.dispatchEvent(new Event('input',{bubbles:true}));" +
                            "e.dispatchEvent(new Event('change',{bubbles:true}));'typed'}else{'ref_not_found:$ref'}"
                    webView.evaluateJavascript(js) { result.success(it ?: "ok") }
                }
            }
            "fillForm" -> {
                val fields = call.argument<List<Map<String, Any?>>>("fields") ?: emptyList()
                runOnWebView {
                    val sb = StringBuilder()
                    sb.append("(function(){")
                    for ((idx, f) in fields.withIndex()) {
                        val ref = f["ref"]?.toString() ?: continue
                        val text = (f["text"] ?: "").toString()
                        sb.append(
                            "var e$idx=document.querySelector('[data-bref=\"$ref\"]');" +
                                "if(e$idx){e$idx.value='${escapeJs(text)}';" +
                                "e$idx.dispatchEvent(new Event('input',{bubbles:true}));}"
                        )
                    }
                    sb.append("return 'ok';})()")
                    webView.evaluateJavascript(sb.toString()) { result.success(it ?: "ok") }
                }
            }
            "evaluateJs" -> {
                val code = call.argument<String>("code") ?: ""
                runOnWebView {
                    webView.evaluateJavascript(code) { result.success(it ?: "null") }
                }
            }
            "pressKey" -> {
                val ref = call.argument<String>("ref") ?: ""
                val key = call.argument<String>("key") ?: "Enter"
                runOnWebView {
                    val js =
                        "var e=document.querySelector('[data-bref=\"$ref\"]');" +
                            "if(e){e.dispatchEvent(new KeyboardEvent('keydown',{key:'$key',bubbles:true}));" +
                            "e.dispatchEvent(new KeyboardEvent('keyup',{key:'$key',bubbles:true}));'pressed'}else{'ref_not_found:$ref'}"
                    webView.evaluateJavascript(js) { result.success(it ?: "ok") }
                }
            }
            "back" -> runOnWebView {
                if (webView.canGoBack()) webView.goBack()
                result.success(true)
            }
            "close" -> runOnWebView {
                webView.loadUrl("about:blank")
                result.success(true)
            }
            "screenshot" -> runOnWebView {
                val w = webView.width
                val h = webView.height
                if (w <= 0 || h <= 0) {
                    // WebView 尚未完成布局（如刚创建或从未显示过），无法截图。
                    result.error(
                        "screenshot_failed",
                        "WebView 尚未布局（宽高无效），请先打开浏览器并加载页面",
                        null,
                    )
                    return@runOnWebView
                }
                val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                // 虚拟显示合成（AndroidView）下，WebView 默认走硬件层，draw 可能抓不到内容。
                // 临时切到软件层可保证 draw 把页面像素绘制到我们提供的 Canvas 上。
                val prevLayer = webView.layerType
                webView.setLayerType(WebView.LAYER_TYPE_SOFTWARE, null)
                try {
                    webView.draw(canvas)
                } finally {
                    webView.setLayerType(prevLayer, null)
                }
                val stream = java.io.ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                val base64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                result.success(base64)
            }
            "tabs" -> result.success("[]")
            "resize", "waitFor", "consoleMessages", "networkRequests", "drag", "upload", "handleDialog" ->
                result.success("[]")
            else -> result.notImplemented()
        }
    }

    /** WebView 操作必须在主线程执行。 */
    private fun runOnWebView(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }

    companion object {
        /** 快照脚本：给可交互元素打 data-bref 并返回结构化清单（对齐 Playwright）。 */
        const val SNAPSHOT_JS = """
(function(){
  try {
    var SEL = 'a,button,input,textarea,select,[role=button],[contenteditable=true]';
    var els = document.querySelectorAll(SEL);
    var out = [];
    for (var i = 0; i < els.length; i++) {
      var e = els[i];
      e.setAttribute('data-bref', i);
      var r = e.getBoundingClientRect();
      var txt = (e.innerText || e.value || e.getAttribute('aria-label') || e.getAttribute('title') || '').toString().slice(0, 100);
      out.push({
        ref: String(i),
        tag: e.tagName.toLowerCase(),
        text: txt,
        type: e.type || '',
        name: e.name || '',
        id: e.id || '',
        placeholder: e.placeholder || '',
        href: e.href || '',
        value: e.value || '',
        x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height)
      });
    }
    return JSON.stringify(out);
  } catch (err) { return '[]'; }
})()
"""

        /** 转义写入 JS 字符串字面量的文本。 */
        fun escapeJs(s: String): String =
            s.replace("\\", "\\\\")
                .replace("'", "\\'")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "")
    }
}

/**
 * 将共享的 [BrowserWebViewHost.webView] 以 PlatformView 形式暴露给 Flutter，
 * viewType = [VIEW_TYPE]。Flutter 侧用 AndroidView 嵌入可见的浏览器浮层。
 */
class BrowserWebViewFactory(private val host: BrowserWebViewHost) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return object : PlatformView {
            override fun getView() = host.webView
            override fun dispose() {
                // 共享 WebView 由 BrowserWebViewHost 持有，生命周期与应用一致，此处不销毁。
            }
        }
    }

    companion object {
        const val VIEW_TYPE = "browser_webview"
    }
}
