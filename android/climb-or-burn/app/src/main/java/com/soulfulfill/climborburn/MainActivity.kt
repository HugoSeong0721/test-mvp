package com.soulfulfill.climborburn

import android.annotation.SuppressLint
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * 게임은 assets/game/index.html 하나로 완결되어 있다.
 * 이 액티비티는 그걸 전체화면 WebView 로 띄우는 껍데기다.
 */
class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView

    /** 게임의 "Share run" 이 부르는 통로. 안드로이드 공유 시트를 연다. */
    private inner class ShareBridge {
        @JavascriptInterface
        fun share(text: String) {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            startActivity(Intent.createChooser(send, null))
        }
    }

    @SuppressLint("SetJavaScriptEnabled", "AddJavascriptInterface")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        goFullScreen()
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        webView = WebView(this).apply {
            setBackgroundColor(Color.BLACK)          // 로딩 중 흰 화면 번쩍임 방지
            overScrollMode = View.OVER_SCROLL_NEVER  // 위아래 당길 때 생기는 반동 제거
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            isLongClickable = false                  // 길게 눌러 텍스트 선택되는 것 차단
            setOnLongClickListener { true }
        }

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true                 // 최고 점수·설정이 localStorage 에 저장된다
            mediaPlaybackRequiresUserGesture = false // 효과음이 탭 없이도 나도록
            cacheMode = WebSettings.LOAD_NO_CACHE    // 자산이 앱 안에 있으니 캐시할 이유가 없다
            allowFileAccess = false                  // file:///android_asset 은 이 설정과 무관하게 열린다
            allowContentAccess = false
            setSupportZoom(false)
            builtInZoomControls = false
            displayZoomControls = false
            textZoom = 100                           // 기기 글꼴 크기 설정에 레이아웃이 흔들리지 않게
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                view?.evaluateJavascript(SHARE_POLYFILL, null)
            }

            // 게임 밖으로 나가는 이동은 앱 안에서 열지 않고 브라우저에 넘긴다
            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?
            ): Boolean {
                val uri: Uri = request?.url ?: return true
                if (uri.toString().startsWith(GAME_URL)) return false
                if (uri.scheme == "http" || uri.scheme == "https") {
                    runCatching { startActivity(Intent(Intent.ACTION_VIEW, uri)) }
                }
                return true
            }
        }

        webView.addJavascriptInterface(ShareBridge(), "AndroidShare")
        webView.loadUrl(GAME_URL)
        setContentView(webView)
    }

    private fun goFullScreen() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) goFullScreen()   // 공유 시트를 닫고 돌아오면 다시 전체화면으로
    }

    // 백그라운드에서 게임 루프가 계속 돌면 배터리를 먹는다
    override fun onPause() {
        super.onPause()
        webView.onPause()
        webView.pauseTimers()
    }

    override fun onResume() {
        super.onResume()
        webView.onResume()
        webView.resumeTimers()
    }

    override fun onDestroy() {
        webView.destroy()
        super.onDestroy()
    }

    companion object {
        private const val GAME_URL = "file:///android_asset/game/index.html"

        /** 웹에서 게임이 열려 있는 주소. 공유 링크는 이쪽을 가리켜야 상대가 열 수 있다. */
        private const val PLAY_URL =
            "https://hugoseong0721.github.io/test-mvp/firechase.html"

        /**
         * WebView 에는 navigator.share 가 없어서 게임의 공유 버튼이 수동 복사로 떨어진다.
         * 안드로이드 공유 시트로 연결해 주고, 링크는 file:// 대신 웹 주소로 바꾼다.
         */
        private val SHARE_POLYFILL = """
            (function () {
              if (!window.AndroidShare || navigator.share) return;
              navigator.share = function (d) {
                d = d || {};
                var hash = /#.*${'$'}/.exec(d.url || '');
                var url = '$PLAY_URL' + (hash ? hash[0] : '');
                var text = (d.text || '') + '\n' + url;
                window.AndroidShare.share(text);
                return Promise.resolve();
              };
            })();
        """.trimIndent()
    }
}
