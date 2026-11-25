#!/usr/bin/env bash
set -euo pipefail

mkdir -p \
  gradle/wrapper \
  app/src/main/res/xml \
  app/src/main/res/values \
  app/src/main/assets/bridge \
  app/src/main/java/com/example/offlinesubtitle/asr \
  app/src/main/java/com/example/offlinesubtitle/audio \
  app/src/main/java/com/example/offlinesubtitle/bridge \
  app/src/main/java/com/example/offlinesubtitle/export \
  app/src/main/java/com/example/offlinesubtitle/service \
  app/src/main/java/com/example/offlinesubtitle/subtitle \
  app/src/main/java/com/example/offlinesubtitle/ui \
  .github/workflows

cat << 'EOF' > settings.gradle.kts
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "OfflineSubtitle"
include(":app")
EOF

cat << 'EOF' > build.gradle.kts
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
EOF

cat << 'EOF' > gradle.properties
org.gradle.jvmargs=-Xmx4096m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
EOF

cat << 'EOF' > gradle/libs.versions.toml
[versions]
agp = "8.5.2"
kotlin = "2.0.20"
coreKtx = "1.13.1"
lifecycle = "2.8.6"
activityCompose = "1.9.2"
composeBom = "2024.09.02"
coroutines = "1.9.0"
onnxruntime = "1.19.2"

[libraries]
androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version.ref = "coreKtx" }
androidx-lifecycle-runtime-ktx = { group = "androidx.lifecycle", name = "lifecycle-runtime-ktx", version.ref = "lifecycle" }
androidx-lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }
androidx-lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycle" }
androidx-lifecycle-service = { group = "androidx.lifecycle", name = "lifecycle-service", version.ref = "lifecycle" }
androidx-activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }

androidx-compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
androidx-compose-ui = { group = "androidx.compose.ui", name = "ui" }
androidx-compose-ui-graphics = { group = "androidx.compose.ui", name = "ui-graphics" }
androidx-compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
androidx-compose-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
androidx-compose-material3 = { group = "androidx.compose.material3", name = "material3" }
androidx-compose-material-icons-extended = { group = "androidx.compose.material", name = "material-icons-extended" }

kotlinx-coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }
onnxruntime-android = { group = "com.microsoft.onnxruntime", name = "onnxruntime-android", version.ref = "onnxruntime" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
EOF

cat << 'EOF' > gradle/wrapper/gradle-wrapper.properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

cat << 'EOF' > app/build.gradle.kts
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.example.offlinesubtitle"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.offlinesubtitle"
        minSdk = 34
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.service)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)

    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.onnxruntime.android)

    debugImplementation(libs.androidx.compose.ui.tooling)
}
EOF

cat << 'EOF' > app/proguard-rules.pro
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
EOF

cat << 'EOF' > app/src/main/res/xml/file_paths.xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="exported_subtitles" path="exports/" />
</paths>
EOF

cat << 'EOF' > app/src/main/res/values/strings.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">OfflineSubtitle</string>
</resources>
EOF

cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- 離線音訊擷取、前景服務、防休眠與懸浮窗權限（嚴禁宣告任何網路權限） -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:allowBackup="false"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".service.SubtitleForegroundService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="microphone|mediaProjection" />

        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>

    </application>

</manifest>
EOF

cat << 'EOF' > app/src/main/assets/bridge/index.html
<!DOCTYPE html>
<html lang="zh-Hant">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>OfflineSubtitle Bridge UI</title>
  <link rel="stylesheet" href="./styles.css" />
</head>
<body>
  <div class="shell">
    <header class="header">
      <div>
        <h1>OfflineSubtitle Bridge UI</h1>
        <p id="bridgeStatus" class="sub">等待原生橋接同步...</p>
      </div>
      <div class="header-btns">
        <button id="btnBridgeOverlay" class="btn-sm">懸浮窗</button>
        <button id="btnBridgeClear" class="btn-sm">清除</button>
      </div>
    </header>

    <section class="card">
      <div class="row">
        <span id="bridgeBackend" class="pill pill-npu">QNN_NPU</span>
        <span id="bridgeLatency" class="metric">延遲: 0 ms</span>
        <span id="bridgeRtf" class="metric">RTF: 0.000</span>
      </div>
      <div class="sub-row">
        <span id="bridgeSysInfo">磁碟: 0.0MB | PSS: 0.0MB | 漂移: 0ms</span>
        <span id="bridgeVad" class="vad-badge">VAD: 靜音</span>
      </div>
    </section>

    <!-- 模型路徑設定框（與 MainScreen 同步） -->
    <section class="card">
      <div class="sub-row">
        <span class="label-bold">模型路徑設定</span>
        <span id="bridgeModelSizeTag" class="label-muted">0.0 MB</span>
      </div>
      <input
        id="inputBridgeModelPath"
        type="text"
        class="path-input"
        placeholder="getExternalFilesDir(null)/models/whisper-tiny"
      />
      <div class="controls">
        <button id="btnPickModelFolder" class="btn-sm flex-1">選擇資料夾</button>
        <button id="btnApplyModelPath" class="btn-sm flex-1">套用</button>
        <button id="btnResetModelPath" class="btn-sm flex-1">重設為預設</button>
      </div>
      <p id="bridgePathAlert" class="path-alert hidden"></p>
    </section>

    <section class="controls">
      <select id="selectBridgeModel" class="select">
        <option value="MOCK">Mock NPU (原型測試)</option>
        <option value="WHISPER_TINY">Whisper Tiny (QNN NPU)</option>
        <option value="WHISPER_SMALL">Whisper Small (本地 NPU)</option>
      </select>
      <button id="btnBridgeUnload" class="btn-sm">卸載模型</button>
      <button id="btnBridgeImport" class="btn-sm">匯入音檔</button>
    </section>

    <section class="controls">
      <button class="chip active" data-source="MICROPHONE">麥克風</button>
      <button class="chip" data-source="SYSTEM_AUDIO">系統音訊</button>
      <button class="chip" data-source="SIMULATED_PCM">模擬音訊</button>
      <button id="btnBridgeBackendToggle" class="chip">NPU 優先</button>
    </section>

    <section id="bridgeSubtitleList" class="list">
      <div class="empty">透過 OfflineSubtitleBridge 即時同步原生字幕狀態</div>
    </section>

    <footer class="footer">
      <button id="btnBridgeTestInject" class="btn-sm">測試資料</button>
      <button id="btnBridgeExportSrt" class="btn-sm">匯出 SRT</button>
      <button id="btnBridgeStartStop" class="btn-primary">啟動服務</button>
    </footer>
  </div>

  <script defer src="./bridge.js"></script>
  <script defer src="./app.js"></script>
</body>
</html>
EOF

cat << 'EOF' > app/src/main/assets/bridge/styles.css
:root {
  --bg: #f5f7fb;
  --surface: #ffffff;
  --border: #d7dce5;
  --text: #111827;
  --muted: #6b7280;
  --primary: #1a73e8;
  --danger: #d93025;
  --ok: #1b873f;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: sans-serif;
  background: var(--bg);
  color: var(--text);
  height: 100vh;
}

.shell {
  display: flex;
  flex-direction: column;
  height: 100vh;
  padding: 10px;
  gap: 8px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 8px 12px;
}

.header h1 {
  font-size: 14px;
}

.sub {
  font-size: 11px;
  color: var(--muted);
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.header-btns,
.controls,
.footer {
  display: flex;
  gap: 6px;
  align-items: center;
}

.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 8px 10px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.row,
.sub-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 6px;
}

.sub-row {
  font-size: 11px;
  color: var(--muted);
}

.label-bold {
  font-weight: 700;
  color: var(--text);
}

.label-muted {
  color: var(--muted);
}

.path-input {
  width: 100%;
  border: 1px solid var(--border);
  background: var(--bg);
  border-radius: 8px;
  padding: 6px 8px;
  font-size: 11px;
  color: var(--text);
}

.flex-1 {
  flex: 1;
}

.path-alert {
  font-size: 11px;
  font-weight: 700;
  color: var(--danger);
  background: #ffebee;
  border-radius: 6px;
  padding: 4px 8px;
}

.hidden {
  display: none !important;
}

.pill {
  font-size: 11px;
  font-weight: 700;
  padding: 2px 7px;
  border-radius: 6px;
}

.pill-npu {
  background: #e3f2fd;
  color: #0d47a1;
}

.pill-cpu {
  background: #fff3e0;
  color: #e65100;
}

.metric {
  font-size: 12px;
  font-weight: 700;
}

.metric.ok {
  color: var(--ok);
}

.metric.warn {
  color: var(--danger);
}

.vad-badge.active {
  color: var(--ok);
  font-weight: 700;
}

.select,
.btn-sm,
.chip {
  border: 1px solid var(--border);
  background: var(--surface);
  border-radius: 8px;
  padding: 6px 8px;
  font-size: 11px;
}

.select {
  flex: 1;
}

.chip.active,
.btn-sm.active {
  background: var(--primary);
  color: #fff;
  border-color: var(--primary);
}

.list {
  flex: 1;
  overflow-y: auto;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.empty {
  margin: auto;
  font-size: 12px;
  color: var(--muted);
  text-align: center;
}

.item {
  background: #eef2f7;
  border-radius: 8px;
  padding: 8px;
}

.item.draft {
  background: #e8f0fe;
  font-style: italic;
}

.item-meta {
  display: flex;
  justify-content: space-between;
  font-size: 10px;
  color: var(--muted);
  margin-bottom: 3px;
}

.item-text {
  font-size: 13px;
}

.btn-primary {
  flex: 1;
  border: none;
  border-radius: 8px;
  padding: 9px 12px;
  background: var(--primary);
  color: #fff;
  font-size: 13px;
  font-weight: 700;
}

.btn-primary.stop {
  background: var(--danger);
}
EOF

cat << 'EOF' > app/src/main/assets/bridge/bridge.js
(function () {
  const nativeBridge = window.AndroidOfflineSubtitleBridge || null;
  const listeners = new Set();

  window.__onNativeSubtitleState = function (jsonText) {
    try {
      const state = typeof jsonText === 'string' ? JSON.parse(jsonText) : jsonText;
      listeners.forEach(function (cb) {
        cb(state);
      });
    } catch (e) {
      console.error('Bridge parse error:', e);
    }
  };

  window.OfflineSubtitleBridgeClient = {
    subscribe: function (cb) {
      listeners.add(cb);
      if (nativeBridge && typeof nativeBridge.getStateJson === 'function') {
        window.__onNativeSubtitleState(nativeBridge.getStateJson());
      }
      return function () {
        listeners.delete(cb);
      };
    },
    pickModelFolder: function () {
      if (nativeBridge) nativeBridge.pickModelFolder();
    },
    applyModelPath: function (path) {
      if (nativeBridge) nativeBridge.applyModelPath(path);
    },
    resetModelPath: function () {
      if (nativeBridge) nativeBridge.resetModelPath();
    },
    startService: function (source) {
      if (nativeBridge) nativeBridge.startService(source);
    },
    stopService: function () {
      if (nativeBridge) nativeBridge.stopService();
    },
    toggleOverlay: function () {
      if (nativeBridge) nativeBridge.toggleOverlay();
    },
    switchModel: function (mode) {
      if (nativeBridge) nativeBridge.switchModel(mode);
    },
    unloadModel: function () {
      if (nativeBridge) nativeBridge.unloadModel();
    },
    setBackendMode: function (backend) {
      if (nativeBridge) nativeBridge.setBackendMode(backend);
    },
    setInputSource: function (source) {
      if (nativeBridge) nativeBridge.setInputSource(source);
    },
    importAudioFile: function () {
      if (nativeBridge) nativeBridge.importAudioFile();
    },
    clearSubtitles: function () {
      if (nativeBridge) nativeBridge.clearSubtitles();
    },
    injectTestSegments: function () {
      if (nativeBridge) nativeBridge.injectTestSegments();
    },
    exportSrt: function () {
      if (nativeBridge) nativeBridge.exportSubtitles('SRT', false);
    }
  };
})();
EOF

cat << 'EOF' > app/src/main/assets/bridge/app.js
(function () {
  const client = window.OfflineSubtitleBridgeClient;
  let currentState = null;

  const el = {
    status: document.getElementById('bridgeStatus'),
    backend: document.getElementById('bridgeBackend'),
    latency: document.getElementById('bridgeLatency'),
    rtf: document.getElementById('bridgeRtf'),
    sysInfo: document.getElementById('bridgeSysInfo'),
    vad: document.getElementById('bridgeVad'),
    inputModelPath: document.getElementById('inputBridgeModelPath'),
    modelSizeTag: document.getElementById('bridgeModelSizeTag'),
    btnPickFolder: document.getElementById('btnPickModelFolder'),
    btnApplyPath: document.getElementById('btnApplyModelPath'),
    btnResetPath: document.getElementById('btnResetModelPath'),
    pathAlert: document.getElementById('bridgePathAlert'),
    list: document.getElementById('bridgeSubtitleList'),
    btnOverlay: document.getElementById('btnBridgeOverlay'),
    btnClear: document.getElementById('btnBridgeClear'),
    selectModel: document.getElementById('selectBridgeModel'),
    btnUnload: document.getElementById('btnBridgeUnload'),
    btnImport: document.getElementById('btnBridgeImport'),
    btnBackendToggle: document.getElementById('btnBridgeBackendToggle'),
    btnTestInject: document.getElementById('btnBridgeTestInject'),
    btnExportSrt: document.getElementById('btnBridgeExportSrt'),
    btnStartStop: document.getElementById('btnBridgeStartStop')
  };

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  function render(state) {
    currentState = state;
    el.status.textContent = state.statusMessage || '';
    el.backend.textContent = state.backendTag + (state.isModelLoaded ? ' (已載入)' : ' (未載入)');
    el.backend.className = 'pill ' + (state.backendTag === 'QNN_NPU' ? 'pill-npu' : 'pill-cpu');

    el.latency.textContent = '延遲: ' + state.lastLatencyMs + ' ms';
    el.latency.className = 'metric ' + (state.lastLatencyMs === 0 ? '' : (state.lastLatencyMs < 800 ? 'ok' : 'warn'));

    const rtf = Number(state.lastRtf || 0);
    el.rtf.textContent = 'RTF: ' + rtf.toFixed(3);
    el.rtf.className = 'metric ' + (rtf <= 0 ? '' : (rtf < 0.3 ? 'ok' : 'warn'));

    const diskMb = Number(state.modelsDiskSizeMb || 0).toFixed(1);
    el.modelSizeTag.textContent = diskMb + ' MB';
    el.sysInfo.textContent =
      '磁碟: ' + diskMb + 'MB | ' +
      'PSS: ' + Number(state.pssMemoryMb || 0).toFixed(1) + 'MB | ' +
      '漂移: ' + state.timelineDriftMs + 'ms';

    if (document.activeElement !== el.inputModelPath && state.currentModelPath) {
      el.inputModelPath.value = state.currentModelPath;
    }

    if (state.modelPathError) {
      el.pathAlert.textContent = state.modelPathError;
      el.pathAlert.classList.remove('hidden');
    } else {
      el.pathAlert.textContent = '';
      el.pathAlert.classList.add('hidden');
    }

    el.vad.textContent = state.isSpeechActive ? 'VAD: 語音中' : 'VAD: 靜音';
    el.vad.className = 'vad-badge ' + (state.isSpeechActive ? 'active' : '');

    el.btnOverlay.classList.toggle('active', Boolean(state.isOverlayActive));
    el.btnBackendToggle.textContent = state.backendTag === 'QNN_NPU' ? 'NPU 優先' : 'CPU 模式';

    const busy = Boolean(state.isRunning || state.isFileTranscribing);
    el.inputModelPath.disabled = busy;
    el.btnPickFolder.disabled = busy;
    el.btnApplyPath.disabled = busy;
    el.btnResetPath.disabled = busy;

    document.querySelectorAll('[data-source]').forEach(function (btn) {
      btn.classList.toggle('active', btn.dataset.source === state.inputSource);
      btn.disabled = busy;
    });

    el.btnStartStop.textContent = state.isRunning ? '停止服務' : '啟動服務';
    el.btnStartStop.classList.toggle('stop', Boolean(state.isRunning));

    const segments = state.segments || [];
    if (!segments.length) {
      el.list.innerHTML = '<div class="empty">透過 OfflineSubtitleBridge 即時同步原生字幕狀態</div>';
      return;
    }

    el.list.innerHTML = segments.map(function (seg) {
      return (
        '<div class="item ' + (seg.isFinal ? 'final' : 'draft') + '">' +
        '<div class="item-meta"><span>#' + seg.id + ' (' + seg.startTimeMs + '→' + seg.endTimeMs + 'ms)</span>' +
        '<span>' + (seg.isFinal ? 'FINAL • ' + seg.backendTag : 'DRAFT') + ' • ' + seg.latencyMs + 'ms</span></div>' +
        '<div class="item-text">' + escapeHtml(seg.text) + '</div>' +
        '</div>'
      );
    }).join('');
    el.list.scrollTop = el.list.scrollHeight;
  }

  el.btnPickFolder.addEventListener('click', function () {
    client.pickModelFolder();
  });

  el.btnApplyPath.addEventListener('click', function () {
    client.applyModelPath(el.inputModelPath.value);
  });

  el.btnResetPath.addEventListener('click', function () {
    client.resetModelPath();
  });

  el.btnOverlay.addEventListener('click', function () { client.toggleOverlay(); });
  el.btnClear.addEventListener('click', function () { client.clearSubtitles(); });
  el.btnUnload.addEventListener('click', function () { client.unloadModel(); });
  el.btnImport.addEventListener('click', function () { client.importAudioFile(); });
  el.btnTestInject.addEventListener('click', function () { client.injectTestSegments(); });
  el.btnExportSrt.addEventListener('click', function () { client.exportSrt(); });

  el.selectModel.addEventListener('change', function (e) {
    client.switchModel(e.target.value);
  });

  el.btnBackendToggle.addEventListener('click', function () {
    if (!currentState) return;
    client.setBackendMode(currentState.backendTag === 'QNN_NPU' ? 'CPU_FALLBACK' : 'QNN_NPU');
  });

  document.querySelectorAll('[data-source]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      client.setInputSource(btn.dataset.source);
    });
  });

  el.btnStartStop.addEventListener('click', function () {
    if (!currentState) return;
    if (currentState.isRunning) {
      client.stopService();
    } else {
      client.startService(currentState.inputSource);
    }
  });

  client.subscribe(render);
})();
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/asr/AsrEngine.kt
package com.example.offlinesubtitle.asr

import android.os.SystemClock
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

enum class BackendTag(val label: String) {
    QNN_NPU("QNN_NPU"),
    CPU_FALLBACK("CPU_FALLBACK")
}

data class SubtitleSegment(
    val id: Long,
    val text: String,
    val isFinal: Boolean,
    val startTimeMs: Long,
    val endTimeMs: Long,
    val backendTag: BackendTag,
    val latencyMs: Long
)

interface AsrEngine {
    val currentBackend: BackendTag

    suspend fun initialize(): Result<Unit>

    suspend fun transcribe(
        pcm16kMono: ShortArray,
        segmentId: Long,
        startTimeMs: Long,
        endTimeMs: Long,
        isFinalTrigger: Boolean
    ): SubtitleSegment

    fun setBackendMode(backendTag: BackendTag)

    fun release()
}

class MockNpuAsrEngine : AsrEngine {

    companion object {
        private const val TAG_PERF = "[ASR_PERF]"
        private const val SAMPLE_RATE = 16_000L

        private val CODE_SWITCHING_SCRIPTS = listOf(
            "大家好，今天我們在 Snapdragon 8s Gen 4 裝置上測試離線即時字幕系統，透過 Hexagon NPU 與 QNN 加速推論效能。",
            "目前音訊管線採用 16kHz Mono PCM 格式輸入，並搭配 VAD 偵測進行靜音過濾與 30 秒滑動視窗切分。",
            "在 Jetpack Compose 與 OfflineSubtitleBridge 介面中，我們將 Draft 草稿字幕與 Final 定稿字幕分離，確保延遲低於 800ms。",
            "這套架構完全不依賴 Cloud API 或網路連線，支援繁體中文與 English 技術名詞混合辨識。",
            "當講者連續發言超過 30 秒邊界時，系統會保留最後 2 秒的重疊音訊緩衝，避免關鍵字詞被截斷。"
        )
    }

    @Volatile
    private var backendMode: BackendTag = BackendTag.QNN_NPU

    override val currentBackend: BackendTag
        get() = backendMode

    override suspend fun initialize(): Result<Unit> = withContext(Dispatchers.Default) {
        val start = SystemClock.elapsedRealtime()
        delay(60L)
        val cost = SystemClock.elapsedRealtime() - start
        Log.i(TAG_PERF, "MockNpuAsrEngine initialized in ${cost}ms, Backend=${backendMode.label}")
        Result.success(Unit)
    }

    override fun setBackendMode(backendTag: BackendTag) {
        backendMode = backendTag
        Log.i(TAG_PERF, "Switched ASR Backend=${backendTag.label}")
    }

