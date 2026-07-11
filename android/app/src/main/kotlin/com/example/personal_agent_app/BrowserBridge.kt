package com.example.personal_agent_app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import java.io.ByteArrayOutputStream

/**
 * 后台无头 WebView，通过MethodChannel供Flutter调用。
 *
 * 启动一个带Looper的后台线程，在其中创建WebView，
 * 支持：导航、JS执行、截屏、提取页面信息。
 * 每会话一个实例，关闭时销毁WebView及线程。
 */
class BrowserBridge {
    private var webView: WebView? = null
    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private val jsResult = java.util.concurrent.ConcurrentHashMap<Int, String>()
    private var jsId = 0

    val isActive: Boolean get() = webView != null

    /** 在后台线程创建WebView */
    fun create() {
        if (webView != null) return
        thread = HandlerThread("BrowserWebView").apply { start() }
        handler = Handler(thread!!.looper)
        handler!!.post {
            webView = WebView(android.app.ApplicationContext()).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.loadWithOverviewMode = true
                settings.useWideViewPort = true
                settings.setSupportZoom(false)
                settings.builtInZoomControls = false
                settings.displayZoomControls = false
                // 隐藏滚动条
                isVerticalScrollBarEnabled = false
                isHorizontalScrollBarEnabled = false

                addJavascriptInterface(object {
                    @JavascriptInterface fun postResult(id: Int, value: String) {
                        jsResult[id.toString()] = value
                    }
                }, "DWeisJS")

                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        // page loaded — caller polls
                    }
                }
                webChromeClient = WebChromeClient()
            }
        }
    }

    /** 导航到URL，等待页面加载完成，返回快照JSON */
    fun navigate(url: String): String {
        val wv = webView ?: return """{"error":"WebView not created"}"""
        val latch = java.util.concurrent.CountDownLatch(1)
        var loadedUrl = ""
        handler!!.post {
            wv.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    loadedUrl = url ?: ""
                    latch.countDown()
                }
            }
            wv.loadUrl(url)
        }
        latch.await(30, java.util.concurrent.TimeUnit.SECONDS)
        return snapshot()
    }

    /** 获取页面结构化快照 */
    fun snapshot(): String {
        val wv = webView ?: return """{"error":"WebView not created"}"""
        val latch = java.util.concurrent.CountDownLatch(1)
        val result = StringBuilder()
        handler!!.post {
            try {
                val url = wv.url ?: ""
                val title = wv.title ?: ""
                val js = """
                    (function(){
                        var r={url:'$url',title:document.title||'$title'};
                        r.text=(document.body?document.body.innerText||'':'').substring(0,3000);
                        var els=[],seen=new Set();
                        function add(el,tag,info){
                            var rect=el.getBoundingClientRect();
                            if(rect.width===0||rect.height===0)return;
                            var key=tag+'|'+Math.round(rect.x)+'|'+Math.round(rect.y);
                            if(seen.has(key))return;
                            seen.add(key);
                            var item={t:tag,x:Math.round(rect.x),y:Math.round(rect.y),w:Math.round(rect.width),h:Math.round(rect.height)};
                            if(info)item.i=info.substring(0,200);
                            els.push(item);
                        }
                        document.querySelectorAll('a[href]').forEach(function(e){
                            var t=(e.innerText||'').trim().substring(0,80)||e.getAttribute('aria-label')||e.title||'';
                            if(!t&&e.querySelector('img'))t='[图片链接]';
                            add(e,'a',t);
                        });
                        document.querySelectorAll('button,input,select,textarea').forEach(function(e){
                            var t=e.getAttribute('aria-label')||e.placeholder||e.name||e.id||'';
                            if(!t&&e.tagName==='BUTTON')t=(e.innerText||'').trim().substring(0,80);
                            if(!t)t=(e.value||'').substring(0,40);
                            var tag=e.tagName.toLowerCase();
                            if(tag==='input')tag='input['+(e.type||'text')+']';
                            add(e,tag,t);
                        });
                        r.elements=JSON.stringify(els);
                        return JSON.stringify(r);
                    })()
                """.trimIndent()
                wv.evaluateJavascript(js) { json ->
                    result.append(json ?: """{"error":"js returned null"}""")
                    latch.countDown()
                }
            } catch (e: Exception) {
                result.append("""{"error":"${e.message?.replace("\"", "\\\"")}"}""")
                latch.countDown()
            }
        }
        latch.await(10, java.util.concurrent.TimeUnit.SECONDS)
        return result.toString()
    }

    /** 执行JavaScript */
    fun evaluateJs(js: String, callbackId: String): String? {
        val wv = webView ?: return "WebView not created"
        val id = jsId++
        val latch = java.util.concurrent.CountDownLatch(1)
        val result = StringBuilder()
        handler!!.post {
            try {
                val wrapped = """
                    (function(){
                        try{var r=eval($js);DWeisJS.postResult($id,String(r));}catch(e){DWeisJS.postResult($id,'Error: '+e.message);}
                    })()
                """.trimIndent()
                wv.evaluateJavascript(wrapped) {}
                // wait for JavascriptInterface callback
                Thread {
                    for (i in 0 until 50) { // 5 seconds max
                        val v = jsResult.remove(id.toString())
                        if (v != null) {
                            result.append(v)
                            latch.countDown()
                            return@Thread
                        }
                        Thread.sleep(100)
                    }
                    result.append("(timeout)")
                    latch.countDown()
                }.start()
            } catch (e: Exception) {
                result.append("Error: ${e.message}")
                latch.countDown()
            }
        }
        latch.await(6, java.util.concurrent.TimeUnit.SECONDS)
        return result.toString()
    }

    /** 截屏，返回base64 PNG */
    fun screenshot(): String? {
        val wv = webView ?: return null
        val latch = java.util.concurrent.CountDownLatch(1)
        var b64: String? = null
        handler!!.post {
            try {
                val bitmap = Bitmap.createBitmap(wv.width.coerceAtLeast(1), wv.height.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                wv.draw(canvas)
                val baos = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 80, baos)
                b64 = Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
                bitmap.recycle()
                baos.close()
            } catch (_: Exception) {}
            latch.countDown()
        }
        latch.await(10, java.util.concurrent.TimeUnit.SECONDS)
        return b64
    }

    /** 关闭WebView和后台线程 */
    fun close() {
        handler?.post {
            webView?.apply {
                stopLoading()
                destroy()
            }
            webView = null
        }
        thread?.quitSafely()
        thread = null
        handler = null
    }
}
