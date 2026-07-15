package com.example.personal_agent_app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.view.View
import android.webkit.CookieManager
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
        // 默认桌面版：覆盖为 PC UA，并启用宽视口+概览模式，使 PC 网页在手机屏上自适应缩放
        wv.settings.userAgentString = DESKTOP_USER_AGENT
        wv.settings.useWideViewPort = true
        wv.settings.loadWithOverviewMode = true
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
                val cssPath = call.argument<String>("cssPath") ?: ""
                runOnWebView {
                    val sel = if (cssPath.isNotEmpty()) {
                        val safe = cssPath.replace("'", "\\'")
                        "document.querySelector('[data-bref=\"$ref\"]')||document.querySelector('$safe')"
                    } else {
                        "document.querySelector('[data-bref=\"$ref\"]')"
                    }
                    webView.evaluateJavascript(
                        "var e=$sel; if(e){e.focus();e.scrollIntoView({block:'center',inline:'center'}); e.click(); 'clicked'}else{'ref_not_found:$ref'}"
                    ) { result.success(it ?: "ok") }
                }
            }
            "type" -> {
                val ref = call.argument<String>("ref") ?: ""
                val text = call.argument<String>("text") ?: ""
                val cssPath = call.argument<String>("cssPath") ?: ""
                runOnWebView {
                    val sel = if (cssPath.isNotEmpty()) {
                        val safe = cssPath.replace("'", "\\'")
                        "var e=document.querySelector('[data-bref=\"$ref\"]')||document.querySelector('$safe');"
                    } else {
                        "var e=document.querySelector('[data-bref=\"$ref\"]');"
                    }
                    val js =
                        sel +
                            "if(!e) return 'ref_not_found:$ref';" +
                            "var d=Object.getOwnPropertyDescriptor(Object.getPrototypeOf(e),'value');" +
                            "if(d&&d.set) d.set.call(e,'${escapeJs(text)}');" +
                            "else e.value='${escapeJs(text)}';" +
                            "e.focus();" +
                            "e.dispatchEvent(new Event('input',{bubbles:true}));" +
                            "e.dispatchEvent(new Event('change',{bubbles:true}));'typed'"
                    webView.evaluateJavascript(js) { result.success(it ?: "ok") }
                }
            }
            "select" -> {
                val ref = call.argument<String>("ref") ?: ""
                val value = call.argument<String>("value") ?: ""
                val cssPath = call.argument<String>("cssPath") ?: ""
                runOnWebView {
                    val sel = if (cssPath.isNotEmpty()) {
                        val safe = cssPath.replace("'", "\\'")
                        "document.querySelector('[data-bref=\"$ref\"]')||document.querySelector('$safe')"
                    } else {
                        "document.querySelector('[data-bref=\"$ref\"]')"
                    }
                    val escaped = value.replace("'", "\\'").replace("\\", "\\\\")
                    webView.evaluateJavascript(
                        "var e=$sel; if(!e||e.tagName!=='SELECT') return 'ref_not_select:$ref';" +
                        "var opts=e.options; for(var i=0;i<opts.length;i++){" +
                        "if(opts[i].value==='$escaped'||opts[i].text==='$escaped'){" +
                        "e.selectedIndex=i; e.dispatchEvent(new Event('change',{bubbles:true}));" +
                        "return 'selected'}}" +
                        "return 'option_not_found:$escaped'"
                    ) { result.success(it ?: "ok") }
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
                        val cssPath = (f["cssPath"] ?: "").toString()
                        val eSel = if (cssPath.isNotEmpty()) {
                            val safe = cssPath.replace("'", "\\'")
                            "document.querySelector('[data-bref=\"$ref\"]')||document.querySelector('$safe')"
                        } else {
                            "document.querySelector('[data-bref=\"$ref\"]')"
                        }
                        sb.append(
                            "var e$idx=$eSel;" +
                                "if(e$idx){" +
                                "var d=Object.getOwnPropertyDescriptor(Object.getPrototypeOf(e$idx),'value');" +
                                "if(d&&d.set) d.set.call(e$idx,'${escapeJs(text)}');" +
                                "else e$idx.value='${escapeJs(text)}';" +
                                "e$idx.focus();" +
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
                val cssPath = call.argument<String>("cssPath") ?: ""
                runOnWebView {
                    val sel = if (cssPath.isNotEmpty()) {
                        val safe = cssPath.replace("'", "\\'")
                        "var e=document.querySelector('[data-bref=\"$ref\"]')||document.querySelector('$safe');"
                    } else {
                        "var e=document.querySelector('[data-bref=\"$ref\"]');"
                    }
                    val js =
                        sel +
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
            "setUserAgent" -> {
                val ua = call.argument<String>("ua") ?: ""
                runOnWebView {
                    webView.settings.userAgentString = if (ua.isEmpty()) DESKTOP_USER_AGENT else ua
                    result.success(true)
                }
            }
            "setViewport" -> {
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                runOnWebView {
                    if (width > 0 && height > 0) {
                        val js = "(function(){var m=document.querySelector('meta[name=viewport]');" +
                            "if(!m){m=document.createElement('meta');m.name='viewport';" +
                            "document.head.appendChild(m);}m.content='width=$width,height=$height,initial-scale=1';" +
                            "document.documentElement.style.width='${width}px';return 'ok';})()"
                        webView.evaluateJavascript(js) { result.success(it ?: "ok") }
                    } else {
                        result.success("width/height 必须大于 0")
                    }
                }
            }
            "getCookies" -> {
                val url = call.argument<String>("url")?.takeIf { it.isNotEmpty() } ?: webView.url ?: ""
                runOnWebView {
                    val cookie = CookieManager.getInstance().getCookie(url)
                    result.success(cookie ?: "")
                }
            }
            "setCookies" -> {
                val url = call.argument<String>("url")?.takeIf { it.isNotEmpty() } ?: webView.url ?: ""
                val cookies = call.argument<String>("cookies") ?: ""
                runOnWebView {
                    val cm = CookieManager.getInstance()
                    cookies.split(";").forEach { pair ->
                        val c = pair.trim()
                        if (c.isNotEmpty()) cm.setCookie(url, c)
                    }
                    cm.flush()
                    result.success(true)
                }
            }
            "screenshot" -> runOnWebView {
                var w = webView.width
                var h = webView.height
                if (w <= 0 || h <= 0) {
                    // WebView 尚未完成布局（如刚创建或从未显示过），先强制测量布局再截图。
                    // 使用常见的移动端视口尺寸（1080×1920）作为默认值，若仍需定制请用 browser_set_viewport。
                    webView.measure(
                        View.MeasureSpec.makeMeasureSpec(1080, View.MeasureSpec.AT_MOST),
                        View.MeasureSpec.makeMeasureSpec(1920, View.MeasureSpec.AT_MOST),
                    )
                    webView.layout(0, 0, webView.measuredWidth, webView.measuredHeight)
                    w = webView.measuredWidth
                    h = webView.measuredHeight
                    if (w <= 0 || h <= 0) {
                        result.error(
                            "screenshot_failed",
                            "WebView 尚未布局（宽高无效），请先打开浏览器并加载页面",
                            null,
                        )
                        return@runOnWebView
                    }
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
        /** 桌面版 Chrome UA（不含 Mobile/Android 字样），让网站返回 PC 布局而非移动版 */
        private const val DESKTOP_USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        /** 快照脚本：给可交互元素打 data-bref 并返回结构化清单（对齐 Playwright）。 */
        const val SNAPSHOT_JS = """
(function(){
  try {
    function cssPath(el){
      if(!el||el===document.body) return 'body';
      if(el.id) return '#'+(CSS&&CSS.escape?CSS.escape(el.id):el.id);
      var p=[],c=el;
      while(c&&c!==document.body&&c!==document.documentElement){
        var t=c.tagName.toLowerCase();
        var pa=c.parentElement;
        if(!pa) break;
        var s=Array.from(pa.children).filter(function(x){return x.tagName===c.tagName;});
        p.unshift(t+':nth-of-type('+(s.indexOf(c)+1)+')');
        c=pa;
      }
      return p.join(' > ');
    }
    var SEL = 'a,button,input,textarea,select,[role=button],[contenteditable=true]';
    var vh = window.innerHeight || document.documentElement.clientHeight;
    var vw = window.innerWidth || document.documentElement.clientWidth;
    var els = document.querySelectorAll(SEL);
    var out = [];
    for (var i = 0; i < els.length; i++) {
      var e = els[i];
      e.setAttribute('data-bref', i);
      var r = e.getBoundingClientRect();
      var cs = getComputedStyle(e);
      var inView = (r.top < vh) && (r.bottom > 0) && (r.left < vw) && (r.right > 0);
      var visible = (e.offsetWidth > 0) && (e.offsetHeight > 0) &&
          (cs.visibility !== 'hidden') && (cs.display !== 'none') && (cs.opacity !== '0') && inView;
      var disabled = (e.disabled === true) || e.hasAttribute('disabled');
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
        x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height),
        inViewport: inView, visible: visible, disabled: disabled,
        cssPath: cssPath(e)
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