    override suspend fun transcribe(
        pcm16kMono: ShortArray,
        segmentId: Long,
        startTimeMs: Long,
        endTimeMs: Long,
        isFinalTrigger: Boolean
    ): SubtitleSegment = withContext(Dispatchers.Default) {
        val inferStartMs = SystemClock.elapsedRealtime()
        val audioDurationMs = (pcm16kMono.size * 1000L) / SAMPLE_RATE

        val simulatedComputeMs = when (backendMode) {
            BackendTag.QNN_NPU -> (65L + audioDurationMs / 40L).coerceIn(70L, 260L)
            BackendTag.CPU_FALLBACK -> (240L + audioDurationMs / 10L).coerceIn(250L, 950L)
        }
        delay(simulatedComputeMs)

        val script = CODE_SWITCHING_SCRIPTS[((segmentId - 1L).coerceAtLeast(0L) % CODE_SWITCHING_SCRIPTS.size).toInt()]
        val targetDurationForFullScriptMs = 6_500L
        val progress = if (isFinalTrigger && audioDurationMs >= 3_500L) {
            1.0f
        } else {
            (audioDurationMs.toFloat() / targetDurationForFullScriptMs.toFloat()).coerceIn(0.18f, 1.0f)
        }

        val charCount = (script.length * progress).toInt().coerceIn(4, script.length)
        val recognizedText = script.substring(0, charCount)

        val inferLatencyMs = SystemClock.elapsedRealtime() - inferStartMs
        val rtf = if (audioDurationMs > 0L) inferLatencyMs.toFloat() / audioDurationMs.toFloat() else 0f

        Log.d(
            TAG_PERF,
            "Backend=${backendMode.label} seg=$segmentId final=$isFinalTrigger " +
                "audioMs=$audioDurationMs inferMs=$inferLatencyMs rtf=${"%.3f".format(rtf)}"
        )

        SubtitleSegment(
            id = segmentId,
            text = recognizedText,
            isFinal = isFinalTrigger,
            startTimeMs = startTimeMs,
            endTimeMs = endTimeMs,
            backendTag = backendMode,
            latencyMs = inferLatencyMs
        )
    }

    override fun release() {
        Log.i(TAG_PERF, "MockNpuAsrEngine released")
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/asr/LocalNpuAsrEngine.kt
package com.example.offlinesubtitle.asr

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtException
import ai.onnxruntime.OrtSession
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.DocumentsContract
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sin

/**
 * 模型配置檔：
 * 預設 WHISPER_TINY_QNN -> getExternalFilesDir(null)/models/whisper-tiny
 */
enum class LocalModelProfile(
    val dirName: String,
    val displayName: String
) {
    WHISPER_TINY_QNN("whisper-tiny", "Whisper Tiny (QNN NPU)"),
    WHISPER_SMALL_QNN("whisper-small", "Whisper Small (本地 NPU)")
}

data class ModelLocationStatus(
    val activePath: String,
    val isCustomPath: Boolean,
    val directoryExists: Boolean,
    val hasEncoderOnnx: Boolean,
    val diskUsageMb: Double,
    val errorMessage: String?
)

class LocalNpuAsrEngine(
    private val context: Context,
    private var profile: LocalModelProfile = LocalModelProfile.WHISPER_TINY_QNN
) : AsrEngine {

    companion object {
        private const val TAG_PERF = "[ASR_PERF]"
        private const val TAG_STATE = "[ASR_STATE]"

        private const val PREFS_NAME = "offline_subtitle_prefs"
        const val KEY_CUSTOM_MODEL_PATH = "custom_model_path"

        private const val SAMPLE_RATE = 16_000
        private const val MAX_SAMPLES = 30 * SAMPLE_RATE
        private const val N_MELS = 80
        private const val MEL_FRAMES = 3000
        private const val MAX_DECODE_TOKENS = 128

        private const val DEFAULT_SOT = 50258
        private const val DEFAULT_LANG_ZH = 50260
        private const val DEFAULT_TASK_TRANSCRIBE = 50359
        private const val DEFAULT_NO_TIMESTAMPS = 50363
        private const val DEFAULT_EOT = 50257
    }

    private data class SafScanResult(
        val exists: Boolean,
        val totalBytes: Long,
        val encoderDocId: String?,
        val decoderDocId: String?,
        val qnnEncoderDocId: String?,
        val qnnDecoderDocId: String?,
        val vocabDocId: String?
    )

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val ortEnv: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val inferMutex = Mutex()
    private val melExtractor = WhisperLogMelExtractor()
    private val unicodeToByte: Map<Char, Byte> = buildWhisperUnicodeToByteMap()

    private var encoderSession: OrtSession? = null
    private var decoderSession: OrtSession? = null
    private var idToToken: Map<Int, String> = emptyMap()
    private var eotTokenId: Int = DEFAULT_EOT

    @Volatile
    private var preferNpu: Boolean = true

    @Volatile
    private var activeBackend: BackendTag = BackendTag.QNN_NPU

    @Volatile
    var isLoaded: Boolean = false
        private set

    override val currentBackend: BackendTag
        get() = activeBackend

    init {
        ensureDefaultModelDirectories()
    }

    /**
     * 預設路徑：getExternalFilesDir(null)/models/whisper-tiny
     */
    fun getDefaultModelDir(): File {
        val externalRoot = context.getExternalFilesDir(null) ?: context.filesDir
        return File(externalRoot, "models/${profile.dirName}").apply {
            if (!exists()) mkdirs()
        }
    }

    fun getCustomModelPath(): String? {
        return prefs.getString(KEY_CUSTOM_MODEL_PATH, null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    fun getEffectiveModelPath(): String {
        return getCustomModelPath() ?: getDefaultModelDir().absolutePath
    }

    fun setCustomModelPath(rawPath: String) {
        val trimmed = rawPath.trim()
        if (trimmed.isEmpty()) {
            resetCustomModelPath()
        } else {
            prefs.edit().putString(KEY_CUSTOM_MODEL_PATH, trimmed).apply()
            Log.i(TAG_STATE, "Saved custom_model_path=$trimmed")
        }
    }

    fun resetCustomModelPath() {
        prefs.edit().remove(KEY_CUSTOM_MODEL_PATH).apply()
        ensureDefaultModelDirectories()
        Log.i(TAG_STATE, "Cleared custom_model_path, reverted to default=${getDefaultModelDir().absolutePath}")
    }

    private fun ensureDefaultModelDirectories() {
        runCatching {
            val externalRoot = context.getExternalFilesDir(null) ?: context.filesDir
            val modelsRoot = File(externalRoot, "models").apply { if (!exists()) mkdirs() }
            LocalModelProfile.entries.forEach { p ->
                val dir = File(modelsRoot, p.dirName)
                if (!dir.exists()) dir.mkdirs()
            }
        }
    }

    /**
     * 優先讀取 SharedPreferences 的 custom_model_path，無自訂則讀取預設目錄，
     * 並檢查目錄存在性、encoder.onnx 存在性及磁碟空間用量 (MB)。
     */
    fun inspectModelLocation(): ModelLocationStatus {
        val customPath = getCustomModelPath()
        val effectivePath = customPath ?: getDefaultModelDir().absolutePath

        if (effectivePath.startsWith("content://")) {
            val safScan = scanSafTree(Uri.parse(effectivePath))
            val hasEncoder = safScan.exists && (safScan.encoderDocId != null || safScan.qnnEncoderDocId != null)
            val diskMb = safScan.totalBytes / (1024.0 * 1024.0)
            val err = if (!safScan.exists || !hasEncoder) "找不到 encoder.onnx" else null
            return ModelLocationStatus(
                activePath = effectivePath,
                isCustomPath = true,
                directoryExists = safScan.exists,
                hasEncoderOnnx = hasEncoder,
                diskUsageMb = diskMb,
                errorMessage = err
            )
        }

        val dir = resolveFileDirectory(effectivePath)
        val dirExists = dir.exists() && dir.isDirectory
        val hasEncoder = dirExists && (
            File(dir, "encoder.onnx").exists() ||
                File(dir, "encoder_qnn_ctx.onnx").exists()
            )
        val diskMb = if (dirExists) {
            dir.walkTopDown().filter { it.isFile }.sumOf { it.length() } / (1024.0 * 1024.0)
        } else {
            0.0
        }
        val err = if (!dirExists || !hasEncoder) "找不到 encoder.onnx" else null
        return ModelLocationStatus(
            activePath = dir.absolutePath,
            isCustomPath = customPath != null,
            directoryExists = dirExists,
            hasEncoderOnnx = hasEncoder,
            diskUsageMb = diskMb,
            errorMessage = err
        )
    }

    fun calculateModelsDiskUsageMb(): Double = inspectModelLocation().diskUsageMb

    fun setProfile(newProfile: LocalModelProfile) {
        profile = newProfile
        ensureDefaultModelDirectories()
    }

    fun getProfile(): LocalModelProfile = profile

    override fun setBackendMode(backendTag: BackendTag) {
        preferNpu = (backendTag == BackendTag.QNN_NPU)
        Log.i(TAG_PERF, "LocalNpuAsrEngine preference updated -> preferNpu=$preferNpu")
    }

    override suspend fun initialize(): Result<Unit> = withContext(Dispatchers.IO) {
        inferMutex.withLock {
            releaseInternal()

            val effectivePath = getEffectiveModelPath()
            val resolvedDir: File = if (effectivePath.startsWith("content://")) {
                prepareSafModelsIntoCache(Uri.parse(effectivePath)).getOrElse { err ->
                    return@withContext Result.failure(err)
                }
            } else {
                resolveFileDirectory(effectivePath)
            }

            if (!resolvedDir.exists() || !resolvedDir.isDirectory) {
                val msg = "找不到 encoder.onnx (${resolvedDir.absolutePath})"
                Log.w(TAG_STATE, msg)
                return@withContext Result.failure(FileNotFoundException("找不到 encoder.onnx"))
            }

            val qnnEncoderCtx = File(resolvedDir, "encoder_qnn_ctx.onnx")
            val qnnDecoderCtx = File(resolvedDir, "decoder_qnn_ctx.onnx")
            val stdEncoder = File(resolvedDir, "encoder.onnx")
            val stdDecoder = File(resolvedDir, "decoder.onnx")

            val encFile = when {
                preferNpu && qnnEncoderCtx.exists() -> qnnEncoderCtx
                stdEncoder.exists() -> stdEncoder
                qnnEncoderCtx.exists() -> qnnEncoderCtx
                else -> null
            }
            val decFile = when {
                preferNpu && qnnDecoderCtx.exists() -> qnnDecoderCtx
                stdDecoder.exists() -> stdDecoder
                qnnDecoderCtx.exists() -> qnnDecoderCtx
                else -> null
            }

            if (encFile == null || decFile == null) {
                val msg = if (encFile == null) "找不到 encoder.onnx" else "找不到 decoder.onnx"
                Log.w(TAG_STATE, "$msg at ${resolvedDir.absolutePath}")
                return@withContext Result.failure(FileNotFoundException(msg))
            }

            val loadStart = SystemClock.elapsedRealtime()
            val numThreads = Runtime.getRuntime().availableProcessors().coerceIn(2, 4)

            var loadedWithQnn = false
            if (preferNpu && isQnnHtpSupported()) {
                try {
                    val qnnOpts = createSessionOptions(useQnnNpu = true, numThreads = numThreads)
                    encoderSession = ortEnv.createSession(encFile.absolutePath, qnnOpts)
                    decoderSession = ortEnv.createSession(decFile.absolutePath, qnnOpts)
                    qnnOpts.close()
                    activeBackend = BackendTag.QNN_NPU
                    loadedWithQnn = true
                    Log.i(TAG_PERF, "Backend=QNN_NPU (loaded ${encFile.absolutePath}, threads=$numThreads)")
                } catch (t: Throwable) {
                    Log.w(TAG_PERF, "QNN EP init failed (${t.message}), falling back to CPU_FALLBACK")
                    releaseInternal()
                }
            }

            if (!loadedWithQnn) {
                try {
                    val cpuEnc = stdEncoder.takeIf { it.exists() } ?: encFile
                    val cpuDec = stdDecoder.takeIf { it.exists() } ?: decFile
                    val cpuOpts = createSessionOptions(useQnnNpu = false, numThreads = numThreads)
                    encoderSession = ortEnv.createSession(cpuEnc.absolutePath, cpuOpts)
                    decoderSession = ortEnv.createSession(cpuDec.absolutePath, cpuOpts)
                    cpuOpts.close()
                    activeBackend = BackendTag.CPU_FALLBACK
                    Log.i(TAG_PERF, "Backend=CPU_FALLBACK (loaded ${cpuEnc.absolutePath}, intraOpThreads=$numThreads)")
                } catch (e: OrtException) {
                    releaseInternal()
                    return@withContext Result.failure(e)
                }
            }

            loadTokenizerIfPresent(resolvedDir)
            isLoaded = true
            val loadCostMs = SystemClock.elapsedRealtime() - loadStart
            Log.i(
                TAG_PERF,
                "Model loaded path=${effectivePath} Backend=${activeBackend.label} " +
                    "loadTime=${loadCostMs}ms diskUsage=${"%.2f".format(calculateModelsDiskUsageMb())}MB"
            )
            Result.success(Unit)
        }
    }

    override suspend fun transcribe(
        pcm16kMono: ShortArray,
        segmentId: Long,
        startTimeMs: Long,
        endTimeMs: Long,
        isFinalTrigger: Boolean
    ): SubtitleSegment = withContext(Dispatchers.Default) {
        inferMutex.withLock {
            val enc = checkNotNull(encoderSession) { "LocalNpuAsrEngine 尚未載入模型" }
            val dec = checkNotNull(decoderSession) { "LocalNpuAsrEngine 尚未載入模型" }

            val inferStart = SystemClock.elapsedRealtime()
            val audioDurationMs = (pcm16kMono.size * 1000L) / SAMPLE_RATE

            val paddedFloat = FloatArray(MAX_SAMPLES)
            val copySamples = minOf(pcm16kMono.size, MAX_SAMPLES)
            for (i in 0 until copySamples) {
                paddedFloat[i] = pcm16kMono[i] / 32768.0f
            }
            val melFeatures = melExtractor.extract(paddedFloat)

            val encInputName = enc.inputNames.firstOrNull() ?: "mel"
            val generatedTokens = mutableListOf<Int>()

            OnnxTensor.createTensor(
                ortEnv,
                FloatBuffer.wrap(melFeatures),
                longArrayOf(1L, N_MELS.toLong(), MEL_FRAMES.toLong())
            ).use { melTensor ->
                enc.run(mapOf(encInputName to melTensor)).use { encResult ->
                    val encOutputTensor = encResult.get(0) as? OnnxTensor
                    if (encOutputTensor != null) {
                        runGreedyDecode(dec, encOutputTensor, generatedTokens)
                    }
                }
            }

            val decodedText = decodeTokensToText(generatedTokens).ifBlank {
                if (isFinalTrigger) "[靜音或無可辨識語音]" else "..."
            }

            val inferMs = SystemClock.elapsedRealtime() - inferStart
            val rtf = if (audioDurationMs > 0L) inferMs.toFloat() / audioDurationMs.toFloat() else 0f
            Log.d(
                TAG_PERF,
                "Backend=${activeBackend.label} seg=$segmentId final=$isFinalTrigger " +
                    "audioMs=$audioDurationMs inferMs=$inferMs rtf=${"%.3f".format(rtf)}"
            )

            SubtitleSegment(
                id = segmentId,
                text = decodedText,
                isFinal = isFinalTrigger,
                startTimeMs = startTimeMs,
                endTimeMs = endTimeMs,
                backendTag = activeBackend,
                latencyMs = inferMs
            )
        }
    }

    override fun release() {
        releaseInternal()
        Log.i(TAG_STATE, "LocalNpuAsrEngine unloaded & native memory released")
    }

    private fun releaseInternal() {
        isLoaded = false
        runCatching { encoderSession?.close() }
        runCatching { decoderSession?.close() }
        encoderSession = null
        decoderSession = null
    }

    private fun resolveFileDirectory(path: String): File {
        val trimmed = path.trim()
        return if (trimmed.startsWith("/")) {
            File(trimmed)
        } else {
            val externalRoot = context.getExternalFilesDir(null) ?: context.filesDir
            File(externalRoot, trimmed)
        }
    }

    private fun scanSafTree(treeUri: Uri): SafScanResult {
        return runCatching {
            val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeDocId)
            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_MIME_TYPE
            )
            var totalBytes = 0L
            var encId: String? = null
            var decId: String? = null
            var qnnEncId: String? = null
            var qnnDecId: String? = null
            var vocabId: String? = null

            context.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val sizeCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)
                val mimeCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)

                while (cursor.moveToNext()) {
                    val docId = cursor.getString(idCol)
                    val name = cursor.getString(nameCol) ?: continue
                    val size = if (!cursor.isNull(sizeCol)) cursor.getLong(sizeCol) else 0L
                    val mime = cursor.getString(mimeCol) ?: ""
                    if (mime != DocumentsContract.Document.MIME_TYPE_DIR) {
                        totalBytes += size
                    }
                    when (name.lowercase(Locale.US)) {
                        "encoder.onnx" -> encId = docId
                        "decoder.onnx" -> decId = docId
                        "encoder_qnn_ctx.onnx" -> qnnEncId = docId
                        "decoder_qnn_ctx.onnx" -> qnnDecId = docId
                        "vocab.json" -> vocabId = docId
                    }
                }
            }
            SafScanResult(
                exists = true,
                totalBytes = totalBytes,
                encoderDocId = encId,
                decoderDocId = decId,
                qnnEncoderDocId = qnnEncId,
                qnnDecoderDocId = qnnDecId,
                vocabDocId = vocabId
            )
        }.getOrElse {
            SafScanResult(false, 0L, null, null, null, null, null)
        }
    }

    private fun prepareSafModelsIntoCache(treeUri: Uri): Result<File> = runCatching {
        val scan = scanSafTree(treeUri)
        if (!scan.exists || (scan.encoderDocId == null && scan.qnnEncoderDocId == null)) {
            throw FileNotFoundException("找不到 encoder.onnx")
        }

        val cacheDir = File(context.cacheDir, "saf_model_cache").apply {
            if (!exists()) mkdirs()
        }

        fun copyDocIfPresent(docId: String?, targetName: String) {
            if (docId == null) return
            val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
            val targetFile = File(cacheDir, targetName)
            context.contentResolver.openInputStream(docUri)?.use { input ->
                targetFile.outputStream().use { output ->
                    input.copyTo(output, bufferSize = 64 * 1024)
                }
            } ?: throw FileNotFoundException("無法讀取 SAF 檔案: $targetName")
        }

        copyDocIfPresent(scan.encoderDocId, "encoder.onnx")
        copyDocIfPresent(scan.decoderDocId, "decoder.onnx")
        copyDocIfPresent(scan.qnnEncoderDocId, "encoder_qnn_ctx.onnx")
        copyDocIfPresent(scan.qnnDecoderDocId, "decoder_qnn_ctx.onnx")
        copyDocIfPresent(scan.vocabDocId, "vocab.json")
        cacheDir
    }

    private fun runGreedyDecode(
        dec: OrtSession,
        encHiddenTensor: OnnxTensor,
        outTokens: MutableList<Int>
    ) {
        val inputNames = dec.inputNames
        val tokenInputName = inputNames.firstOrNull { it.contains("input_ids") || it.contains("tokens") }
            ?: inputNames.first()
        val encStateInputName = inputNames.firstOrNull { it.contains("encoder") || it.contains("hidden") }

        val sequence = mutableListOf(
            DEFAULT_SOT.toLong(),
            DEFAULT_LANG_ZH.toLong(),
            DEFAULT_TASK_TRANSCRIBE.toLong(),
            DEFAULT_NO_TIMESTAMPS.toLong()
        )

        for (step in 0 until MAX_DECODE_TOKENS) {
            val idsArr = sequence.toLongArray()
            val idsTensor = OnnxTensor.createTensor(
                ortEnv,
                LongBuffer.wrap(idsArr),
                longArrayOf(1L, idsArr.size.toLong())
            )
            val inputs = HashMap<String, OnnxTensor>(2)
            inputs[tokenInputName] = idsTensor
            if (encStateInputName != null) {
                inputs[encStateInputName] = encHiddenTensor
            }

            val nextToken: Int = try {
                dec.run(inputs).use { decOut ->
                    extractLastStepArgmax(decOut.get(0).value)
                }
            } catch (e: OrtException) {
                Log.w(TAG_PERF, "Decoder step=$step stopped: ${e.message}")
                DEFAULT_EOT
            } finally {
                idsTensor.close()
            }

            if (nextToken == eotTokenId || nextToken == DEFAULT_EOT) break
            outTokens.add(nextToken)
            sequence.add(nextToken.toLong())
        }
    }

    private fun extractLastStepArgmax(rawValue: Any?): Int {
        val lastStepLogits: FloatArray = when (rawValue) {
            is Array<*> -> {
                val first = rawValue.firstOrNull()
                when (first) {
                    is Array<*> -> (first.lastOrNull() as? FloatArray) ?: return DEFAULT_EOT
                    is FloatArray -> first
                    else -> return DEFAULT_EOT
                }
            }
            else -> return DEFAULT_EOT
        }

        var bestIdx = DEFAULT_EOT
        var bestVal = Float.NEGATIVE_INFINITY
        for (i in lastStepLogits.indices) {
            if (lastStepLogits[i] > bestVal) {
                bestVal = lastStepLogits[i]
                bestIdx = i
            }
        }
        return bestIdx
    }

    private fun createSessionOptions(useQnnNpu: Boolean, numThreads: Int): OrtSession.SessionOptions {
        return OrtSession.SessionOptions().apply {
            setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            setIntraOpNumThreads(numThreads)
            setInterOpNumThreads(1)
            addConfigEntry("session.intra_op.allow_spinning", "1")

            if (useQnnNpu) {
                val qnnMap = mapOf(
                    "backend_path" to "libQnnHtp.so",
                    "htp_performance_mode" to "burst",
                    "htp_graph_finalization_optimization_mode" to "3",
                    "enable_htp_fp16_precision" to "1"
                )
                val addQnnMethod = OrtSession.SessionOptions::class.java
                    .getMethod("addQnn", Map::class.java)
                addQnnMethod.invoke(this, qnnMap)
            } else {
                runCatching {
                    addXnnpack(mapOf("intra_op_num_threads" to numThreads.toString()))
                }
            }
        }
    }

    private fun isQnnHtpSupported(): Boolean {
        val isQualcomm = Build.HARDWARE.contains("qcom", ignoreCase = true) ||
            Build.SOC_MANUFACTURER.contains("Qualcomm", ignoreCase = true)
        if (!isQualcomm) return false

        val nativeLibPath = context.applicationInfo.nativeLibraryDir
        val hasLocalQnn = File(nativeLibPath, "libQnnHtp.so").exists()
        val hasSystemQnn = File("/vendor/lib64/libQnnHtp.so").exists() ||
            File("/system/vendor/lib64/libQnnHtp.so").exists()
        return hasLocalQnn || hasSystemQnn
    }

    private fun loadTokenizerIfPresent(modelDir: File) {
        val vocabFile = File(modelDir, "vocab.json")
        if (!vocabFile.exists()) {
            idToToken = emptyMap()
            return
        }
        runCatching {
            val json = JSONObject(vocabFile.readText())
            val map = HashMap<Int, String>(json.length())
            val keys = json.keys()
            while (keys.hasNext()) {
                val token = keys.next()
                val id = json.getInt(token)
                map[id] = token
                if (token == "<|endoftext|>") eotTokenId = id
            }
            idToToken = map
        }.onFailure {
            Log.w(TAG_STATE, "vocab.json 解析失敗: ${it.message}")
        }
    }

    private fun decodeTokensToText(tokens: List<Int>): String {
        if (tokens.isEmpty()) return ""
        if (idToToken.isEmpty()) {
            return tokens.joinToString(" ") { "#$it" }
        }
        val byteStream = ByteArrayOutputStream()
        for (id in tokens) {
            val tok = idToToken[id] ?: continue
            if (tok.startsWith("<|") && tok.endsWith("|>")) continue
            for (ch in tok) {
                val b = unicodeToByte[ch]
                if (b != null) {
                    byteStream.write(b.toInt() and 0xFF)
                } else {
                    val utf8 = ch.toString().toByteArray(Charsets.UTF_8)
                    byteStream.write(utf8, 0, utf8.size)
                }
            }
        }
        return byteStream.toByteArray().toString(Charsets.UTF_8).trim()
    }

    private fun buildWhisperUnicodeToByteMap(): Map<Char, Byte> {
        val bs = mutableListOf<Int>()
        for (b in 33..126) bs.add(b)
        for (b in 161..172) bs.add(b)
        for (b in 174..255) bs.add(b)

        val cs = bs.toMutableList()
        var n = 0
        for (b in 0..255) {
            if (b !in bs) {
                bs.add(b)
                cs.add(256 + n)
                n++
            }
        }
        val map = HashMap<Char, Byte>(bs.size)
        for (i in bs.indices) {
            map[cs[i].toChar()] = bs[i].toByte()
        }
        return map
    }

    private class WhisperLogMelExtractor {
        private val fftSize = 512
        private val winSize = 400
        private val hopSize = 160
        private val nBins = fftSize / 2 + 1

        private val hannWindow = FloatArray(winSize) { i ->
            (0.5 * (1.0 - cos(2.0 * PI * i / winSize))).toFloat()
        }
        private val melFilterBank: Array<FloatArray> = buildMelFilterBank()

        fun extract(padded30sPcm: FloatArray): FloatArray {
            val melOut = FloatArray(N_MELS * MEL_FRAMES)
            val real = FloatArray(fftSize)
            val imag = FloatArray(fftSize)
            val powerSpec = FloatArray(nBins)
            var maxLogMel = -10.0f

            for (frame in 0 until MEL_FRAMES) {
                val startSample = frame * hopSize
                real.fill(0f)
                imag.fill(0f)

                for (i in 0 until winSize) {
                    val idx = startSample + i
                    if (idx < padded30sPcm.size) {
                        real[i] = padded30sPcm[idx] * hannWindow[i]
                    }
                }

                fftRadix2(real, imag)

                for (k in 0 until nBins) {
                    powerSpec[k] = real[k] * real[k] + imag[k] * imag[k]
                }

                for (m in 0 until N_MELS) {
                    val weights = melFilterBank[m]
                    var energy = 0f
                    for (k in 0 until nBins) {
                        energy += weights[k] * powerSpec[k]
                    }
                    val logVal = log10(max(energy, 1e-10f))
                    melOut[m * MEL_FRAMES + frame] = logVal
                    if (logVal > maxLogMel) maxLogMel = logVal
                }
            }

            val minClamp = maxLogMel - 8.0f
            for (i in melOut.indices) {
                val clamped = max(melOut[i], minClamp)
                melOut[i] = (clamped + 4.0f) / 4.0f
            }
            return melOut
        }

        private fun fftRadix2(real: FloatArray, imag: FloatArray) {
            val n = real.size
            var j = 0
            for (i in 1 until n) {
                var bit = n shr 1
                while (j and bit != 0) {
                    j = j xor bit
                    bit = bit shr 1
                }
                j = j xor bit
                if (i < j) {
                    val tr = real[i]; real[i] = real[j]; real[j] = tr
                    val ti = imag[i]; imag[i] = imag[j]; imag[j] = ti
                }
            }

            var len = 2
            while (len <= n) {
                val ang = -2.0 * PI / len
                val wLenReal = cos(ang).toFloat()
                val wLenImag = sin(ang).toFloat()
                var i = 0
                while (i < n) {
                    var wReal = 1f
                    var wImag = 0f
                    for (k in 0 until len / 2) {
                        val uReal = real[i + k]
                        val uImag = imag[i + k]
                        val vReal = real[i + k + len / 2] * wReal - imag[i + k + len / 2] * wImag
                        val vImag = real[i + k + len / 2] * wImag + imag[i + k + len / 2] * wReal
                        real[i + k] = uReal + vReal
                        imag[i + k] = uImag + vImag
                        real[i + k + len / 2] = uReal - vReal
                        imag[i + k + len / 2] = uImag - vImag
                        val nextWReal = wReal * wLenReal - wImag * wLenImag
                        wImag = wReal * wLenImag + wImag * wLenReal
                        wReal = nextWReal
                    }
                    i += len
                }
                len = len shl 1
            }
        }

        private fun buildMelFilterBank(): Array<FloatArray> {
            fun hzToMel(hz: Double): Double = 2595.0 * log10(1.0 + hz / 700.0)
            fun melToHz(mel: Double): Double = 700.0 * (10.0.pow(mel / 2595.0) - 1.0)

            val melMin = hzToMel(0.0)
            val melMax = hzToMel(SAMPLE_RATE / 2.0)
            val melPoints = DoubleArray(N_MELS + 2) { idx ->
                melMin + (melMax - melMin) * idx / (N_MELS + 1)
            }
            val fftFreqs = DoubleArray(nBins) { k ->
                (SAMPLE_RATE / 2.0) * k / (nBins - 1)
            }
            val hzPoints = DoubleArray(N_MELS + 2) { melToHz(melPoints[it]) }

            return Array(N_MELS) { m ->
                val fLeft = hzPoints[m]
                val fCenter = hzPoints[m + 1]
                val fRight = hzPoints[m + 2]
                val enorm = 2.0 / (fRight - fLeft)
                FloatArray(nBins) { k ->
                    val f = fftFreqs[k]
                    val weight = when {
                        f in fLeft..fCenter && fCenter > fLeft -> (f - fLeft) / (fCenter - fLeft)
                        f in fCenter..fRight && fRight > fCenter -> (fRight - f) / (fRight - fCenter)
                        else -> 0.0
                    }
                    (weight * enorm).toFloat()
                }
            }
        }
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/asr/WavFileTranscriber.kt
package com.example.offlinesubtitle.asr

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.SystemClock
import android.provider.OpenableColumns
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale
import kotlin.math.sqrt

data class FileTranscriptionReport(
    val fileName: String,
    val audioDurationMs: Long,
    val processingTimeMs: Long,
    val rtf: Float,
    val backendTag: BackendTag,
    val segments: List<SubtitleSegment>
)

class WavFileTranscriber(private val context: Context) {

    companion object {
        private const val TAG_PERF = "[ASR_PERF]"
        private const val TAG_VAD = "[ASR_VAD]"

        private const val TARGET_SAMPLE_RATE = 16_000
        private const val WINDOW_SAMPLES = 30 * TARGET_SAMPLE_RATE
        private const val OVERLAP_SAMPLES = 2 * TARGET_SAMPLE_RATE
        private const val STRIDE_SAMPLES = WINDOW_SAMPLES - OVERLAP_SAMPLES
        private const val SILENCE_RMS_THRESHOLD = 0.004f
    }

    suspend fun transcribeUri(
        uri: Uri,
        asrEngine: AsrEngine,
        onProgress: (Float) -> Unit = {}
    ): Result<FileTranscriptionReport> = withContext(Dispatchers.IO) {
        runCatching {
            val totalStartMs = SystemClock.elapsedRealtime()
            val fileName = resolveFileName(uri)

            val decodeStartMs = SystemClock.elapsedRealtime()
            val pcm16k = decodeTo16kMonoPcm(uri, fileName)
            val decodeCostMs = SystemClock.elapsedRealtime() - decodeStartMs
            require(pcm16k.isNotEmpty()) { "無法從檔案解析出有效音軌: $fileName" }

            val audioDurationMs = (pcm16k.size * 1000L) / TARGET_SAMPLE_RATE
            Log.i(
                TAG_PERF,
                "Decoded file=$fileName samples=${pcm16k.size} audioMs=$audioDurationMs decodeCost=${decodeCostMs}ms"
            )

            val segments = mutableListOf<SubtitleSegment>()
            var offset = 0
            var segId = 10_000L

            withContext(Dispatchers.Default) {
                while (offset < pcm16k.size && currentCoroutineContext().isActive) {
                    val end = minOf(offset + WINDOW_SAMPLES, pcm16k.size)
                    val chunk = pcm16k.copyOfRange(offset, end)
                    val startMs = (offset * 1000L) / TARGET_SAMPLE_RATE
                    val endMs = (end * 1000L) / TARGET_SAMPLE_RATE

                    val rms = computeRms(chunk)
                    if (rms >= SILENCE_RMS_THRESHOLD) {
                        val segment = asrEngine.transcribe(
                            pcm16kMono = chunk,
                            segmentId = segId++,
                            startTimeMs = startMs,
                            endTimeMs = endMs,
                            isFinalTrigger = true
                        )
                        segments.add(segment)
                    } else {
                        Log.d(TAG_VAD, "File chunk skipped (silence) range=${startMs}..${endMs}ms rms=${"%.4f".format(rms)}")
                    }

                    onProgress((end.toFloat() / pcm16k.size.toFloat()).coerceIn(0f, 1f))
                    if (end >= pcm16k.size) break
                    offset += STRIDE_SAMPLES
                }
            }

            val processingTimeMs = (SystemClock.elapsedRealtime() - totalStartMs).coerceAtLeast(1L)
            val rtf = if (audioDurationMs > 0L) {
                processingTimeMs.toFloat() / audioDurationMs.toFloat()
            } else {
                0f
            }

            Log.i(
                TAG_PERF,
                String.format(
                    Locale.US,
                    "FileTranscribe BENCHMARK file=%s Backend=%s audioMs=%d processMs=%d RTF=%.4f segments=%d",
                    fileName,
                    asrEngine.currentBackend.label,
                    audioDurationMs,
                    processingTimeMs,
                    rtf,
                    segments.size
                )
            )

            FileTranscriptionReport(
                fileName = fileName,
                audioDurationMs = audioDurationMs,
                processingTimeMs = processingTimeMs,
                rtf = rtf,
                backendTag = asrEngine.currentBackend,
                segments = segments
            )
        }
    }

    private fun decodeTo16kMonoPcm(uri: Uri, fileName: String): ShortArray {
        if (fileName.lowercase(Locale.US).endsWith(".wav")) {
            tryDecodeRawWav(uri)?.let { return it }
        }
        return decodeViaMediaExtractor(uri)
    }

    private fun tryDecodeRawWav(uri: Uri): ShortArray? {
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        if (bytes.size < 44) return null
        val header = String(bytes, 0, 4, Charsets.US_ASCII)
        val wave = String(bytes, 8, 4, Charsets.US_ASCII)
        if (header != "RIFF" || wave != "WAVE") return null

        val bb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var pos = 12
        var audioFormat = 1
        var channels = 1
        var sampleRate = 16_000
        var bitsPerSample = 16
        var dataOffset = -1
        var dataSize = 0

        while (pos + 8 <= bytes.size) {
            val chunkId = String(bytes, pos, 4, Charsets.US_ASCII)
            val chunkSize = bb.getInt(pos + 4)
            val payloadPos = pos + 8
            if (chunkId == "fmt " && payloadPos + 16 <= bytes.size) {
                audioFormat = bb.getShort(payloadPos).toInt() and 0xFFFF
                channels = bb.getShort(payloadPos + 2).toInt() and 0xFFFF
                sampleRate = bb.getInt(payloadPos + 4)
                bitsPerSample = bb.getShort(payloadPos + 14).toInt() and 0xFFFF
            } else if (chunkId == "data") {
                dataOffset = payloadPos
                dataSize = minOf(chunkSize, bytes.size - payloadPos)
                break
            }
            pos = payloadPos + chunkSize + (chunkSize and 1)
        }

        if (audioFormat != 1 || bitsPerSample != 16 || dataOffset < 0 || dataSize <= 0) return null

        val totalFrames = dataSize / (2 * channels)
        val monoSrc = ShortArray(totalFrames)
        for (i in 0 until totalFrames) {
            var sum = 0
            for (ch in 0 until channels) {
                sum += bb.getShort(dataOffset + (i * channels + ch) * 2).toInt()
            }
            monoSrc[i] = (sum / channels).toShort()
        }
        return resampleLinear(monoSrc, sampleRate, TARGET_SAMPLE_RATE)
    }

    private fun decodeViaMediaExtractor(uri: Uri): ShortArray {
        val extractor = MediaExtractor()
        extractor.setDataSource(context, uri, null)

        var audioTrackIndex = -1
        var trackFormat: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val fmt = extractor.getTrackFormat(i)
            val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                trackFormat = fmt
                break
            }
        }
        require(audioTrackIndex >= 0 && trackFormat != null) { "檔案中未包含音訊軌道" }
        extractor.selectTrack(audioTrackIndex)

        val mime = trackFormat.getString(MediaFormat.KEY_MIME)!!
        var srcSampleRate = trackFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var srcChannels = trackFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(trackFormat, null, null, 0)
        codec.start()

        val pcmBufferOut = ByteArrayOutputStream()
        val bufferInfo = MediaCodec.BufferInfo()
        var sawInputEos = false
        var sawOutputEos = false

        try {
            while (!sawOutputEos) {
                if (!sawInputEos) {
                    val inIdx = codec.dequeueInputBuffer(10_000L)
                    if (inIdx >= 0) {
                        val inBuf = codec.getInputBuffer(inIdx)!!
                        val sampleSize = extractor.readSampleData(inBuf, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inIdx, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            sawInputEos = true
                        } else {
                            codec.queueInputBuffer(inIdx, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIdx = codec.dequeueOutputBuffer(bufferInfo, 10_000L)
                when {
                    outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outFmt = codec.outputFormat
                        if (outFmt.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                            srcSampleRate = outFmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        }
                        if (outFmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                            srcChannels = outFmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        }
                        if (outFmt.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            pcmEncoding = outFmt.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        }
                    }
                    outIdx >= 0 -> {
                        val outBuf = codec.getOutputBuffer(outIdx)
                        if (outBuf != null && bufferInfo.size > 0) {
                            outBuf.position(bufferInfo.offset)
                            outBuf.limit(bufferInfo.offset + bufferInfo.size)
                            val chunk = ByteArray(bufferInfo.size)
                            outBuf.get(chunk)
                            pcmBufferOut.write(chunk)
                        }
                        codec.releaseOutputBuffer(outIdx, false)
                        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            sawOutputEos = true
                        }
                    }
                }
            }
        } finally {
            runCatching { codec.stop() }
            runCatching { codec.release() }
            runCatching { extractor.release() }
        }

        val rawBytes = pcmBufferOut.toByteArray()
        val monoSrc = convertRawPcmToMonoShorts(rawBytes, srcChannels.coerceAtLeast(1), pcmEncoding)
        return resampleLinear(monoSrc, srcSampleRate, TARGET_SAMPLE_RATE)
    }

    private fun convertRawPcmToMonoShorts(
        rawBytes: ByteArray,
        channels: Int,
        pcmEncoding: Int
    ): ShortArray {
        val bb = ByteBuffer.wrap(rawBytes).order(ByteOrder.LITTLE_ENDIAN)
        return if (pcmEncoding == AudioFormat.ENCODING_PCM_FLOAT) {
            val totalFloats = rawBytes.size / 4
            val totalFrames = totalFloats / channels
            ShortArray(totalFrames) { frame ->
                var sum = 0f
                for (ch in 0 until channels) {
                    sum += bb.getFloat((frame * channels + ch) * 4)
                }
                ((sum / channels).coerceIn(-1f, 1f) * Short.MAX_VALUE).toInt().toShort()
            }
        } else {
            val totalShorts = rawBytes.size / 2
            val totalFrames = totalShorts / channels
            ShortArray(totalFrames) { frame ->
                var sum = 0
                for (ch in 0 until channels) {
                    sum += bb.getShort((frame * channels + ch) * 2).toInt()
                }
                (sum / channels).toShort()
            }
        }
    }

    private fun resampleLinear(src: ShortArray, srcRate: Int, dstRate: Int): ShortArray {
        if (src.isEmpty() || srcRate == dstRate) return src
        val ratio = srcRate.toDouble() / dstRate.toDouble()
        val dstLen = (src.size / ratio).toInt().coerceAtLeast(1)
        return ShortArray(dstLen) { i ->
            val srcPos = i * ratio
            val idx0 = srcPos.toInt().coerceIn(0, src.lastIndex)
            val idx1 = (idx0 + 1).coerceIn(0, src.lastIndex)
            val frac = srcPos - idx0
            ((src[idx0] * (1.0 - frac)) + (src[idx1] * frac)).toInt().toShort()
        }
    }

    private fun computeRms(pcm: ShortArray): Float {
        var sumSq = 0.0
        for (s in pcm) {
            val norm = s / 32768.0
            sumSq += norm * norm
        }
        return sqrt(sumSq / pcm.size).toFloat()
    }

    private fun resolveFileName(uri: Uri): String {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) return cursor.getString(idx)
                }
            }
        return uri.lastPathSegment ?: "audio_sample.wav"
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/audio/SystemAudioCapture.kt
package com.example.offlinesubtitle.audio

