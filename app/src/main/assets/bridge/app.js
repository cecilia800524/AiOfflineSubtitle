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
