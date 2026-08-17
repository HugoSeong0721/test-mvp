# WebView 의 @JavascriptInterface 는 리플렉션으로 호출되므로 난독화에서 제외한다.
# 지우면 릴리스 빌드에서만 공유 버튼이 조용히 죽는다.
-keepclassmembers class com.soulfulfill.climborburn.MainActivity$ShareBridge {
    public *;
}
-keepattributes JavascriptInterface