import android.annotation.SuppressLint
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.isActive
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.sqrt

class SystemAudioCapture {

    companion object {
        private const val TAG_VAD = "[ASR_VAD]"
        private const val TAG_SERVICE = "[ASR_SERVICE]"

        const val SAMPLE_RATE = 16_000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        const val FRAME_SAMPLES = 512
        const val FRAME_BYTES = FRAME_SAMPLES * 2

        private const val SPEECH_RMS_THRESHOLD = 0.015f
        private const val HANGOVER_FRAMES = 15
        private const val ZERO_SIGNAL_WARN_FRAMES = 125
    }

    @Volatile
    private var activeRecorder: AudioRecord? = null

    fun captureFromSystemAudio(
        mediaProjection: MediaProjection,
        onZeroSignalWarning: (Boolean) -> Unit = {}
    ): Flow<AudioFrameChunk> = startInternalCapture(
        sourceTag = "SYSTEM_AUDIO",
        onZeroSignalWarning = onZeroSignalWarning
    ) { minBufBytes ->
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw UnsupportedOperationException("系統音訊擷取需要 Android 10 (API 29) 以上")
        }
        val playbackConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        AudioRecord.Builder()
            .setAudioFormat(buildAudioFormat())
            .setBufferSizeInBytes(maxOf(minBufBytes, FRAME_BYTES * 8))
            .setAudioPlaybackCaptureConfig(playbackConfig)
            .build()
    }

    @SuppressLint("MissingPermission")
    fun captureFromMicrophone(): Flow<AudioFrameChunk> = startInternalCapture(
        sourceTag = "MICROPHONE",
        onZeroSignalWarning = {}
    ) { minBufBytes ->
        AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            .setAudioFormat(buildAudioFormat())
            .setBufferSizeInBytes(maxOf(minBufBytes, FRAME_BYTES * 8))
            .build()
    }

    @SuppressLint("MissingPermission")
    private fun startInternalCapture(
        sourceTag: String,
        onZeroSignalWarning: (Boolean) -> Unit,
        createRecorder: (minBufBytes: Int) -> AudioRecord
    ): Flow<AudioFrameChunk> = flow {
        Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)

        val minBufBytes = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        require(minBufBytes > 0) { "裝置不支援 16kHz Mono 16-bit PCM" }

        val recorder = createRecorder(minBufBytes)
        check(recorder.state == AudioRecord.STATE_INITIALIZED) {
            "$sourceTag AudioRecord 初始化失敗"
        }
        activeRecorder = recorder

        val byteBuf = ByteArray(FRAME_BYTES)
        var inSpeech = false
        var silenceFrames = 0
        var speechStartMs = 0L
        var consecutiveZeroFrames = 0
        var warnedDrm = false

        Log.i(TAG_SERVICE, "SystemAudioCapture started mode=$sourceTag")
        try {
            recorder.startRecording()
            while (currentCoroutineContext().isActive) {
                val readBytes = recorder.read(byteBuf, 0, FRAME_BYTES, AudioRecord.READ_BLOCKING)
                if (readBytes == FRAME_BYTES) {
                    val pcm = ShortArray(FRAME_SAMPLES)
                    ByteBuffer.wrap(byteBuf)
                        .order(ByteOrder.LITTLE_ENDIAN)
                        .asShortBuffer()
                        .get(pcm)

                    val nowMs = SystemClock.elapsedRealtime()
                    val rms = computeRms(pcm)

                    if (sourceTag == "SYSTEM_AUDIO") {
                        if (rms < 1e-6f) {
                            consecutiveZeroFrames++
                            if (consecutiveZeroFrames >= ZERO_SIGNAL_WARN_FRAMES && !warnedDrm) {
                                warnedDrm = true
                                onZeroSignalWarning(true)
                                Log.w(TAG_VAD, "SystemAudio 連續全零訊號，目標 App 可能受 DRM 或內錄限制")
                            }
                        } else {
                            if (warnedDrm) {
                                warnedDrm = false
                                onZeroSignalWarning(false)
                            }
                            consecutiveZeroFrames = 0
                        }
                    }

                    var transition = VadTransition.NONE
                    if (rms >= SPEECH_RMS_THRESHOLD) {
                        silenceFrames = 0
                        if (!inSpeech) {
                            inSpeech = true
                            speechStartMs = nowMs
                            transition = VadTransition.SPEECH_START
                            Log.d(TAG_VAD, "[$sourceTag] VAD SPEECH_START rms=${"%.4f".format(rms)}")
                        }
                    } else if (inSpeech) {
                        silenceFrames++
                        if (silenceFrames >= HANGOVER_FRAMES) {
                            inSpeech = false
                            silenceFrames = 0
                            transition = VadTransition.SPEECH_END
                            Log.d(TAG_VAD, "[$sourceTag] VAD SPEECH_END dur=${nowMs - speechStartMs}ms")
                        }
                    }

                    emit(
                        AudioFrameChunk(
                            pcmData = pcm,
                            rmsEnergy = rms,
                            isSpeech = inSpeech,
                            transition = transition,
                            captureTimestampMs = nowMs
                        )
                    )
                } else if (readBytes < 0) {
                    Log.e(TAG_VAD, "[$sourceTag] AudioRecord.read error=$readBytes")
                    break
                }
            }
        } finally {
            releaseRecorder(recorder)
            Log.i(TAG_SERVICE, "SystemAudioCapture stopped mode=$sourceTag")
        }
    }.flowOn(Dispatchers.IO)

    fun stop() {
        activeRecorder?.let { releaseRecorder(it) }
    }

    private fun releaseRecorder(recorder: AudioRecord) {
        runCatching {
            if (recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                recorder.stop()
            }
            recorder.release()
        }
        if (activeRecorder === recorder) {
            activeRecorder = null
        }
    }

    private fun buildAudioFormat(): AudioFormat = AudioFormat.Builder()
        .setEncoding(AUDIO_FORMAT)
        .setSampleRate(SAMPLE_RATE)
        .setChannelMask(CHANNEL_CONFIG)
        .build()

    private fun computeRms(pcm: ShortArray): Float {
        var sumSq = 0.0
        for (s in pcm) {
            val norm = s / 32768.0
            sumSq += norm * norm
        }
        return sqrt(sumSq / pcm.size).toFloat()
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/audio/AudioCaptureManager.kt
package com.example.offlinesubtitle.audio

import android.media.projection.MediaProjection
import android.os.SystemClock
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.isActive
import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt

enum class AudioInputSource(val label: String) {
    MICROPHONE("麥克風"),
    SYSTEM_AUDIO("系統音訊"),
    SIMULATED_PCM("模擬音訊")
}

enum class VadTransition {
    NONE,
    SPEECH_START,
    SPEECH_END
}

data class AudioFrameChunk(
    val pcmData: ShortArray,
    val rmsEnergy: Float,
    val isSpeech: Boolean,
    val transition: VadTransition,
    val captureTimestampMs: Long
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is AudioFrameChunk) return false
        return captureTimestampMs == other.captureTimestampMs &&
            isSpeech == other.isSpeech &&
            transition == other.transition &&
            pcmData.contentEquals(other.pcmData)
    }

    override fun hashCode(): Int {
        var result = pcmData.contentHashCode()
        result = 31 * result + isSpeech.hashCode()
        result = 31 * result + transition.hashCode()
        result = 31 * result + captureTimestampMs.hashCode()
        return result
    }
}

