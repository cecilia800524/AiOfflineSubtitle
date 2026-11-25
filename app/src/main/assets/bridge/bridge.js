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
