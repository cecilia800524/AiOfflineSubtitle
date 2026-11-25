# ONNX Runtime 與 QNN JNI 保留規則
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# 保留 LocalNpuAsrEngine 透過反射呼叫 QNN EP 之 SessionOptions 方法
-keepclassmembers class ai.onnxruntime.OrtSession$SessionOptions {
    public *** addQnn(java.util.Map);
    public *** addXnnpack(java.util.Map);
}

# 保留 OfflineSubtitleBridge 供離線 WebView 呼叫之 JavascriptInterface 方法
-keepclassmembers class com.example.offlinesubtitle.bridge.OfflineSubtitleBridge {
    @android.webkit.JavascriptInterface <methods>;
}

# 保留本專案資料模型與前景服務名稱
-keep class com.example.offlinesubtitle.asr.SubtitleSegment { *; }
-keep class com.example.offlinesubtitle.service.SubtitleForegroundService { *; }