class AudioCaptureManager {

    companion object {
        private const val TAG_VAD = "[ASR_VAD]"

        const val SAMPLE_RATE = 16_000
        const val FRAME_SAMPLES = 512
        const val FRAME_DURATION_MS = 32L

        private const val SPEECH_RMS_THRESHOLD = 0.015f
        private const val HANGOVER_FRAMES = 15
    }

    private val systemAudioCapture = SystemAudioCapture()

    fun startCapture(
        source: AudioInputSource,
        mediaProjection: MediaProjection? = null,
        onSystemZeroSignalWarning: (Boolean) -> Unit = {}
    ): Flow<AudioFrameChunk> = when (source) {
        AudioInputSource.MICROPHONE -> systemAudioCapture.captureFromMicrophone()
        AudioInputSource.SYSTEM_AUDIO -> {
            val projection = requireNotNull(mediaProjection) {
                "系統音訊模式必須先取得 MediaProjection 授權"
            }
            systemAudioCapture.captureFromSystemAudio(projection, onSystemZeroSignalWarning)
        }
        AudioInputSource.SIMULATED_PCM -> captureSimulatedAudio()
    }

    private fun captureSimulatedAudio(): Flow<AudioFrameChunk> = flow {
        var inSpeech = false
        var silenceFrames = 0
        var frameIndex = 0L
        var phase = 0.0

        Log.i(TAG_VAD, "Simulated PCM capture started (16kHz Mono)")
        try {
            while (currentCoroutineContext().isActive) {
                val loopMs = (frameIndex * FRAME_DURATION_MS) % 7_000L
                val isSpeakingPhase = loopMs < 5_500L

                val pcm = ShortArray(FRAME_SAMPLES) { idx ->
                    if (isSpeakingPhase) {
                        val freq = 240.0 + 90.0 * sin(frameIndex * 0.15)
                        val sample = sin(phase + 2.0 * PI * freq * idx / SAMPLE_RATE) * 0.28
                        (sample * Short.MAX_VALUE).toInt().toShort()
                    } else {
                        ((idx % 7 - 3) * 8).toShort()
                    }
                }
                if (isSpeakingPhase) {
                    phase += 2.0 * PI * 240.0 * FRAME_SAMPLES / SAMPLE_RATE
                }

                val rms = computeRms(pcm)
                val nowMs = SystemClock.elapsedRealtime()
                var transition = VadTransition.NONE
                if (rms >= SPEECH_RMS_THRESHOLD) {
                    silenceFrames = 0
                    if (!inSpeech) {
                        inSpeech = true
                        transition = VadTransition.SPEECH_START
                        Log.d(TAG_VAD, "[SIM] VAD SPEECH_START rms=${"%.4f".format(rms)}")
                    }
                } else if (inSpeech) {
                    silenceFrames++
                    if (silenceFrames >= HANGOVER_FRAMES) {
                        inSpeech = false
                        silenceFrames = 0
                        transition = VadTransition.SPEECH_END
                        Log.d(TAG_VAD, "[SIM] VAD SPEECH_END")
                    }
                }

                emit(AudioFrameChunk(pcm, rms, inSpeech, transition, nowMs))
                frameIndex++
                delay(FRAME_DURATION_MS)
            }
        } finally {
            Log.i(TAG_VAD, "Simulated PCM capture stopped")
        }
    }.flowOn(Dispatchers.IO)

    fun stop() {
        systemAudioCapture.stop()
    }

