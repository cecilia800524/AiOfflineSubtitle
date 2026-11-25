-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

-keepclassmembers class ai.onnxruntime.OrtSession$SessionOptions {
    public *** addQnn(java.util.Map);
    public *** addXnnpack(java.util.Map);
}

-keepclassmembers class com.example.offlinesubtitle.bridge.OfflineSubtitleBridge {
    @android.webkit.JavascriptInterface <methods>;
}

-keep class com.example.offlinesubtitle.asr.SubtitleSegment { *; }
-keep class com.example.offlinesubtitle.service.SubtitleForegroundService { *; }