    private fun computeRms(pcm: ShortArray): Float {
        var sumSq = 0.0
        for (s in pcm) {
            val norm = s / 32768.0
            sumSq += norm * norm
        }
        return sqrt(sumSq / pcm.size).toFloat()
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/subtitle/SubtitleStateManager.kt
package com.example.offlinesubtitle.subtitle

import android.media.projection.MediaProjection
import android.os.SystemClock
import android.util.Log
import com.example.offlinesubtitle.asr.AsrEngine
import com.example.offlinesubtitle.asr.BackendTag
import com.example.offlinesubtitle.asr.FileTranscriptionReport
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.asr.LocalNpuAsrEngine
import com.example.offlinesubtitle.asr.SubtitleSegment
import com.example.offlinesubtitle.audio.AudioCaptureManager
import com.example.offlinesubtitle.audio.AudioFrameChunk
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.audio.VadTransition
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.abs

data class SubtitleUiState(
    val isRunning: Boolean = false,
    val isFileTranscribing: Boolean = false,
    val fileTranscribeProgress: Float = 0f,
    val inputSource: AudioInputSource = AudioInputSource.MICROPHONE,
    val backendTag: BackendTag = BackendTag.QNN_NPU,
    val activeEngineLabel: String = "Mock NPU",
    val currentModelPath: String = "",
    val isCustomModelPath: Boolean = false,
    val modelPathError: String? = null,
    val modelPathAlertEventId: Long = 0L,
    val isModelLoaded: Boolean = true,
    val modelsDiskSizeMb: Double = 0.0,
    val isSpeechActive: Boolean = false,
    val latestRms: Float = 0f,
    val lastLatencyMs: Long = 0L,
    val lastRtf: Float = 0f,
    val activeWindowSec: Float = 0f,
    val timelineDriftMs: Long = 0L,
    val pssMemoryMb: Float = 0f,
    val isOverlayActive: Boolean = false,
    val systemAudioSilentWarning: Boolean = false,
    val segments: List<SubtitleSegment> = emptyList(),
    val statusMessage: String = "待命中"
)

class SubtitleStateManager(
    private val audioCaptureManager: AudioCaptureManager,
    initialEngine: AsrEngine,
    private val localNpuAsrEngine: LocalNpuAsrEngine? = null
) {
    companion object {
        private const val TAG_PERF = "[ASR_PERF]"
        private const val TAG_STATE = "[ASR_STATE]"

        const val SAMPLE_RATE = AudioCaptureManager.SAMPLE_RATE
        const val MAX_WINDOW_SAMPLES = 30 * SAMPLE_RATE
        const val OVERLAP_SAMPLES = 2 * SAMPLE_RATE
        private const val MIN_INFER_SAMPLES = 3_200
        private const val DRAFT_INTERVAL_MS = 500L
        private const val DRIFT_CORRECTION_THRESHOLD_MS = 180L
    }

    private sealed class InferTask {
        abstract val pcmSnapshot: ShortArray
        abstract val segmentId: Long
        abstract val startTimeMs: Long
        abstract val endTimeMs: Long
        abstract val audioEntryTimestampMs: Long

        data class Draft(
            override val pcmSnapshot: ShortArray,
            override val segmentId: Long,
            override val startTimeMs: Long,
            override val endTimeMs: Long,
            override val audioEntryTimestampMs: Long
        ) : InferTask()

        data class Final(
            override val pcmSnapshot: ShortArray,
            override val segmentId: Long,
            override val startTimeMs: Long,
            override val endTimeMs: Long,
            override val audioEntryTimestampMs: Long,
            val reason: String
        ) : InferTask()
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val bufferMutex = Mutex()
    private val segmentIdGen = AtomicLong(0L)
    private val alertEventGen = AtomicLong(0L)
    private val isDraftInFlight = AtomicBoolean(false)

    @Volatile
    private var activeAsrEngine: AsrEngine = initialEngine

    private val windowBuffer = ShortArray(MAX_WINDOW_SAMPLES + SAMPLE_RATE)
    private var windowSampleCount = 0
    private var windowStartTotalSamples = 0L
    private var totalCapturedSamples = 0L
    private var sessionStartElapsedMs = 0L
    private var accumulatedDriftCorrectionMs = 0L
    private var currentActiveSegmentId = 0L
    private var lastDraftDispatchMs = 0L
    private var hasSpeechInWindow = false

    private var captureJob: Job? = null
    private var inferConsumerJob: Job? = null
    private var inferChannel = Channel<InferTask>(Channel.UNLIMITED)

    private val initialLocation = localNpuAsrEngine?.inspectModelLocation()

    private val _uiState = MutableStateFlow(
        SubtitleUiState(
            backendTag = initialEngine.currentBackend,
            currentModelPath = initialLocation?.activePath ?: "",
            isCustomModelPath = initialLocation?.isCustomPath ?: false,
            modelsDiskSizeMb = initialLocation?.diskUsageMb ?: 0.0
        )
    )
    val uiState: StateFlow<SubtitleUiState> = _uiState.asStateFlow()

    fun getCurrentEngine(): AsrEngine = activeAsrEngine

    /**
     * 套用自訂模型路徑（文字輸入或 SAF URI），立即 refreshModelDiskUsage 並檢查是否存在 encoder.onnx。
     */
    fun applyCustomModelPath(path: String) {
        val local = localNpuAsrEngine ?: return
        local.setCustomModelPath(path)
        refreshModelDiskUsage(validateAndAlert = true)
    }

    /**
     * 清除 SharedPreferences 中的 custom_model_path，恢復為 getExternalFilesDir(null)/models/whisper-tiny。
     */
    fun resetModelPathToDefault() {
        val local = localNpuAsrEngine ?: return
        local.resetCustomModelPath()
        refreshModelDiskUsage(validateAndAlert = true)
    }

    fun refreshModelDiskUsage(validateAndAlert: Boolean = false) {
        val local = localNpuAsrEngine ?: return
        val status = local.inspectModelLocation()
        val shouldAlert = validateAndAlert && status.errorMessage != null

        _uiState.update { state ->
            state.copy(
                currentModelPath = status.activePath,
                isCustomModelPath = status.isCustomPath,
                modelsDiskSizeMb = status.diskUsageMb,
                modelPathError = if (validateAndAlert) status.errorMessage else if (status.hasEncoderOnnx) null else state.modelPathError,
                modelPathAlertEventId = if (shouldAlert) alertEventGen.incrementAndGet() else state.modelPathAlertEventId,
                statusMessage = if (validateAndAlert) {
                    status.errorMessage ?: String.format(
                        Locale.US,
                        "已套用模型路徑 (%.1f MB)",
                        status.diskUsageMb
                    )
                } else {
                    state.statusMessage
                }
            )
        }
    }

    fun setOverlayActive(active: Boolean) {
        _uiState.update { it.copy(isOverlayActive = active) }
    }

    fun setInputSource(source: AudioInputSource) {
        _uiState.update { it.copy(inputSource = source) }
    }

    fun setBackendMode(backend: BackendTag) {
        activeAsrEngine.setBackendMode(backend)
        _uiState.update { it.copy(backendTag = backend) }
    }

    fun switchToEngine(engine: AsrEngine, label: String, localProfile: LocalModelProfile? = null) {
        if (_uiState.value.isRunning || _uiState.value.isFileTranscribing) return

        scope.launch {
            _uiState.update { it.copy(statusMessage = "正在切換模型: $label...") }
            if (activeAsrEngine !== engine) {
                activeAsrEngine.release()
            }
            if (engine is LocalNpuAsrEngine && localProfile != null) {
                engine.setProfile(localProfile)
            }

            // 載入前先讀取 custom_model_path（若有則用自訂，無則用預設）並更新磁碟用量
            val locStatus = localNpuAsrEngine?.inspectModelLocation()
            val initResult = engine.initialize()
            val updatedStatus = localNpuAsrEngine?.inspectModelLocation() ?: locStatus
            activeAsrEngine = engine

            if (initResult.isSuccess) {
                _uiState.update {
                    it.copy(
                        activeEngineLabel = label,
                        backendTag = engine.currentBackend,
                        isModelLoaded = true,
                        currentModelPath = updatedStatus?.activePath ?: it.currentModelPath,
                        isCustomModelPath = updatedStatus?.isCustomPath ?: it.isCustomModelPath,
                        modelPathError = null,
                        modelsDiskSizeMb = updatedStatus?.diskUsageMb ?: 0.0,
                        statusMessage = "已載入 $label (${engine.currentBackend.label})"
                    )
                }
            } else {
                val errMsg = initResult.exceptionOrNull()?.message ?: "找不到 encoder.onnx"
                _uiState.update {
                    it.copy(
                        activeEngineLabel = label,
                        isModelLoaded = false,
                        currentModelPath = updatedStatus?.activePath ?: it.currentModelPath,
                        isCustomModelPath = updatedStatus?.isCustomPath ?: it.isCustomModelPath,
                        modelPathError = errMsg,
                        modelPathAlertEventId = alertEventGen.incrementAndGet(),
                        modelsDiskSizeMb = updatedStatus?.diskUsageMb ?: 0.0,
                        statusMessage = errMsg
                    )
                }
            }
        }
    }

    fun unloadCurrentModel() {
        if (_uiState.value.isRunning || _uiState.value.isFileTranscribing) return
        activeAsrEngine.release()
        _uiState.update {
            it.copy(
                isModelLoaded = false,
                modelsDiskSizeMb = localNpuAsrEngine?.calculateModelsDiskUsageMb() ?: 0.0,
                statusMessage = "已卸載模型並釋放記憶體"
            )
        }
    }

    fun clearSubtitles() {
        _uiState.update { it.copy(segments = emptyList(), lastLatencyMs = 0L, lastRtf = 0f) }
    }

    fun editSegmentText(segmentId: Long, newText: String) {
        val trimmed = newText.trim()
        if (trimmed.isEmpty()) return
        _uiState.update { state ->
            val updated = state.segments.map { seg ->
                if (seg.id == segmentId) seg.copy(text = trimmed) else seg
            }
            state.copy(segments = updated, statusMessage = "已更新第 #$segmentId 句字幕")
        }
        Log.i(TAG_STATE, "Edited segment id=$segmentId")
    }

    fun injectBuiltInTestSegments() {
        val baseId = segmentIdGen.addAndGet(100L)
        val mockSegments = listOf(
            SubtitleSegment(
                id = baseId + 1,
                text = "歡迎使用 Snapdragon 8s Gen 4 離線即時字幕原型系統。",
                isFinal = true,
                startTimeMs = 0L,
                endTimeMs = 3_400L,
                backendTag = BackendTag.QNN_NPU,
                latencyMs = 112L
            ),
            SubtitleSegment(
                id = baseId + 2,
                text = "這一句刻意帶有 400ms 時間軸重疊，用來測試 SubtitleExporter 連續性自動修正。",
                isFinal = true,
                startTimeMs = 3_000L,
                endTimeMs = 7_200L,
                backendTag = BackendTag.QNN_NPU,
                latencyMs = 135L
            ),
            SubtitleSegment(
                id = baseId + 3,
                text = "目前模型路徑設定為 ${_uiState.value.currentModelPath}，並透過 OfflineSubtitleBridge 雙向同步。",
                isFinal = true,
                startTimeMs = 7_500L,
                endTimeMs = 11_800L,
                backendTag = BackendTag.QNN_NPU,
                latencyMs = 128L
            ),
            SubtitleSegment(
                id = baseId + 4,
                text = "最後這一段將測試 SRT、VTT 與 TXT 匯出格式與關鍵字 Search 高亮功能。",
                isFinal = true,
                startTimeMs = 12_100L,
                endTimeMs = 16_000L,
                backendTag = BackendTag.CPU_FALLBACK,
                latencyMs = 410L
            )
        )
        _uiState.update {
            it.copy(
                segments = mockSegments,
                lastLatencyMs = 128L,
                lastRtf = 0.042f,
                statusMessage = "已載入內建測試模式資料（含故意重疊時間軸供匯出校驗）"
            )
        }
        Log.i(TAG_STATE, "Injected built-in test segments count=${mockSegments.size}")
    }

    fun updateServiceHeartbeatMetrics(pssMemoryMb: Float) {
        if (!_uiState.value.isRunning || sessionStartElapsedMs == 0L) {
            _uiState.update { it.copy(pssMemoryMb = pssMemoryMb) }
            return
        }
        val wallElapsedMs = SystemClock.elapsedRealtime() - sessionStartElapsedMs
        val audioClockMs = samplesToMs(totalCapturedSamples) + accumulatedDriftCorrectionMs
        val driftMs = wallElapsedMs - audioClockMs

        if (abs(driftMs) >= DRIFT_CORRECTION_THRESHOLD_MS) {
            accumulatedDriftCorrectionMs += driftMs
            Log.w(
                TAG_STATE,
                "Timeline drift corrected: rawDrift=${driftMs}ms, totalCorrection=${accumulatedDriftCorrectionMs}ms"
            )
        }

        _uiState.update {
            it.copy(
                timelineDriftMs = driftMs,
                pssMemoryMb = pssMemoryMb
            )
        }
    }

    fun onFileTranscribeStarted(fileName: String) {
        _uiState.update {
            it.copy(
                isFileTranscribing = true,
                fileTranscribeProgress = 0f,
                statusMessage = "正在離線轉錄: $fileName..."
            )
        }
    }

    fun onFileTranscribeProgress(progress: Float) {
        _uiState.update { it.copy(fileTranscribeProgress = progress) }
    }

    fun onFileTranscribeCompleted(report: FileTranscriptionReport) {
        _uiState.update {
            it.copy(
                isFileTranscribing = false,
                fileTranscribeProgress = 1f,
                lastRtf = report.rtf,
                backendTag = report.backendTag,
                segments = report.segments,
                statusMessage = String.format(
                    Locale.US,
                    "轉錄完成: %s (時長 %.1fs / 耗時 %.1fs / RTF %.3f)",
                    report.fileName,
                    report.audioDurationMs / 1000f,
                    report.processingTimeMs / 1000f,
                    report.rtf
                )
            )
        }
    }

    fun onFileTranscribeFailed(errorMessage: String) {
        _uiState.update {
            it.copy(
                isFileTranscribing = false,
                fileTranscribeProgress = 0f,
                statusMessage = "音檔轉錄失敗: $errorMessage"
            )
        }
    }

    fun start(mediaProjection: MediaProjection? = null) {
        if (_uiState.value.isRunning || _uiState.value.isFileTranscribing) return

        scope.launch {
            if (!_uiState.value.isModelLoaded) {
                val initRes = activeAsrEngine.initialize()
                if (initRes.isFailure) {
                    val err = initRes.exceptionOrNull()?.message ?: "找不到 encoder.onnx"
                    _uiState.update {
                        it.copy(
                            modelPathError = err,
                            modelPathAlertEventId = alertEventGen.incrementAndGet(),
                            statusMessage = err
                        )
                    }
                    return@launch
                }
                _uiState.update {
                    it.copy(
                        isModelLoaded = true,
                        modelPathError = null,
                        backendTag = activeAsrEngine.currentBackend
                    )
                }
            }

            resetWindowCounters()
            sessionStartElapsedMs = SystemClock.elapsedRealtime()
            inferChannel.close()
            inferChannel = Channel(Channel.UNLIMITED)
            startInferConsumer()

            val source = _uiState.value.inputSource
            _uiState.update {
                it.copy(
                    isRunning = true,
                    systemAudioSilentWarning = false,
                    statusMessage = "背景服務運行中：${source.label}"
                )
            }
            Log.i(TAG_STATE, "Subtitle pipeline started, source=${source.label}")

            captureJob = scope.launch {
                try {
                    audioCaptureManager.startCapture(
                        source = source,
                        mediaProjection = mediaProjection,
                        onSystemZeroSignalWarning = { warn ->
                            _uiState.update { it.copy(systemAudioSilentWarning = warn) }
                        }
                    ).collect { chunk ->
                        handleAudioChunk(chunk)
                    }
                } catch (e: Exception) {
                    Log.e(TAG_STATE, "Audio pipeline error: ${e.message}", e)
                    _uiState.update {
                        it.copy(
                            isRunning = false,
                            isSpeechActive = false,
                            statusMessage = "錯誤：${e.message ?: "音訊擷取失敗"}"
                        )
                    }
                }
            }
        }
    }

    fun stop() {
        if (!_uiState.value.isRunning && captureJob == null) return

        captureJob?.cancel()
        captureJob = null
        audioCaptureManager.stop()

        scope.launch {
            flushRemainingAsFinal()
            inferChannel.close()
            inferConsumerJob?.join()
            inferConsumerJob = null

            _uiState.update {
                it.copy(
                    isRunning = false,
                    isSpeechActive = false,
                    activeWindowSec = 0f,
                    systemAudioSilentWarning = false,
                    statusMessage = "已停止"
                )
            }
            Log.i(TAG_STATE, "Subtitle pipeline stopped")
        }
    }

    fun release() {
        stop()
        activeAsrEngine.release()
    }

    private fun startInferConsumer() {
        inferConsumerJob = scope.launch(Dispatchers.Default) {
            for (task in inferChannel) {
                val isFinal = task is InferTask.Final
                val audioDurationMs = (task.pcmSnapshot.size * 1000L) / SAMPLE_RATE
                val segment = activeAsrEngine.transcribe(
                    pcm16kMono = task.pcmSnapshot,
                    segmentId = task.segmentId,
                    startTimeMs = task.startTimeMs,
                    endTimeMs = task.endTimeMs,
                    isFinalTrigger = isFinal
                )

                val endToEndLatencyMs = SystemClock.elapsedRealtime() - task.audioEntryTimestampMs
                val updatedSegment = segment.copy(latencyMs = endToEndLatencyMs)
                val rtf = if (audioDurationMs > 0L) {
                    segment.latencyMs.toFloat() / audioDurationMs.toFloat()
                } else {
                    0f
                }

                if (isFinal) {
                    val reason = (task as InferTask.Final).reason
                    Log.i(
                        TAG_PERF,
                        "FINAL committed id=${updatedSegment.id} reason=$reason " +
                            "e2eLatency=${endToEndLatencyMs}ms rtf=${"%.3f".format(rtf)} Backend=${updatedSegment.backendTag.label}"
                    )
                } else {
                    isDraftInFlight.set(false)
                    Log.d(
                        TAG_PERF,
                        "DRAFT emitted id=${updatedSegment.id} e2eLatency=${endToEndLatencyMs}ms Backend=${updatedSegment.backendTag.label}"
                    )
                }

                applySegmentToState(updatedSegment, rtf)
            }
        }
    }

    private suspend fun handleAudioChunk(chunk: AudioFrameChunk) {
        var taskToEnqueue: InferTask? = null

        bufferMutex.withLock {
            val incoming = chunk.pcmData
            totalCapturedSamples += incoming.size

            when (chunk.transition) {
                VadTransition.SPEECH_START -> {
                    if (!hasSpeechInWindow) {
                        windowSampleCount = 0
                        windowStartTotalSamples = totalCapturedSamples - incoming.size
                        currentActiveSegmentId = segmentIdGen.incrementAndGet()
                        hasSpeechInWindow = true
                        lastDraftDispatchMs = chunk.captureTimestampMs
                    }
                }

                VadTransition.SPEECH_END -> {
                    if (hasSpeechInWindow && windowSampleCount >= MIN_INFER_SAMPLES) {
                        val snapshot = windowBuffer.copyOf(windowSampleCount)
                        val startMs = samplesToCorrectedMs(windowStartTotalSamples)
                        val endMs = samplesToCorrectedMs(windowStartTotalSamples + windowSampleCount)
                        taskToEnqueue = InferTask.Final(
                            pcmSnapshot = snapshot,
                            segmentId = currentActiveSegmentId,
                            startTimeMs = startMs,
                            endTimeMs = endMs,
                            audioEntryTimestampMs = chunk.captureTimestampMs,
                            reason = "VAD_SPEECH_END"
                        )
                    }
                    windowSampleCount = 0
                    hasSpeechInWindow = false
                }

                VadTransition.NONE -> Unit
            }

            if (chunk.isSpeech || hasSpeechInWindow) {
                val copyLen = minOf(incoming.size, windowBuffer.size - windowSampleCount)
                if (copyLen > 0) {
                    incoming.copyInto(windowBuffer, destinationOffset = windowSampleCount, endIndex = copyLen)
                    windowSampleCount += copyLen
                }

                if (windowSampleCount >= MAX_WINDOW_SAMPLES) {
                    val snapshot = windowBuffer.copyOf(MAX_WINDOW_SAMPLES)
                    val startMs = samplesToCorrectedMs(windowStartTotalSamples)
                    val endMs = samplesToCorrectedMs(windowStartTotalSamples + MAX_WINDOW_SAMPLES)
                    val finalizedId = currentActiveSegmentId

                    val shiftFrom = MAX_WINDOW_SAMPLES - OVERLAP_SAMPLES
                    System.arraycopy(windowBuffer, shiftFrom, windowBuffer, 0, OVERLAP_SAMPLES)
                    windowSampleCount = OVERLAP_SAMPLES
                    windowStartTotalSamples += shiftFrom
                    currentActiveSegmentId = segmentIdGen.incrementAndGet()
                    lastDraftDispatchMs = chunk.captureTimestampMs

                    Log.i(TAG_STATE, "30s boundary split: finalizedId=$finalizedId -> nextId=$currentActiveSegmentId")

                    taskToEnqueue = InferTask.Final(
                        pcmSnapshot = snapshot,
                        segmentId = finalizedId,
                        startTimeMs = startMs,
                        endTimeMs = endMs,
                        audioEntryTimestampMs = chunk.captureTimestampMs,
                        reason = "30S_BOUNDARY_OVERLAP"
                    )
                } else if (
                    chunk.transition == VadTransition.NONE &&
                    hasSpeechInWindow &&
                    windowSampleCount >= MIN_INFER_SAMPLES &&
                    (chunk.captureTimestampMs - lastDraftDispatchMs >= DRAFT_INTERVAL_MS) &&
                    isDraftInFlight.compareAndSet(false, true)
                ) {
                    val snapshot = windowBuffer.copyOf(windowSampleCount)
                    val startMs = samplesToCorrectedMs(windowStartTotalSamples)
                    val endMs = samplesToCorrectedMs(windowStartTotalSamples + windowSampleCount)
                    lastDraftDispatchMs = chunk.captureTimestampMs

                    taskToEnqueue = InferTask.Draft(
                        pcmSnapshot = snapshot,
                        segmentId = currentActiveSegmentId,
                        startTimeMs = startMs,
                        endTimeMs = endMs,
                        audioEntryTimestampMs = chunk.captureTimestampMs
                    )
                }
            }

            val currentWindowSec = windowSampleCount.toFloat() / SAMPLE_RATE.toFloat()
            _uiState.update { state ->
                state.copy(
                    isSpeechActive = chunk.isSpeech,
                    latestRms = chunk.rmsEnergy,
                    activeWindowSec = currentWindowSec
                )
            }
        }

        taskToEnqueue?.let { task ->
            val sent = inferChannel.trySend(task).isSuccess
            if (!sent && task is InferTask.Draft) {
                isDraftInFlight.set(false)
            }
        }
    }

    private suspend fun flushRemainingAsFinal() {
        val flushTask: InferTask.Final? = bufferMutex.withLock {
            if (hasSpeechInWindow && windowSampleCount >= MIN_INFER_SAMPLES) {
                val snapshot = windowBuffer.copyOf(windowSampleCount)
                val startMs = samplesToCorrectedMs(windowStartTotalSamples)
                val endMs = samplesToCorrectedMs(windowStartTotalSamples + windowSampleCount)
                val segId = currentActiveSegmentId
                windowSampleCount = 0
                hasSpeechInWindow = false
                InferTask.Final(
                    pcmSnapshot = snapshot,
                    segmentId = segId,
                    startTimeMs = startMs,
                    endTimeMs = endMs,
                    audioEntryTimestampMs = SystemClock.elapsedRealtime(),
                    reason = "MANUAL_STOP_FLUSH"
                )
            } else {
                windowSampleCount = 0
                hasSpeechInWindow = false
                null
            }
        }

        if (flushTask != null) {
            inferChannel.trySend(flushTask)
        }
    }

    private fun applySegmentToState(incoming: SubtitleSegment, rtf: Float) {
        _uiState.update { state ->
            val currentList = state.segments.toMutableList()
            val existingIdx = currentList.indexOfFirst { it.id == incoming.id }

            if (existingIdx >= 0) {
                val existing = currentList[existingIdx]
                if (!existing.isFinal || incoming.isFinal) {
                    currentList[existingIdx] = incoming
                }
            } else {
                currentList.add(incoming)
            }

            state.copy(
                segments = currentList,
                lastLatencyMs = incoming.latencyMs,
                lastRtf = rtf,
                backendTag = incoming.backendTag
            )
        }
    }

    private fun resetWindowCounters() {
        windowSampleCount = 0
        windowStartTotalSamples = 0L
        totalCapturedSamples = 0L
        accumulatedDriftCorrectionMs = 0L
        hasSpeechInWindow = false
        lastDraftDispatchMs = 0L
        isDraftInFlight.set(false)
    }

    private fun samplesToMs(samples: Long): Long = (samples * 1000L) / SAMPLE_RATE

    private fun samplesToCorrectedMs(samples: Long): Long =
        (samplesToMs(samples) + accumulatedDriftCorrectionMs).coerceAtLeast(0L)
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/service/SubtitleForegroundService.kt
package com.example.offlinesubtitle.service

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Debug
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import com.example.offlinesubtitle.MainActivity
import com.example.offlinesubtitle.asr.LocalNpuAsrEngine
import com.example.offlinesubtitle.asr.MockNpuAsrEngine
import com.example.offlinesubtitle.audio.AudioCaptureManager
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.bridge.OfflineSubtitleBridge
import com.example.offlinesubtitle.subtitle.SubtitleStateManager
import com.example.offlinesubtitle.ui.FloatingSubtitleOverlay
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

object SubtitleRuntimeCoordinator {
    @Volatile
    private var stateManager: SubtitleStateManager? = null
    @Volatile
    private var mockEngine: MockNpuAsrEngine? = null
    @Volatile
    private var localEngine: LocalNpuAsrEngine? = null
    @Volatile
    private var bridge: OfflineSubtitleBridge? = null

    fun getOrCreateStateManager(appContext: Context): SubtitleStateManager {
        return stateManager ?: synchronized(this) {
            stateManager ?: run {
                val ctx = appContext.applicationContext
                val mock = getMockEngine()
                val local = getLocalEngine(ctx)
                SubtitleStateManager(
                    audioCaptureManager = AudioCaptureManager(),
                    initialEngine = mock,
                    localNpuAsrEngine = local
                ).also { stateManager = it }
            }
        }
    }

    fun getMockEngine(): MockNpuAsrEngine = mockEngine ?: synchronized(this) {
        mockEngine ?: MockNpuAsrEngine().also { mockEngine = it }
    }

    fun getLocalEngine(appContext: Context): LocalNpuAsrEngine = localEngine ?: synchronized(this) {
        localEngine ?: LocalNpuAsrEngine(appContext.applicationContext).also { localEngine = it }
    }

    fun getOrCreateBridge(appContext: Context): OfflineSubtitleBridge = bridge ?: synchronized(this) {
        bridge ?: run {
            val ctx = appContext.applicationContext
            val manager = getOrCreateStateManager(ctx)
            OfflineSubtitleBridge(
                appContext = ctx,
                stateManager = manager,
                mockAsrEngine = getMockEngine(),
                localNpuAsrEngine = getLocalEngine(ctx)
            ).also { bridge = it }
        }
    }
}

class SubtitleForegroundService : LifecycleService() {

    companion object {
        private const val TAG_SERVICE = "[ASR_SERVICE]"
        private const val CHANNEL_ID = "offline_subtitle_channel"
        private const val NOTIFICATION_ID = 1001
        private const val HEARTBEAT_INTERVAL_MS = 15_000L

        const val ACTION_START_MIC = "com.example.offlinesubtitle.action.START_MIC"
        const val ACTION_START_SIMULATED = "com.example.offlinesubtitle.action.START_SIMULATED"
        const val ACTION_START_SYSTEM_AUDIO = "com.example.offlinesubtitle.action.START_SYSTEM_AUDIO"
        const val ACTION_STOP = "com.example.offlinesubtitle.action.STOP"
        const val ACTION_SHOW_OVERLAY = "com.example.offlinesubtitle.action.SHOW_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.example.offlinesubtitle.action.HIDE_OVERLAY"

        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_RESULT_DATA = "extra_result_data"
    }

    inner class LocalBinder : Binder() {
        fun getService(): SubtitleForegroundService = this@SubtitleForegroundService
    }

    private val binder = LocalBinder()
    private lateinit var stateManager: SubtitleStateManager
    private lateinit var bridge: OfflineSubtitleBridge
    private lateinit var floatingOverlay: FloatingSubtitleOverlay

    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaProjection: MediaProjection? = null
    private var heartbeatJob: Job? = null
    private var serviceStartElapsedMs: Long = 0L

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            Log.w(TAG_SERVICE, "MediaProjection stopped by system")
            stopPipelineAndService()
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        stateManager = SubtitleRuntimeCoordinator.getOrCreateStateManager(applicationContext)
        bridge = SubtitleRuntimeCoordinator.getOrCreateBridge(applicationContext)
        floatingOverlay = FloatingSubtitleOverlay(
            context = applicationContext,
            stateManager = stateManager,
            onSwitchSourceRequest = { nextSource ->
                handleOverlaySourceSwitch(nextSource)
            },
            onCloseOverlay = {
                hideOverlay()
            }
        )
        bridge.notifyServiceLifecycle("CREATED")
        Log.i(TAG_SERVICE, "SubtitleForegroundService created")
    }

    override fun onBind(intent: Intent): IBinder {
        super.onBind(intent)
        return binder
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        when (intent?.action) {
            ACTION_START_MIC -> startMicOrSimMode(AudioInputSource.MICROPHONE)
            ACTION_START_SIMULATED -> startMicOrSimMode(AudioInputSource.SIMULATED_PCM)
            ACTION_START_SYSTEM_AUDIO -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
                @Suppress("DEPRECATION")
                val resultData = intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
                if (resultCode == Activity.RESULT_OK && resultData != null) {
                    startSystemAudioMode(resultCode, resultData)
                } else {
                    Log.e(TAG_SERVICE, "MediaProjection intent invalid, stopping service")
                    stopSelf()
                }
            }
            ACTION_SHOW_OVERLAY -> {
                ensureForegroundForOverlayIfIdle()
                showOverlay()
            }
            ACTION_HIDE_OVERLAY -> hideOverlay()
            ACTION_STOP -> stopPipelineAndService()
        }
        return START_NOT_STICKY
    }

    private fun startMicOrSimMode(source: AudioInputSource) {
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification("即時字幕運作中（${source.label}）"),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        )
        acquireWakeLock()
        startHeartbeat()
        stateManager.setInputSource(source)
        stateManager.start()
        bridge.notifyServiceLifecycle("RUNNING_${source.name}")
        Log.i(TAG_SERVICE, "ForegroundService started with MICROPHONE type, source=${source.name}")
    }

    private fun startSystemAudioMode(resultCode: Int, resultData: Intent) {
        val fgsType = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification("系統音訊字幕擷取中 (MediaProjection)"),
            fgsType
        )

        val projectionManager = getSystemService(MediaProjectionManager::class.java)
        mediaProjection?.unregisterCallback(projectionCallback)
        mediaProjection?.stop()

        val projection = projectionManager.getMediaProjection(resultCode, resultData)
        projection.registerCallback(projectionCallback, null)
        mediaProjection = projection

        acquireWakeLock()
        startHeartbeat()
        stateManager.setInputSource(AudioInputSource.SYSTEM_AUDIO)
        stateManager.start(mediaProjection = projection)
        bridge.notifyServiceLifecycle("RUNNING_SYSTEM_AUDIO")
        Log.i(TAG_SERVICE, "ForegroundService started with MEDIA_PROJECTION type")
    }

    private fun ensureForegroundForOverlayIfIdle() {
        if (stateManager.uiState.value.isRunning) return
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification("懸浮字幕視窗待命中"),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        )
        acquireWakeLock()
        startHeartbeat()
        bridge.notifyServiceLifecycle("OVERLAY_STANDBY")
    }

    private fun handleOverlaySourceSwitch(nextSource: AudioInputSource) {
        if (nextSource == AudioInputSource.SYSTEM_AUDIO && mediaProjection == null) {
            Log.w(TAG_SERVICE, "Cannot switch to SYSTEM_AUDIO from overlay without MediaProjection consent")
            return
        }
        stateManager.stop()
        stateManager.setInputSource(nextSource)
        if (nextSource == AudioInputSource.SYSTEM_AUDIO) {
            stateManager.start(mediaProjection = mediaProjection)
        } else {
            stateManager.start()
        }
        bridge.notifyServiceLifecycle("SWITCHED_${nextSource.name}")
    }

    fun showOverlay() {
        floatingOverlay.show()
        stateManager.setOverlayActive(true)
        bridge.notifyServiceLifecycle("OVERLAY_SHOWN")
        Log.i(TAG_SERVICE, "FloatingSubtitleOverlay shown")
    }

    fun hideOverlay() {
        floatingOverlay.hide()
        stateManager.setOverlayActive(false)
        bridge.notifyServiceLifecycle("OVERLAY_HIDDEN")
        Log.i(TAG_SERVICE, "FloatingSubtitleOverlay hidden")
    }

    private fun stopPipelineAndService() {
        stateManager.stop()
        hideOverlay()
        releaseProjection()
        releaseWakeLock()
        heartbeatJob?.cancel()
        heartbeatJob = null
        bridge.notifyServiceLifecycle("STOPPED")
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.i(TAG_SERVICE, "SubtitleForegroundService stopped cleanly")
    }

    private fun startHeartbeat() {
        if (heartbeatJob?.isActive == true) return
        serviceStartElapsedMs = SystemClock.elapsedRealtime()
        heartbeatJob = lifecycleScope.launch {
            while (isActive) {
                val uptimeSec = (SystemClock.elapsedRealtime() - serviceStartElapsedMs) / 1000L
                val pssMb = Debug.getPss() / 1024f
                stateManager.updateServiceHeartbeatMetrics(pssMemoryMb = pssMb)
                val ui = stateManager.uiState.value
                Log.i(
                    TAG_SERVICE,
                    "HEARTBEAT uptime=${uptimeSec}s running=${ui.isRunning} " +
                        "source=${ui.inputSource.name} Backend=${ui.backendTag.label} " +
                        "drift=${ui.timelineDriftMs}ms pss=${"%.1f".format(pssMb)}MB"
                )
                delay(HEARTBEAT_INTERVAL_MS)
            }
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(PowerManager::class.java)
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "OfflineSubtitle:AsrWakeLock").apply {
            setReferenceCounted(false)
            acquire(2 * 60 * 60 * 1000L)
        }
        Log.d(TAG_SERVICE, "PARTIAL_WAKE_LOCK acquired")
    }

    private fun releaseWakeLock() {
        runCatching {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        }
        wakeLock = null
    }

    private fun releaseProjection() {
        runCatching {
            mediaProjection?.unregisterCallback(projectionCallback)
            mediaProjection?.stop()
        }
        mediaProjection = null
    }

    private fun createNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "離線即時字幕服務",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "維持背景與鎖屏期間離線字幕推論不斷線"
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(contentText: String): Notification {
        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, SubtitleForegroundService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OfflineSubtitle 離線字幕")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(openAppIntent)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_media_pause, "停止", stopIntent)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        floatingOverlay.hide()
        releaseProjection()
        releaseWakeLock()
        heartbeatJob?.cancel()
        bridge.notifyServiceLifecycle("DESTROYED")
        Log.i(TAG_SERVICE, "SubtitleForegroundService destroyed")
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/export/SubtitleExporter.kt
package com.example.offlinesubtitle.export

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import com.example.offlinesubtitle.asr.SubtitleSegment
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class SubtitleExportFormat(
    val extension: String,
    val mimeType: String,
    val label: String
) {
    SRT("srt", "application/x-subrip", "SRT"),
    VTT("vtt", "text/vtt", "VTT"),
    TXT("txt", "text/plain", "TXT")
}

data class ExportResult(
    val fileName: String,
    val shareUri: Uri,
    val downloadsUri: Uri?,
    val segmentCount: Int,
    val overlapsFixed: Int
)

class SubtitleExporter(private val context: Context) {

    companion object {
        private const val TAG_STATE = "[ASR_STATE]"
        private const val MIN_SEGMENT_DURATION_MS = 300L
    }

    data class ValidationOutput(
        val normalizedSegments: List<SubtitleSegment>,
        val overlapsFixed: Int,
        val durationsFixed: Int
    )

    fun normalizeTimeline(rawSegments: List<SubtitleSegment>): ValidationOutput {
        val sorted = rawSegments
            .filter { it.text.isNotBlank() }
            .sortedWith(compareBy<SubtitleSegment> { it.startTimeMs }.thenBy { it.id })

        val result = ArrayList<SubtitleSegment>(sorted.size)
        var overlapsFixed = 0
        var durationsFixed = 0

        for (seg in sorted) {
            var startMs = seg.startTimeMs
            var endMs = seg.endTimeMs

            if (startMs < 0L) {
                startMs = 0L
                durationsFixed++
            }

            val prev = result.lastOrNull()
            if (prev != null && startMs < prev.endTimeMs) {
                startMs = prev.endTimeMs
                overlapsFixed++
            }

            if (endMs <= startMs) {
                endMs = startMs + MIN_SEGMENT_DURATION_MS
                durationsFixed++
            }

            result.add(
                seg.copy(
                    text = seg.text.trim(),
                    startTimeMs = startMs,
                    endTimeMs = endMs
                )
            )
        }

        Log.i(
            TAG_STATE,
            "Timeline validated: count=${result.size}, overlapsFixed=$overlapsFixed, durationsFixed=$durationsFixed"
        )
        return ValidationOutput(result, overlapsFixed, durationsFixed)
    }

    fun formatContent(
        segments: List<SubtitleSegment>,
        format: SubtitleExportFormat
    ): Pair<String, ValidationOutput> {
        val validation = normalizeTimeline(segments)
        val normalized = validation.normalizedSegments

        val text = when (format) {
            SubtitleExportFormat.SRT -> buildSrt(normalized)
            SubtitleExportFormat.VTT -> buildVtt(normalized)
            SubtitleExportFormat.TXT -> buildTxt(normalized)
        }
        return text to validation
    }

    suspend fun export(
        segments: List<SubtitleSegment>,
        format: SubtitleExportFormat,
        saveToDownloads: Boolean = true
    ): Result<ExportResult> = withContext(Dispatchers.IO) {
        runCatching {
            require(segments.isNotEmpty()) { "目前沒有可匯出的字幕內容" }

            val (content, validation) = formatContent(segments, format)
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val fileName = "subtitle_$timestamp.${format.extension}"

            val exportDir = File(context.cacheDir, "exports").apply { mkdirs() }
            val cacheFile = File(exportDir, fileName)
            cacheFile.writeText(content, Charsets.UTF_8)
            val shareUri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                cacheFile
            )

            val downloadsUri = if (saveToDownloads) {
                saveFileToDownloads(fileName, format.mimeType, content)
            } else {
                null
            }

            ExportResult(
                fileName = fileName,
                shareUri = shareUri,
                downloadsUri = downloadsUri,
                segmentCount = validation.normalizedSegments.size,
                overlapsFixed = validation.overlapsFixed
            )
        }
    }

    private fun saveFileToDownloads(fileName: String, mimeType: String, utf8Content: String): Uri? {
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null

        resolver.openOutputStream(uri)?.use { out ->
            out.write(utf8Content.toByteArray(Charsets.UTF_8))
        }

        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return uri
    }

    private fun buildSrt(segments: List<SubtitleSegment>): String {
        val sb = StringBuilder()
        segments.forEachIndexed { idx, seg ->
            sb.append(idx + 1).append('\n')
            sb.append(formatSrtTime(seg.startTimeMs))
                .append(" --> ")
                .append(formatSrtTime(seg.endTimeMs))
                .append('\n')
            sb.append(seg.text).append("\n\n")
        }
        return sb.toString()
    }

    private fun buildVtt(segments: List<SubtitleSegment>): String {
        val sb = StringBuilder("WEBVTT\n\n")
        segments.forEachIndexed { idx, seg ->
            sb.append(idx + 1).append('\n')
            sb.append(formatVttTime(seg.startTimeMs))
                .append(" --> ")
                .append(formatVttTime(seg.endTimeMs))
                .append('\n')
            sb.append(seg.text).append("\n\n")
        }
        return sb.toString()
    }

    private fun buildTxt(segments: List<SubtitleSegment>): String {
        val sb = StringBuilder()
        segments.forEach { seg ->
            sb.append('[')
                .append(formatShortTime(seg.startTimeMs))
                .append("] ")
                .append(seg.text)
                .append('\n')
        }
        return sb.toString()
    }

    private fun formatSrtTime(ms: Long): String {
        val h = ms / 3_600_000L
        val m = (ms % 3_600_000L) / 60_000L
        val s = (ms % 60_000L) / 1_000L
        val milli = ms % 1_000L
        return String.format(Locale.US, "%02d:%02d:%02d,%03d", h, m, s, milli)
    }

    private fun formatVttTime(ms: Long): String {
        val h = ms / 3_600_000L
        val m = (ms % 3_600_000L) / 60_000L
        val s = (ms % 60_000L) / 1_000L
        val milli = ms % 1_000L
        return String.format(Locale.US, "%02d:%02d:%02d.%03d", h, m, s, milli)
    }

    private fun formatShortTime(ms: Long): String {
        val m = ms / 60_000L
        val s = (ms % 60_000L) / 1_000L
        val tenth = (ms % 1_000L) / 100L
        return String.format(Locale.US, "%02d:%02d.%d", m, s, tenth)
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/bridge/OfflineSubtitleBridge.kt
package com.example.offlinesubtitle.bridge

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import androidx.core.content.ContextCompat
import com.example.offlinesubtitle.asr.BackendTag
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.asr.LocalNpuAsrEngine
import com.example.offlinesubtitle.asr.MockNpuAsrEngine
import com.example.offlinesubtitle.asr.WavFileTranscriber
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.export.SubtitleExportFormat
import com.example.offlinesubtitle.export.SubtitleExporter
import com.example.offlinesubtitle.service.SubtitleForegroundService
import com.example.offlinesubtitle.subtitle.SubtitleStateManager
import com.example.offlinesubtitle.subtitle.SubtitleUiState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.sample
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

interface BridgeHostCallbacks {
    fun requestMicAndNotificationPermissions()
    fun launchMediaProjectionConsent()
    fun launchOverlayPermissionSettings()
    fun launchAudioFilePicker()
    fun launchModelFolderPicker()
    fun launchShareSheet(shareUri: Uri, mimeType: String, formatLabel: String)
}

data class BridgeControlState(
    val isHostAttached: Boolean = false,
    val isWebViewAttached: Boolean = false,
    val serviceLifecycleState: String = "IDLE",
    val lastCommand: String = "NONE",
    val exportStatusMessage: String? = null,
    val lastSerializedStateJson: String = "{}",
    val commandHistory: List<String> = emptyList()
)

class OfflineSubtitleBridge(
    private val appContext: Context,
    val stateManager: SubtitleStateManager,
    private val mockAsrEngine: MockNpuAsrEngine,
    private val localNpuAsrEngine: LocalNpuAsrEngine
) {
    companion object {
        private const val TAG_STATE = "[ASR_STATE]"
        private const val TAG_SERVICE = "[ASR_SERVICE]"
        const val JS_INTERFACE_NAME = "AndroidOfflineSubtitleBridge"
    }

    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val wavFileTranscriber = WavFileTranscriber(appContext)
    private val subtitleExporter = SubtitleExporter(appContext)

    private var hostCallbacks: BridgeHostCallbacks? = null
    private var attachedWebView: WebView? = null
    private var statePushJob: Job? = null

    private val _bridgeState = MutableStateFlow(
        BridgeControlState(lastSerializedStateJson = serializeUiState(stateManager.uiState.value))
    )
    val bridgeState: StateFlow<BridgeControlState> = _bridgeState.asStateFlow()

    val uiState: StateFlow<SubtitleUiState>
        get() = stateManager.uiState

    init {
        startStateObserver()
    }

    fun attachHost(callbacks: BridgeHostCallbacks) {
        hostCallbacks = callbacks
        _bridgeState.update { it.copy(isHostAttached = true) }
        recordCommand("HOST_ATTACHED")
    }

    fun detachHost() {
        hostCallbacks = null
        _bridgeState.update { it.copy(isHostAttached = false) }
    }

    fun attachWebView(webView: WebView) {
        attachedWebView = webView
        _bridgeState.update { it.copy(isWebViewAttached = true) }
        pushStateToWebView(stateManager.uiState.value)
        recordCommand("WEBVIEW_ATTACHED")
    }

    fun detachWebView(webView: WebView) {
        if (attachedWebView === webView) {
            attachedWebView = null
            _bridgeState.update { it.copy(isWebViewAttached = false) }
        }
    }

    fun notifyServiceLifecycle(lifecycleEvent: String) {
        _bridgeState.update { it.copy(serviceLifecycleState = lifecycleEvent) }
        Log.d(TAG_SERVICE, "Bridge observed service lifecycle -> $lifecycleEvent")
    }

    // --- 模型路徑設定 State Handlers（同步於 MainScreen 與 WebView Bridge UI）---

    fun handlePickModelFolderClick() {
        recordCommand("PICK_MODEL_FOLDER_SAF")
        hostCallbacks?.launchModelFolderPicker()
    }

    fun handleModelFolderPicked(treeUri: Uri) {
        val uriString = treeUri.toString()
        recordCommand("SAF_FOLDER_SELECTED:$uriString")
        stateManager.applyCustomModelPath(uriString)
    }

    fun handleApplyModelPath(rawPath: String) {
        recordCommand("APPLY_MODEL_PATH:${rawPath.trim()}")
        stateManager.applyCustomModelPath(rawPath)
    }

    fun handleResetModelPath() {
        recordCommand("RESET_MODEL_PATH_DEFAULT")
        stateManager.resetModelPathToDefault()
    }

    fun handleRefreshExternalModels() {
        recordCommand("REFRESH_EXTERNAL_MODELS")
        stateManager.refreshModelDiskUsage(validateAndAlert = false)
    }

    // --- 音訊服務與 ASR 控制 State Handlers ---

    fun handleStartOrStopToggle(hasMicPermission: Boolean) {
        if (stateManager.uiState.value.isRunning) {
            handleStopService()
        } else {
            val source = stateManager.uiState.value.inputSource
            if (source == AudioInputSource.MICROPHONE && !hasMicPermission) {
                hostCallbacks?.requestMicAndNotificationPermissions()
                recordCommand("REQUEST_MIC_PERMISSION")
                return
            }
            handleStartService(source)
        }
    }

    fun handleStartService(source: AudioInputSource) {
        recordCommand("START_SERVICE:${source.name}")
        stateManager.setInputSource(source)
        when (source) {
            AudioInputSource.SYSTEM_AUDIO -> {
                hostCallbacks?.launchMediaProjectionConsent()
            }
            AudioInputSource.SIMULATED_PCM -> {
                sendServiceAction(SubtitleForegroundService.ACTION_START_SIMULATED)
            }
            AudioInputSource.MICROPHONE -> {
                sendServiceAction(SubtitleForegroundService.ACTION_START_MIC)
            }
        }
    }

    fun handleMediaProjectionGranted(resultCode: Int, resultData: Intent) {
        recordCommand("MEDIA_PROJECTION_GRANTED")
        val svcIntent = Intent(appContext, SubtitleForegroundService::class.java).apply {
            action = SubtitleForegroundService.ACTION_START_SYSTEM_AUDIO
            putExtra(SubtitleForegroundService.EXTRA_RESULT_CODE, resultCode)
            putExtra(SubtitleForegroundService.EXTRA_RESULT_DATA, resultData)
        }
        ContextCompat.startForegroundService(appContext, svcIntent)
    }

    fun handleStopService() {
        recordCommand("STOP_SERVICE")
        sendServiceAction(SubtitleForegroundService.ACTION_STOP)
    }

    fun handleToggleOverlay() {
        val currentlyActive = stateManager.uiState.value.isOverlayActive
        if (currentlyActive) {
            recordCommand("HIDE_OVERLAY")
            sendServiceAction(SubtitleForegroundService.ACTION_HIDE_OVERLAY)
            return
        }
        if (Settings.canDrawOverlays(appContext)) {
            recordCommand("SHOW_OVERLAY")
            sendServiceAction(SubtitleForegroundService.ACTION_SHOW_OVERLAY)
        } else {
            recordCommand("REQUEST_OVERLAY_PERMISSION")
            hostCallbacks?.launchOverlayPermissionSettings()
        }
    }

    fun handleSwitchToMockModel() {
        recordCommand("SWITCH_MODEL:MOCK")
        stateManager.switchToEngine(engine = mockAsrEngine, label = "Mock NPU")
    }

    fun handleSwitchToLocalModel(profile: LocalModelProfile) {
        recordCommand("SWITCH_MODEL:${profile.dirName}")
        stateManager.switchToEngine(
            engine = localNpuAsrEngine,
            label = profile.displayName,
            localProfile = profile
        )
    }

    fun handleUnloadModel() {
        recordCommand("UNLOAD_MODEL")
        stateManager.unloadCurrentModel()
    }

    fun handleSelectInputSource(source: AudioInputSource) {
        recordCommand("SET_INPUT_SOURCE:${source.name}")
        stateManager.setInputSource(source)
    }

    fun handleSelectBackend(backendTag: BackendTag) {
        recordCommand("SET_BACKEND:${backendTag.label}")
        stateManager.setBackendMode(backendTag)
    }

    fun handleImportAudioClick() {
        recordCommand("OPEN_AUDIO_PICKER")
        hostCallbacks?.launchAudioFilePicker()
    }

    fun handleAudioUriPicked(uri: Uri) {
        recordCommand("TRANSCRIBE_FILE:${uri.lastPathSegment ?: "audio"}")
        mainScope.launch {
            val engine = stateManager.getCurrentEngine()
            stateManager.onFileTranscribeStarted(uri.lastPathSegment ?: "audio")

            val result = wavFileTranscriber.transcribeUri(
                uri = uri,
                asrEngine = engine,
                onProgress = { progress -> stateManager.onFileTranscribeProgress(progress) }
            )

            result.onSuccess { report ->
                stateManager.onFileTranscribeCompleted(report)
            }.onFailure { err ->
                stateManager.onFileTranscribeFailed(err.message ?: "未知錯誤")
            }
        }
    }

    fun handleEditSegment(segmentId: Long, newText: String) {
        recordCommand("EDIT_SEGMENT:$segmentId")
        stateManager.editSegmentText(segmentId, newText)
    }

    fun handleClearSubtitles() {
        recordCommand("CLEAR_SUBTITLES")
        stateManager.clearSubtitles()
        _bridgeState.update { it.copy(exportStatusMessage = null) }
    }

    fun handleInjectBuiltInTestMode() {
        recordCommand("INJECT_TEST_SEGMENTS")
        stateManager.injectBuiltInTestSegments()
        _bridgeState.update {
            it.copy(exportStatusMessage = "已注入含重疊時間軸之測試資料，可立即測試匯出校驗")
        }
    }

    fun handleExportSubtitles(format: SubtitleExportFormat, shareAfter: Boolean) {
        recordCommand("EXPORT:${format.label}:share=$shareAfter")
        mainScope.launch {
            val segments = stateManager.uiState.value.segments
            val result = subtitleExporter.export(
                segments = segments,
                format = format,
                saveToDownloads = !shareAfter
            )

            result.onSuccess { res ->
                val fixHint = if (res.overlapsFixed > 0) "（已自動修正 ${res.overlapsFixed} 處重疊）" else ""
                if (shareAfter) {
                    _bridgeState.update {
                        it.copy(exportStatusMessage = "已產生 ${res.fileName}$fixHint，開啟分享面板...")
                    }
                    hostCallbacks?.launchShareSheet(res.shareUri, format.mimeType, format.label)
                } else {
                    _bridgeState.update {
                        it.copy(exportStatusMessage = "已儲存至 Downloads/${res.fileName}$fixHint")
                    }
                }
            }.onFailure { err ->
                _bridgeState.update { it.copy(exportStatusMessage = "匯出失敗: ${err.message}") }
            }
        }
    }

    // --- WebView @JavascriptInterface 橋接端點 ---

    @JavascriptInterface
    fun getStateJson(): String = serializeUiState(stateManager.uiState.value)

    @JavascriptInterface
    fun pickModelFolder() {
        mainScope.launch { handlePickModelFolderClick() }
    }

    @JavascriptInterface
    fun applyModelPath(path: String) {
        mainScope.launch { handleApplyModelPath(path) }
    }

    @JavascriptInterface
    fun resetModelPath() {
        mainScope.launch { handleResetModelPath() }
    }

    @JavascriptInterface
    fun startService(sourceName: String) {
        mainScope.launch {
            val source = runCatching { AudioInputSource.valueOf(sourceName) }
                .getOrDefault(AudioInputSource.MICROPHONE)
            handleStartService(source)
        }
    }

    @JavascriptInterface
    fun stopService() {
        mainScope.launch { handleStopService() }
    }

    @JavascriptInterface
    fun toggleOverlay() {
        mainScope.launch { handleToggleOverlay() }
    }

    @JavascriptInterface
    fun switchModel(mode: String) {
        mainScope.launch {
            when (mode) {
                "WHISPER_TINY" -> handleSwitchToLocalModel(LocalModelProfile.WHISPER_TINY_QNN)
                "WHISPER_SMALL" -> handleSwitchToLocalModel(LocalModelProfile.WHISPER_SMALL_QNN)
                else -> handleSwitchToMockModel()
            }
        }
    }

    @JavascriptInterface
    fun unloadModel() {
        mainScope.launch { handleUnloadModel() }
    }

    @JavascriptInterface
    fun setBackendMode(backendName: String) {
        mainScope.launch {
            val tag = runCatching { BackendTag.valueOf(backendName) }
                .getOrDefault(BackendTag.QNN_NPU)
            handleSelectBackend(tag)
        }
    }

    @JavascriptInterface
    fun setInputSource(sourceName: String) {
        mainScope.launch {
            val source = runCatching { AudioInputSource.valueOf(sourceName) }
                .getOrDefault(AudioInputSource.MICROPHONE)
            handleSelectInputSource(source)
        }
    }

    @JavascriptInterface
    fun importAudioFile() {
        mainScope.launch { handleImportAudioClick() }
    }

    @JavascriptInterface
    fun clearSubtitles() {
        mainScope.launch { handleClearSubtitles() }
    }

    @JavascriptInterface
    fun injectTestSegments() {
        mainScope.launch { handleInjectBuiltInTestMode() }
    }

    @JavascriptInterface
    fun exportSubtitles(formatName: String, shareAfter: Boolean) {
        mainScope.launch {
            val fmt = runCatching { SubtitleExportFormat.valueOf(formatName) }
                .getOrDefault(SubtitleExportFormat.SRT)
            handleExportSubtitles(fmt, shareAfter)
        }
    }

    private fun startStateObserver() {
        statePushJob?.cancel()
        statePushJob = mainScope.launch {
            @Suppress("OPT_IN_USAGE")
            stateManager.uiState
                .sample(100L)
                .collect { state ->
                    val json = serializeUiState(state)
                    _bridgeState.update { it.copy(lastSerializedStateJson = json) }
                    pushStateToWebView(state, json)
                }
        }
    }

    private fun pushStateToWebView(state: SubtitleUiState, precomputedJson: String? = null) {
        val webView = attachedWebView ?: return
        val json = precomputedJson ?: serializeUiState(state)
        val quoted = JSONObject.quote(json)
        webView.post {
            webView.evaluateJavascript(
                "window.__onNativeSubtitleState && window.__onNativeSubtitleState($quoted);",
                null
            )
        }
    }

    private fun sendServiceAction(action: String) {
        val intent = Intent(appContext, SubtitleForegroundService::class.java).apply {
            this.action = action
        }
        if (stateManager.uiState.value.isRunning || action == SubtitleForegroundService.ACTION_STOP) {
            appContext.startService(intent)
        } else {
            ContextCompat.startForegroundService(appContext, intent)
        }
    }

    private fun recordCommand(cmd: String) {
        Log.d(TAG_STATE, "Bridge command -> $cmd")
        _bridgeState.update { state ->
            val updated = (listOf(cmd) + state.commandHistory).take(12)
            state.copy(lastCommand = cmd, commandHistory = updated)
        }
    }

    private fun serializeUiState(state: SubtitleUiState): String {
        val segArray = JSONArray()
        state.segments.forEach { seg ->
            segArray.put(
                JSONObject().apply {
                    put("id", seg.id)
                    put("text", seg.text)
                    put("isFinal", seg.isFinal)
                    put("startTimeMs", seg.startTimeMs)
                    put("endTimeMs", seg.endTimeMs)
                    put("backendTag", seg.backendTag.label)
                    put("latencyMs", seg.latencyMs)
                }
            )
        }

        return JSONObject().apply {
            put("isRunning", state.isRunning)
            put("isFileTranscribing", state.isFileTranscribing)
            put("fileTranscribeProgress", state.fileTranscribeProgress.toDouble())
            put("inputSource", state.inputSource.name)
            put("backendTag", state.backendTag.label)
            put("activeEngineLabel", state.activeEngineLabel)
            put("currentModelPath", state.currentModelPath)
            put("isCustomModelPath", state.isCustomModelPath)
            put("modelPathError", state.modelPathError ?: "")
            put("modelPathAlertEventId", state.modelPathAlertEventId)
            put("isModelLoaded", state.isModelLoaded)
            put("modelsDiskSizeMb", state.modelsDiskSizeMb)
            put("isSpeechActive", state.isSpeechActive)
            put("lastLatencyMs", state.lastLatencyMs)
            put("lastRtf", state.lastRtf.toDouble())
            put("activeWindowSec", state.activeWindowSec.toDouble())
            put("timelineDriftMs", state.timelineDriftMs)
            put("pssMemoryMb", state.pssMemoryMb.toDouble())
            put("isOverlayActive", state.isOverlayActive)
            put("systemAudioSilentWarning", state.systemAudioSilentWarning)
            put("statusMessage", state.statusMessage)
            put("segments", segArray)
        }.toString()
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/bridge/OfflineSubtitleViewModel.kt
package com.example.offlinesubtitle.bridge

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import com.example.offlinesubtitle.asr.BackendTag
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.export.SubtitleExportFormat
import com.example.offlinesubtitle.service.SubtitleRuntimeCoordinator
import com.example.offlinesubtitle.subtitle.SubtitleUiState
import kotlinx.coroutines.flow.StateFlow

class OfflineSubtitleViewModel(application: Application) : AndroidViewModel(application) {

    val bridge: OfflineSubtitleBridge =
        SubtitleRuntimeCoordinator.getOrCreateBridge(application.applicationContext)

    val uiState: StateFlow<SubtitleUiState> = bridge.uiState
    val bridgeState: StateFlow<BridgeControlState> = bridge.bridgeState

    fun attachHost(callbacks: BridgeHostCallbacks) = bridge.attachHost(callbacks)
    fun detachHost() = bridge.detachHost()

    fun onPickModelFolderClick() = bridge.handlePickModelFolderClick()
    fun onModelFolderPicked(treeUri: Uri) = bridge.handleModelFolderPicked(treeUri)
    fun onApplyModelPath(path: String) = bridge.handleApplyModelPath(path)
    fun onResetModelPath() = bridge.handleResetModelPath()

    fun onStartStopClick(hasMicPermission: Boolean) = bridge.handleStartOrStopToggle(hasMicPermission)
    fun onMediaProjectionGranted(resultCode: Int, data: Intent) =
        bridge.handleMediaProjectionGranted(resultCode, data)

    fun onToggleOverlay() = bridge.handleToggleOverlay()
    fun onImportAudioClick() = bridge.handleImportAudioClick()
    fun onAudioUriPicked(uri: Uri) = bridge.handleAudioUriPicked(uri)
    fun onSwitchToMockModel() = bridge.handleSwitchToMockModel()
    fun onSwitchToLocalModel(profile: LocalModelProfile) = bridge.handleSwitchToLocalModel(profile)
    fun onUnloadModel() = bridge.handleUnloadModel()
    fun onSelectInputSource(source: AudioInputSource) = bridge.handleSelectInputSource(source)
    fun onSelectBackend(backendTag: BackendTag) = bridge.handleSelectBackend(backendTag)
    fun onEditSegment(segmentId: Long, newText: String) = bridge.handleEditSegment(segmentId, newText)
    fun onClearSubtitles() = bridge.handleClearSubtitles()
    fun onLoadBuiltInTestMode() = bridge.handleInjectBuiltInTestMode()
    fun onExport(format: SubtitleExportFormat, shareAfter: Boolean) =
        bridge.handleExportSubtitles(format, shareAfter)
    fun onRefreshModels() = bridge.handleRefreshExternalModels()
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/ui/FloatingSubtitleOverlay.kt
package com.example.offlinesubtitle.ui

import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DragIndicator
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.subtitle.SubtitleStateManager
import kotlin.math.roundToInt

class FloatingSubtitleOverlay(
    private val context: Context,
    private val stateManager: SubtitleStateManager,
    private val onSwitchSourceRequest: (AudioInputSource) -> Unit,
    private val onCloseOverlay: () -> Unit
) {
    private val windowManager = context.getSystemService(WindowManager::class.java)
    private var composeView: ComposeView? = null
    private var overlayLifecycleOwner: OverlayLifecycleOwner? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    val isShowing: Boolean
        get() = composeView != null

    fun show() {
        if (composeView != null) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = 180
        }
        layoutParams = params

        val lifecycleOwner = OverlayLifecycleOwner().apply {
            performRestore()
            handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
            handleLifecycleEvent(Lifecycle.Event.ON_START)
            handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        }
        overlayLifecycleOwner = lifecycleOwner

        val view = ComposeView(context).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
            setViewTreeLifecycleOwner(lifecycleOwner)
            setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            setContent {
                MaterialTheme {
                    val uiState by stateManager.uiState.collectAsStateWithLifecycle()
                    FloatingOverlayCard(
                        latestText = uiState.segments.lastOrNull()?.text ?: "正在等待語音輸入...",
                        previousText = uiState.segments.dropLast(1).lastOrNull()?.text,
                        isDraft = uiState.segments.lastOrNull()?.isFinal == false,
                        inputSource = uiState.inputSource,
                        latencyMs = uiState.lastLatencyMs,
                        onDrag = { dx, dy ->
                            params.x += dx
                            params.y += dy
                            runCatching { windowManager.updateViewLayout(this, params) }
                        },
                        onToggleSource = {
                            val next = if (uiState.inputSource == AudioInputSource.MICROPHONE) {
                                AudioInputSource.SYSTEM_AUDIO
                            } else {
                                AudioInputSource.MICROPHONE
                            }
                            onSwitchSourceRequest(next)
                        },
                        onClose = onCloseOverlay
                    )
                }
            }
        }
        composeView = view
        windowManager.addView(view, params)
    }

    fun hide() {
        val view = composeView ?: return
        runCatching { windowManager.removeView(view) }
        composeView = null
        overlayLifecycleOwner?.apply {
            handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
            handleLifecycleEvent(Lifecycle.Event.ON_STOP)
            handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        }
        overlayLifecycleOwner = null
        layoutParams = null
    }

    private class OverlayLifecycleOwner : LifecycleOwner, SavedStateRegistryOwner {
        private val lifecycleRegistry = LifecycleRegistry(this)
        private val savedStateController = SavedStateRegistryController.create(this)

        override val lifecycle: Lifecycle
            get() = lifecycleRegistry

        override val savedStateRegistry: SavedStateRegistry
            get() = savedStateController.savedStateRegistry

        fun performRestore() {
            savedStateController.performRestore(null)
        }

        fun handleLifecycleEvent(event: Lifecycle.Event) {
            lifecycleRegistry.handleLifecycleEvent(event)
        }
    }
}

@Composable
private fun FloatingOverlayCard(
    latestText: String,
    previousText: String?,
    isDraft: Boolean,
    inputSource: AudioInputSource,
    latencyMs: Long,
    onDrag: (dx: Int, dy: Int) -> Unit,
    onToggleSource: () -> Unit,
    onClose: () -> Unit
) {
    var isCollapsed by remember { mutableStateOf(false) }

    Surface(
        color = Color(0xCC121417),
        shape = RoundedCornerShape(16.dp),
        shadowElevation = 8.dp,
        modifier = Modifier
            .widthIn(min = 260.dp, max = 350.dp)
            .clip(RoundedCornerShape(16.dp))
            .pointerInput(Unit) {
                detectDragGestures { change, dragAmount ->
                    change.consume()
                    onDrag(dragAmount.x.roundToInt(), dragAmount.y.roundToInt())
                }
            }
    ) {
        Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.DragIndicator,
                        contentDescription = "拖曳懸浮窗",
                        tint = Color(0xFFB0BEC5),
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = "${inputSource.label} • ${latencyMs}ms",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF81D4FA),
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = 4.dp)
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onToggleSource, modifier = Modifier.size(26.dp)) {
                        Icon(
                            imageVector = Icons.Default.SwapHoriz,
                            contentDescription = "切換音源",
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    IconButton(
                        onClick = { isCollapsed = !isCollapsed },
                        modifier = Modifier.size(26.dp)
                    ) {
                        Icon(
                            imageVector = if (isCollapsed) Icons.Default.ExpandMore else Icons.Default.ExpandLess,
                            contentDescription = if (isCollapsed) "展開" else "收合",
                            tint = Color.White,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                    IconButton(onClick = onClose, modifier = Modifier.size(26.dp)) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "關閉懸浮窗",
                            tint = Color(0xFFEF9A9A),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }

            if (!isCollapsed) {
                Spacer(modifier = Modifier.height(4.dp))
                if (!previousText.isNullOrBlank()) {
                    Text(
                        text = previousText,
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFBDBDBD),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                }
                Text(
                    text = latestText,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    fontStyle = if (isDraft) FontStyle.Italic else FontStyle.Normal,
                    color = if (isDraft) Color(0xFFFFF59D) else Color.White,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0x33FFFFFF), RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 6.dp)
                )
            }
        }
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/ui/TranscriptEditorScreen.kt
package com.example.offlinesubtitle.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.offlinesubtitle.asr.SubtitleSegment
import com.example.offlinesubtitle.export.SubtitleExportFormat
import java.util.Locale

@Composable
fun TranscriptEditorScreen(
    segments: List<SubtitleSegment>,
    exportStatusMessage: String?,
    onEditSegment: (segmentId: Long, newText: String) -> Unit,
    onExportAndSave: (SubtitleExportFormat) -> Unit,
    onExportAndShare: (SubtitleExportFormat) -> Unit,
    onLoadBuiltInTestMode: () -> Unit
) {
    var searchQuery by remember { mutableStateOf("") }
    var editingSegment by remember { mutableStateOf<SubtitleSegment?>(null) }
    var editBufferText by remember { mutableStateOf("") }
    var selectedFormat by remember { mutableStateOf(SubtitleExportFormat.SRT) }

    val filteredSegments = remember(segments, searchQuery) {
        if (searchQuery.isBlank()) {
            segments
        } else {
            segments.filter { it.text.contains(searchQuery, ignoreCase = true) }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text("搜尋字幕關鍵字...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { searchQuery = "" }) {
                            Icon(Icons.Default.Clear, contentDescription = "清除搜尋")
                        }
                    }
                },
                singleLine = true,
                modifier = Modifier.weight(1f)
            )

            OutlinedButton(
                onClick = onLoadBuiltInTestMode,
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 14.dp)
            ) {
                Icon(Icons.Default.BugReport, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("測試資料", style = MaterialTheme.typography.labelMedium)
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "格式：",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    SubtitleExportFormat.entries.forEach { fmt ->
                        val selected = selectedFormat == fmt
                        if (selected) {
                            Button(
                                onClick = { selectedFormat = fmt },
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
                                modifier = Modifier.height(34.dp)
                            ) {
                                Text(fmt.label, style = MaterialTheme.typography.labelMedium)
                            }
                        } else {
                            OutlinedButton(
                                onClick = { selectedFormat = fmt },
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
                                modifier = Modifier.height(34.dp)
                            ) {
                                Text(fmt.label, style = MaterialTheme.typography.labelMedium)
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedButton(
                        onClick = { onExportAndSave(selectedFormat) },
                        enabled = segments.isNotEmpty(),
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("存至 Downloads")
                    }

                    Button(
                        onClick = { onExportAndShare(selectedFormat) },
                        enabled = segments.isNotEmpty(),
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("匯出並分享")
                    }
                }

                if (!exportStatusMessage.isNullOrBlank()) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = exportStatusMessage,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        if (filteredSegments.isEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = if (segments.isEmpty()) "尚無轉錄字幕，請先錄音、匯入音檔或點擊「測試資料」" else "查無符合「$searchQuery」的字幕",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(
                    items = filteredSegments,
                    key = { it.id }
                ) { seg ->
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                editingSegment = seg
                                editBufferText = seg.text
                            }
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "#${seg.id}  ${formatEditorMs(seg.startTimeMs)} → ${formatEditorMs(seg.endTimeMs)}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Icon(
                                    imageVector = Icons.Default.Edit,
                                    contentDescription = "編輯",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = highlightKeyword(seg.text, searchQuery),
                                style = MaterialTheme.typography.bodyLarge
                            )
                        }
                    }
                }
            }
        }
    }

    editingSegment?.let { target ->
        AlertDialog(
            onDismissRequest = { editingSegment = null },
            title = { Text("編輯第 #${target.id} 句字幕") },
            text = {
                OutlinedTextField(
                    value = editBufferText,
                    onValueChange = { editBufferText = it },
                    minLines = 3,
                    maxLines = 6,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        onEditSegment(target.id, editBufferText)
                        editingSegment = null
                    }
                ) {
                    Text("儲存修改")
                }
            },
            dismissButton = {
                TextButton(onClick = { editingSegment = null }) {
                    Text("取消")
                }
            }
        )
    }
}

private fun highlightKeyword(text: String, query: String): AnnotatedString {
    if (query.isBlank()) return AnnotatedString(text)
    return buildAnnotatedString {
        append(text)
        var startIndex = 0
        while (startIndex < text.length) {
            val found = text.indexOf(query, startIndex = startIndex, ignoreCase = true)
            if (found < 0) break
            addStyle(
                style = SpanStyle(
                    background = Color(0xFFFFEB3B),
                    color = Color.Black,
                    fontWeight = FontWeight.Bold
                ),
                start = found,
                end = found + query.length
            )
            startIndex = found + query.length
        }
    }
}

private fun formatEditorMs(ms: Long): String {
    val totalSec = ms / 1000L
    val min = totalSec / 60L
    val sec = totalSec % 60L
    val tenth = (ms % 1000L) / 100L
    return String.format(Locale.US, "%02d:%02d.%d", min, sec, tenth)
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/ui/OfflineSubtitleBridgeScreen.kt
package com.example.offlinesubtitle.ui

import android.annotation.SuppressLint
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.bridge.BridgeControlState
import com.example.offlinesubtitle.bridge.OfflineSubtitleBridge
import com.example.offlinesubtitle.subtitle.SubtitleUiState

@Composable
fun OfflineSubtitleBridgeScreen(
    bridge: OfflineSubtitleBridge,
    uiState: SubtitleUiState,
    bridgeState: BridgeControlState,
    hasMicPermission: Boolean
) {
    var showEmbeddedWebUi by remember { mutableStateOf(true) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            FilterChip(
                selected = showEmbeddedWebUi,
                onClick = { showEmbeddedWebUi = true },
                label = { Text("離線 WebView Bridge UI") }
            )
            FilterChip(
                selected = !showEmbeddedWebUi,
                onClick = { showEmbeddedWebUi = false },
                label = { Text("State Handlers 檢視") }
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        if (showEmbeddedWebUi) {
            EmbeddedBridgeWebView(
                bridge = bridge,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
            )
        } else {
            BridgeStateHandlersInspector(
                bridge = bridge,
                uiState = uiState,
                bridgeState = bridgeState,
                hasMicPermission = hasMicPermission,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun BridgeStateHandlersInspector(
    bridge: OfflineSubtitleBridge,
    uiState: SubtitleUiState,
    bridgeState: BridgeControlState,
    hasMicPermission: Boolean,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(bottom = 12.dp)
    ) {
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = "OfflineSubtitleBridge 連動狀態",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "MainActivity Host: ${if (bridgeState.isHostAttached) "已綁定" else "未綁定"}",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        text = "ForegroundService 狀態: ${bridgeState.serviceLifecycleState}",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        text = "目前模型路徑 (${if (uiState.isCustomModelPath) "自訂" else "預設"}): ${uiState.currentModelPath}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = "最近指令: ${bridgeState.lastCommand}",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }

        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = "Bridge State Handlers 快速驗證",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = {
                                if (uiState.isRunning) {
                                    bridge.handleStopService()
                                } else {
                                    bridge.handleStartService(AudioInputSource.SIMULATED_PCM)
                                }
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (uiState.isRunning) "停止服務" else "模擬音訊啟動")
                        }
                        OutlinedButton(
                            onClick = { bridge.handleStartOrStopToggle(hasMicPermission) },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Mic 切換")
                        }
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { bridge.handleSwitchToLocalModel(LocalModelProfile.WHISPER_TINY_QNN) },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("載入 Whisper Tiny")
                        }
                        OutlinedButton(
                            onClick = { bridge.handleToggleOverlay() },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (uiState.isOverlayActive) "關閉懸浮窗" else "開啟懸浮窗")
                        }
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { bridge.handlePickModelFolderClick() },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("SAF 選取模型目錄")
                        }
                        OutlinedButton(
                            onClick = { bridge.handleResetModelPath() },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("重設預設路徑")
                        }
                    }
                }
            }
        }

        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLowest),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = "即時橋接 JSON 狀態快照",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = bridgeState.lastSerializedStateJson,
                        style = MaterialTheme.typography.bodySmall,
                        fontFamily = FontFamily.Monospace,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(8.dp))
                            .padding(8.dp)
                    )
                }
            }
        }

        if (bridgeState.commandHistory.isNotEmpty()) {
            item {
                Text(
                    text = "近期 State Handler 指令軌跡",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold
                )
            }
            items(bridgeState.commandHistory) { cmd ->
                Text(
                    text = "• $cmd",
                    style = MaterialTheme.typography.bodySmall,
                    fontFamily = FontFamily.Monospace
                )
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun EmbeddedBridgeWebView(
    bridge: OfflineSubtitleBridge,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val webView = remember {
        WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            webViewClient = WebViewClient()
            addJavascriptInterface(bridge, OfflineSubtitleBridge.JS_INTERFACE_NAME)
            loadUrl("file:///android_asset/bridge/index.html")
        }
    }

    DisposableEffect(webView) {
        bridge.attachWebView(webView)
        onDispose {
            bridge.detachWebView(webView)
            webView.removeJavascriptInterface(OfflineSubtitleBridge.JS_INTERFACE_NAME)
            webView.destroy()
        }
    }

    AndroidView(
        factory = { webView },
        modifier = modifier
    )
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/ui/MainScreen.kt
package com.example.offlinesubtitle.ui

import android.widget.Toast
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AudioFile
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Eject
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PictureInPictureAlt
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.offlinesubtitle.asr.BackendTag
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.asr.SubtitleSegment
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.bridge.BridgeControlState
import com.example.offlinesubtitle.bridge.OfflineSubtitleBridge
import com.example.offlinesubtitle.export.SubtitleExportFormat
import com.example.offlinesubtitle.subtitle.SubtitleUiState
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(
    bridge: OfflineSubtitleBridge,
    uiState: SubtitleUiState,
    bridgeState: BridgeControlState,
    hasMicPermission: Boolean,
    onRequestMicPermission: () -> Unit,
    onStartStopClick: () -> Unit,
    onToggleOverlayClick: () -> Unit,
    onImportAudioClick: () -> Unit,
    onPickModelFolderClick: () -> Unit,
    onApplyModelPath: (String) -> Unit,
    onResetModelPath: () -> Unit,
    onSwitchToMockModel: () -> Unit,
    onSwitchToLocalModel: (LocalModelProfile) -> Unit,
    onUnloadModelClick: () -> Unit,
    onSelectInputSource: (AudioInputSource) -> Unit,
    onSelectBackend: (BackendTag) -> Unit,
    onClearClick: () -> Unit,
    onEditSegment: (Long, String) -> Unit,
    onExportAndSave: (SubtitleExportFormat) -> Unit,
    onExportAndShare: (SubtitleExportFormat) -> Unit,
    onLoadBuiltInTestMode: () -> Unit
) {
    var selectedTab by remember { mutableIntStateOf(0) }
    val snackbarHostState = remember { SnackbarHostState() }
    val context = LocalContext.current

    // 當套用或切換路徑找不到 encoder.onnx 時，立即跳出提示
    LaunchedEffect(uiState.modelPathAlertEventId) {
        if (uiState.modelPathAlertEventId > 0L && !uiState.modelPathError.isNullOrBlank()) {
            Toast.makeText(context, uiState.modelPathError, Toast.LENGTH_SHORT).show()
            snackbarHostState.showSnackbar(uiState.modelPathError)
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "OfflineSubtitle 離線即時字幕",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = uiState.statusMessage,
                            style = MaterialTheme.typography.labelSmall,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onToggleOverlayClick) {
                        Icon(
                            imageVector = Icons.Default.PictureInPictureAlt,
                            contentDescription = "切換懸浮字幕窗",
                            tint = if (uiState.isOverlayActive) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            }
                        )
                    }
                    IconButton(onClick = onClearClick, enabled = uiState.segments.isNotEmpty()) {
                        Icon(
                            imageVector = Icons.Default.DeleteOutline,
                            contentDescription = "清除字幕"
                        )
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("即時字幕") }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("編輯匯出 (${uiState.segments.size})") }
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    text = { Text("Bridge UI") }
                )
            }

            when (selectedTab) {
                0 -> LiveCaptionTabContent(
                    uiState = uiState,
                    hasMicPermission = hasMicPermission,
                    onRequestMicPermission = onRequestMicPermission,
                    onStartStopClick = onStartStopClick,
                    onImportAudioClick = onImportAudioClick,
                    onPickModelFolderClick = onPickModelFolderClick,
                    onApplyModelPath = onApplyModelPath,
                    onResetModelPath = onResetModelPath,
                    onSwitchToMockModel = onSwitchToMockModel,
                    onSwitchToLocalModel = onSwitchToLocalModel,
                    onUnloadModelClick = onUnloadModelClick,
                    onSelectInputSource = onSelectInputSource,
                    onSelectBackend = onSelectBackend
                )
                1 -> TranscriptEditorScreen(
                    segments = uiState.segments,
                    exportStatusMessage = bridgeState.exportStatusMessage,
                    onEditSegment = onEditSegment,
                    onExportAndSave = onExportAndSave,
                    onExportAndShare = onExportAndShare,
                    onLoadBuiltInTestMode = onLoadBuiltInTestMode
                )
                else -> OfflineSubtitleBridgeScreen(
                    bridge = bridge,
                    uiState = uiState,
                    bridgeState = bridgeState,
                    hasMicPermission = hasMicPermission
                )
            }
        }
    }
}

@Composable
private fun LiveCaptionTabContent(
    uiState: SubtitleUiState,
    hasMicPermission: Boolean,
    onRequestMicPermission: () -> Unit,
    onStartStopClick: () -> Unit,
    onImportAudioClick: () -> Unit,
    onPickModelFolderClick: () -> Unit,
    onApplyModelPath: (String) -> Unit,
    onResetModelPath: () -> Unit,
    onSwitchToMockModel: () -> Unit,
    onSwitchToLocalModel: (LocalModelProfile) -> Unit,
    onUnloadModelClick: () -> Unit,
    onSelectInputSource: (AudioInputSource) -> Unit,
    onSelectBackend: (BackendTag) -> Unit
) {
    val listState = rememberLazyListState()

    LaunchedEffect(uiState.segments.size, uiState.segments.lastOrNull()?.text) {
        if (uiState.segments.isNotEmpty()) {
            listState.animateScrollToItem(uiState.segments.lastIndex)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
    ) {
        Spacer(modifier = Modifier.height(8.dp))

        TelemetryStatusBanner(uiState = uiState)

        Spacer(modifier = Modifier.height(8.dp))

        // 模型路徑設定框（顯示與編輯目前路徑 + [選擇資料夾] [套用] [重設為預設]）
        ModelPathConfigCard(
            currentModelPath = uiState.currentModelPath,
            isCustomPath = uiState.isCustomModelPath,
            modelPathError = uiState.modelPathError,
            modelsDiskSizeMb = uiState.modelsDiskSizeMb,
            enabled = !uiState.isRunning && !uiState.isFileTranscribing,
            onPickModelFolderClick = onPickModelFolderClick,
            onApplyModelPath = onApplyModelPath,
            onResetModelPath = onResetModelPath
        )

        if (uiState.systemAudioSilentWarning) {
            Spacer(modifier = Modifier.height(6.dp))
            Surface(
                color = Color(0xFFFFEBEE),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "偵測到系統音訊持續靜音：目標 App 可能受 DRM 保護或禁止音訊內錄",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFFC62828),
                    modifier = Modifier.padding(8.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        ModelAndFileActionRow(
            uiState = uiState,
            onImportAudioClick = onImportAudioClick,
            onSwitchToMockModel = onSwitchToMockModel,
            onSwitchToLocalModel = onSwitchToLocalModel,
            onUnloadModelClick = onUnloadModelClick
        )

        Spacer(modifier = Modifier.height(6.dp))

        ControlOptionsRow(
            uiState = uiState,
            onSelectInputSource = onSelectInputSource,
            onSelectBackend = onSelectBackend
        )

        if (uiState.isFileTranscribing) {
            Spacer(modifier = Modifier.height(6.dp))
            LinearProgressIndicator(
                progress = { uiState.fileTranscribeProgress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp))
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.surfaceContainerLowest)
        ) {
            if (uiState.segments.isEmpty()) {
                EmptySubtitlePlaceholder(
                    modifier = Modifier.align(Alignment.Center),
                    isRunning = uiState.isRunning
                )
            } else {
                LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.fillMaxSize()
                ) {
                    items(
                        items = uiState.segments,
                        key = { it.id }
                    ) { segment ->
                        SubtitleItemCard(segment = segment)
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        BottomActionBar(
            isRunning = uiState.isRunning,
            isBusy = uiState.isFileTranscribing,
            inputSource = uiState.inputSource,
            needsMicPermission = uiState.inputSource == AudioInputSource.MICROPHONE && !hasMicPermission,
            onRequestMicPermission = onRequestMicPermission,
            onStartStopClick = onStartStopClick
        )

        Spacer(modifier = Modifier.height(10.dp))
    }
}

@Composable
private fun ModelPathConfigCard(
    currentModelPath: String,
    isCustomPath: Boolean,
    modelPathError: String?,
    modelsDiskSizeMb: Double,
    enabled: Boolean,
    onPickModelFolderClick: () -> Unit,
    onApplyModelPath: (String) -> Unit,
    onResetModelPath: () -> Unit
) {
    var pathInput by remember { mutableStateOf(currentModelPath) }

    LaunchedEffect(currentModelPath) {
        pathInput = currentModelPath
    }

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "模型路徑設定 (${if (isCustomPath) "自訂" else "預設"})",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = String.format(Locale.US, "磁碟用量: %.1f MB", modelsDiskSizeMb),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            OutlinedTextField(
                value = pathInput,
                onValueChange = { pathInput = it },
                enabled = enabled,
                singleLine = true,
                textStyle = MaterialTheme.typography.bodySmall,
                placeholder = { Text("getExternalFilesDir(null)/models/whisper-tiny") },
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                OutlinedButton(
                    onClick = onPickModelFolderClick,
                    enabled = enabled,
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                    modifier = Modifier.weight(1.1f)
                ) {
                    Icon(Icons.Default.FolderOpen, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("選擇資料夾", style = MaterialTheme.typography.labelSmall, maxLines = 1)
                }

                OutlinedButton(
                    onClick = { onApplyModelPath(pathInput) },
                    enabled = enabled,
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                    modifier = Modifier.weight(0.75f)
                ) {
                    Text("套用", style = MaterialTheme.typography.labelSmall, maxLines = 1)
                }

                OutlinedButton(
                    onClick = onResetModelPath,
                    enabled = enabled,
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Text("重設為預設", style = MaterialTheme.typography.labelSmall, maxLines = 1)
                }
            }

            if (!modelPathError.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = modelPathError,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}

@Composable
private fun TelemetryStatusBanner(uiState: SubtitleUiState) {
    val latencyColor = when {
        uiState.lastLatencyMs == 0L -> MaterialTheme.colorScheme.onSurfaceVariant
        uiState.lastLatencyMs < 800L -> Color(0xFF1B873F)
        else -> Color(0xFFD93025)
    }

    val rtfColor = when {
        uiState.lastRtf <= 0f -> MaterialTheme.colorScheme.onSurfaceVariant
        uiState.lastRtf < 0.30f -> Color(0xFF1B873F)
        else -> Color(0xFFD93025)
    }

    val vadColor by animateColorAsState(
        targetValue = if (uiState.isSpeechActive) Color(0xFF1B873F) else MaterialTheme.colorScheme.outline,
        label = "vadColor"
    )

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = if (uiState.backendTag == BackendTag.QNN_NPU) Color(0xFFE3F2FD) else Color(0xFFFFF3E0),
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = "${uiState.backendTag.label} (${if (uiState.isModelLoaded) "已載入" else "未載入"})",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = if (uiState.backendTag == BackendTag.QNN_NPU) Color(0xFF0D47A1) else Color(0xFFE65100),
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }

                Text(
                    text = "延遲: ${uiState.lastLatencyMs}ms",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = latencyColor
                )

                Text(
                    text = String.format(Locale.US, "RTF: %.3f", uiState.lastRtf),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = rtfColor
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = String.format(
                        Locale.US,
                        "模型: %.1fMB | PSS: %.1fMB | 漂移: %dms",
                        uiState.modelsDiskSizeMb,
                        uiState.pssMemoryMb,
                        uiState.timelineDriftMs
                    ),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(vadColor)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = if (uiState.isSpeechActive) "語音" else "靜音",
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = String.format(Locale.US, "視窗 %.1fs / 30s", uiState.activeWindowSec),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.width(96.dp)
                )
                LinearProgressIndicator(
                    progress = { (uiState.activeWindowSec / 30f).coerceIn(0f, 1f) },
                    modifier = Modifier
                        .weight(1f)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                )
            }
        }
    }
}

@Composable
private fun ModelAndFileActionRow(
    uiState: SubtitleUiState,
    onImportAudioClick: () -> Unit,
    onSwitchToMockModel: () -> Unit,
    onSwitchToLocalModel: (LocalModelProfile) -> Unit,
    onUnloadModelClick: () -> Unit
) {
    var modelMenuExpanded by remember { mutableStateOf(false) }
    val controlsEnabled = !uiState.isRunning && !uiState.isFileTranscribing

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        OutlinedButton(
            onClick = onImportAudioClick,
            enabled = controlsEnabled,
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
            modifier = Modifier.weight(1f)
        ) {
            Icon(Icons.Default.AudioFile, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text("匯入音檔測試", style = MaterialTheme.typography.labelMedium, maxLines = 1)
        }

        Box {
            OutlinedButton(
                onClick = { modelMenuExpanded = true },
                enabled = controlsEnabled,
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)
            ) {
                Icon(Icons.Default.Memory, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("切換模型", style = MaterialTheme.typography.labelMedium)
            }
            DropdownMenu(
                expanded = modelMenuExpanded,
                onDismissRequest = { modelMenuExpanded = false }
            ) {
                DropdownMenuItem(
                    text = { Text("Mock NPU (免模型原型測試)") },
                    onClick = {
                        modelMenuExpanded = false
                        onSwitchToMockModel()
                    }
                )
                LocalModelProfile.entries.forEach { profile ->
                    DropdownMenuItem(
                        text = { Text(profile.displayName) },
                        onClick = {
                            modelMenuExpanded = false
                            onSwitchToLocalModel(profile)
                        }
                    )
                }
            }
        }

        OutlinedButton(
            onClick = onUnloadModelClick,
            enabled = controlsEnabled && uiState.isModelLoaded,
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)
        ) {
            Icon(Icons.Default.Eject, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text("卸載", style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable
private fun ControlOptionsRow(
    uiState: SubtitleUiState,
    onSelectInputSource: (AudioInputSource) -> Unit,
    onSelectBackend: (BackendTag) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AudioInputSource.entries.forEach { source ->
            FilterChip(
                selected = uiState.inputSource == source,
                onClick = { onSelectInputSource(source) },
                enabled = !uiState.isRunning && !uiState.isFileTranscribing,
                label = { Text(source.label, style = MaterialTheme.typography.labelSmall) }
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        FilterChip(
            selected = uiState.backendTag == BackendTag.QNN_NPU,
            onClick = {
                val next = if (uiState.backendTag == BackendTag.QNN_NPU) {
                    BackendTag.CPU_FALLBACK
                } else {
                    BackendTag.QNN_NPU
                }
                onSelectBackend(next)
            },
            label = {
                Text(
                    text = if (uiState.backendTag == BackendTag.QNN_NPU) "NPU" else "CPU",
                    style = MaterialTheme.typography.labelSmall
                )
            }
        )
    }
}

@Composable
private fun SubtitleItemCard(segment: SubtitleSegment) {
    val containerColor = if (segment.isFinal) {
        MaterialTheme.colorScheme.surfaceContainer
    } else {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f)
    }

    Card(
        colors = CardDefaults.cardColors(containerColor = containerColor),
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${formatTimestamp(segment.startTimeMs)} → ${formatTimestamp(segment.endTimeMs)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Text(
                    text = if (segment.isFinal) {
                        "FINAL • ${segment.backendTag.label} • ${segment.latencyMs}ms"
                    } else {
                        "DRAFT • ${segment.latencyMs}ms"
                    },
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = if (segment.isFinal) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (segment.isFinal) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.tertiary
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            Text(
                text = segment.text,
                style = MaterialTheme.typography.bodyLarge,
                fontStyle = if (segment.isFinal) FontStyle.Normal else FontStyle.Italic,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
private fun EmptySubtitlePlaceholder(
    modifier: Modifier = Modifier,
    isRunning: Boolean
) {
    Column(
        modifier = modifier.padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.GraphicEq,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.outline,
            modifier = Modifier.size(48.dp)
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = if (isRunning) {
                "前景服務運作中，偵測到語音後將即時顯示字幕..."
            } else {
                "選擇「麥克風 / 系統音訊 / 模擬音訊」並點擊開始；上方可設定自訂或 SAF 模型路徑"
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun BottomActionBar(
    isRunning: Boolean,
    isBusy: Boolean,
    inputSource: AudioInputSource,
    needsMicPermission: Boolean,
    onRequestMicPermission: () -> Unit,
    onStartStopClick: () -> Unit
) {
    if (needsMicPermission) {
        Button(
            onClick = onRequestMicPermission,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
        ) {
            Icon(imageVector = Icons.Default.Mic, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("授予麥克風權限以啟動前景字幕服務")
        }
    } else {
        Button(
            onClick = onStartStopClick,
            enabled = !isBusy,
            colors = if (isRunning) {
                ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
            } else {
                ButtonDefaults.buttonColors()
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
        ) {
            Icon(
                imageVector = if (isRunning) Icons.Default.Stop else Icons.Default.Mic,
                contentDescription = null
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                if (isRunning) "停止背景服務與字幕" else "啟動${inputSource.label}字幕服務"
            )
        }
    }
}

private fun formatTimestamp(ms: Long): String {
    val totalSec = ms / 1000L
    val min = totalSec / 60L
    val sec = totalSec % 60L
    val tenth = (ms % 1000L) / 100L
    return String.format(Locale.US, "%02d:%02d.%d", min, sec, tenth)
}
EOF

cat << 'EOF' > app/src/main/java/com/example/offlinesubtitle/MainActivity.kt
package com.example.offlinesubtitle

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.offlinesubtitle.bridge.BridgeHostCallbacks
import com.example.offlinesubtitle.bridge.OfflineSubtitleViewModel
import com.example.offlinesubtitle.ui.MainScreen

class MainActivity : ComponentActivity(), BridgeHostCallbacks {

    private lateinit var subtitleViewModel: OfflineSubtitleViewModel
    private var hasMicPermission by mutableStateOf(false)

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        hasMicPermission = results[Manifest.permission.RECORD_AUDIO] == true ||
            checkPermissionGranted(Manifest.permission.RECORD_AUDIO)
    }

    private val mediaProjectionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val data = result.data
        if (result.resultCode == Activity.RESULT_OK && data != null) {
            subtitleViewModel.onMediaProjectionGranted(result.resultCode, data)
        }
    }

    private val overlayPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        if (Settings.canDrawOverlays(this)) {
            subtitleViewModel.onToggleOverlay()
        }
    }

    private val audioFilePickerLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            subtitleViewModel.onAudioUriPicked(uri)
        }
    }

    private val modelFolderPickerLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val treeUri = result.data?.data
        if (result.resultCode == Activity.RESULT_OK && treeUri != null) {
            val takeFlags = (result.data?.flags ?: 0) and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            val resolvedFlags = if (takeFlags != 0) takeFlags else Intent.FLAG_GRANT_READ_URI_PERMISSION
            runCatching {
                contentResolver.takePersistableUriPermission(treeUri, resolvedFlags)
            }.onFailure {
                runCatching {
                    contentResolver.takePersistableUriPermission(
                        treeUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                }
            }
            subtitleViewModel.onModelFolderPicked(treeUri)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        subtitleViewModel = ViewModelProvider(this)[OfflineSubtitleViewModel::class.java]
        subtitleViewModel.attachHost(this)

        refreshPermissions()
        requestMicAndNotificationPermissions()

        setContent {
            val vm: OfflineSubtitleViewModel = viewModel()
            val uiState by vm.uiState.collectAsStateWithLifecycle()
            val bridgeState by vm.bridgeState.collectAsStateWithLifecycle()

            MaterialTheme {
                Surface {
                    MainScreen(
                        bridge = vm.bridge,
                        uiState = uiState,
                        bridgeState = bridgeState,
                        hasMicPermission = hasMicPermission,
                        onRequestMicPermission = { requestMicAndNotificationPermissions() },
                        onStartStopClick = { vm.onStartStopClick(hasMicPermission) },
                        onToggleOverlayClick = { vm.onToggleOverlay() },
                        onImportAudioClick = { vm.onImportAudioClick() },
                        onPickModelFolderClick = { vm.onPickModelFolderClick() },
                        onApplyModelPath = { path -> vm.onApplyModelPath(path) },
                        onResetModelPath = { vm.onResetModelPath() },
                        onSwitchToMockModel = { vm.onSwitchToMockModel() },
                        onSwitchToLocalModel = { profile -> vm.onSwitchToLocalModel(profile) },
                        onUnloadModelClick = { vm.onUnloadModel() },
                        onSelectInputSource = { source -> vm.onSelectInputSource(source) },
                        onSelectBackend = { backend -> vm.onSelectBackend(backend) },
                        onClearClick = { vm.onClearSubtitles() },
                        onEditSegment = { segId, newText -> vm.onEditSegment(segId, newText) },
                        onExportAndSave = { format -> vm.onExport(format, shareAfter = false) },
                        onExportAndShare = { format -> vm.onExport(format, shareAfter = true) },
                        onLoadBuiltInTestMode = { vm.onLoadBuiltInTestMode() }
                    )
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        refreshPermissions()
        subtitleViewModel.onRefreshModels()
    }

    override fun onDestroy() {
        super.onDestroy()
        subtitleViewModel.detachHost()
    }

    override fun requestMicAndNotificationPermissions() {
        val needed = buildList {
            if (!checkPermissionGranted(Manifest.permission.RECORD_AUDIO)) {
                add(Manifest.permission.RECORD_AUDIO)
            }
            if (!checkPermissionGranted(Manifest.permission.POST_NOTIFICATIONS)) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        if (needed.isNotEmpty()) {
            permissionLauncher.launch(needed.toTypedArray())
        }
    }

    override fun launchMediaProjectionConsent() {
        val projectionManager = getSystemService(MediaProjectionManager::class.java)
        mediaProjectionLauncher.launch(projectionManager.createScreenCaptureIntent())
    }

    override fun launchOverlayPermissionSettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        overlayPermissionLauncher.launch(intent)
    }

    override fun launchAudioFilePicker() {
        audioFilePickerLauncher.launch(arrayOf("audio/*", "video/mp4"))
    }

    override fun launchModelFolderPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        modelFolderPickerLauncher.launch(intent)
    }

    override fun launchShareSheet(shareUri: Uri, mimeType: String, formatLabel: String) {
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, shareUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(shareIntent, "分享字幕檔案 ($formatLabel)"))
    }

    private fun refreshPermissions() {
        hasMicPermission = checkPermissionGranted(Manifest.permission.RECORD_AUDIO)
    }

    private fun checkPermissionGranted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }
}
EOF

cat << 'EOF' > .github/workflows/build.yml
name: Android Debug Build

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up JDK 17
