(function () {
  'use strict';

  // Barcode scanning engine: Quagga2 (1D-optimized — EAN/UPC/Code128/39).
  // ZXing (html5-qrcode) failed to decode 1D product barcodes on Safari iOS
  // because it needs a razor-sharp image. Quagga2 does its own patch-based
  // localization + binarization and tolerates blur/angle far better.

  var _overlay = null;
  var _running = false;
  var _detected = false;
  var _detectCb = null;
  var _cancelCb = null;
  var _triggerBtn = null;
  var _audioCtx = null;

  // ── audio / haptics ────────────────────────────────────────────────────────

  // Must be primed from a user gesture (the trigger button click) so iOS lets
  // it play later from the async scan-success callback.
  function ensureAudio() {
    try {
      if (!_audioCtx) {
        var AC = window.AudioContext || window.webkitAudioContext;
        if (AC) _audioCtx = new AC();
      }
      if (_audioCtx && _audioCtx.state === 'suspended') _audioCtx.resume();
    } catch (e) {}
  }

  function beep() {
    try {
      if (_audioCtx) {
        var o = _audioCtx.createOscillator();
        var g = _audioCtx.createGain();
        o.type = 'square';
        o.frequency.value = 880;
        g.gain.value = 0.18;
        o.connect(g);
        g.connect(_audioCtx.destination);
        o.start();
        o.stop(_audioCtx.currentTime + 0.12);
      }
    } catch (e) {}
    try { if (navigator.vibrate) navigator.vibrate(80); } catch (e) {}
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  // Average decode error of the individual bars; lower = higher confidence.
  // Rejects noisy misreads (Quagga can briefly emit garbage on a bad frame).
  function avgError(result) {
    try {
      var codes = (result.codeResult.decodedCodes || [])
        .filter(function (c) { return typeof c.error === 'number'; });
      if (!codes.length) return 1;
      var sum = codes.reduce(function (a, c) { return a + c.error; }, 0);
      return sum / codes.length;
    } catch (e) {
      return 1;
    }
  }

  function stopQuagga() {
    if (_running && window.Quagga) {
      try { window.Quagga.offDetected(_onDetected); } catch (e) {}
      try { window.Quagga.stop(); } catch (e) {}
    }
    _running = false;
  }

  function removeOverlay() {
    stopQuagga();
    if (_overlay && _overlay.parentNode) {
      _overlay.parentNode.removeChild(_overlay);
    }
    _overlay = null;
    _detected = false;
    _detectCb = null;
    _cancelCb = null;
  }

  function removeTriggerBtn() {
    if (_triggerBtn && _triggerBtn.parentNode) {
      _triggerBtn.parentNode.removeChild(_triggerBtn);
    }
    _triggerBtn = null;
  }

  function _onDetected(result) {
    if (_detected) return;
    var code = result && result.codeResult && result.codeResult.code;
    if (!code) return;
    // Require a confident read to avoid false positives.
    if (avgError(result) > 0.20) return;
    _detected = true;
    var cb = _detectCb;
    beep();
    removeOverlay();
    if (cb) cb(code);
  }

  function launchScanner() {
    removeTriggerBtn();
    if (_overlay) removeOverlay();

    // ── Overlay full-screen ───────────────────────────────────────────────
    _overlay = document.createElement('div');
    Object.assign(_overlay.style, {
      position: 'fixed', top: '0', left: '0', right: '0', bottom: '0',
      background: 'rgba(0,0,0,0.90)', zIndex: '2147483647',
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      fontFamily: '-apple-system,BlinkMacSystemFont,sans-serif',
      touchAction: 'manipulation',
    });

    var label = document.createElement('p');
    label.textContent = 'Apunta al código de barras';
    Object.assign(label.style, {
      color: '#fff', fontSize: '17px', margin: '0 0 16px', fontWeight: '600',
    });
    _overlay.appendChild(label);

    var container = document.createElement('div');
    container.id = '_sc_' + Date.now();
    Object.assign(container.style, {
      width: '360px', maxWidth: '92vw', position: 'relative',
      borderRadius: '12px', overflow: 'hidden', background: '#000',
      minHeight: '280px',
    });
    // Force Quagga's injected <video>/<canvas> to fill the container width.
    var styleTag = document.createElement('style');
    styleTag.textContent =
      '#' + container.id + ' video, #' + container.id + ' canvas {' +
      'width:100%!important;height:auto!important;display:block;}';
    container.appendChild(styleTag);
    _overlay.appendChild(container);

    // Red aiming line across the middle (visual guide for 1D codes).
    var aim = document.createElement('div');
    Object.assign(aim.style, {
      position: 'absolute', left: '6%', right: '6%', top: '50%',
      height: '2px', background: 'rgba(255,80,80,0.9)',
      boxShadow: '0 0 8px rgba(255,80,80,0.8)', pointerEvents: 'none',
    });
    container.appendChild(aim);

    var hint = document.createElement('p');
    hint.textContent = 'Mantén el código a ~15 cm y bien iluminado';
    Object.assign(hint.style, {
      color: 'rgba(255,255,255,0.6)', fontSize: '13px', margin: '14px 0 0',
    });
    _overlay.appendChild(hint);

    var btn = document.createElement('button');
    btn.textContent = 'Cancelar';
    Object.assign(btn.style, {
      marginTop: '16px', padding: '12px 40px',
      background: 'rgba(255,255,255,0.15)', color: '#fff',
      border: '1px solid rgba(255,255,255,0.35)', borderRadius: '24px',
      fontSize: '16px', cursor: 'pointer', touchAction: 'manipulation',
    });
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var cb = _cancelCb;
      removeOverlay();
      if (cb) cb();
    });
    _overlay.appendChild(btn);

    document.body.appendChild(_overlay);

    // ── Start Quagga2 ─────────────────────────────────────────────────────
    if (!window.Quagga) {
      container.innerHTML =
        '<p style="color:#ff5252;padding:16px;text-align:center">' +
        'Motor de escaneo no disponible.</p>';
      return;
    }

    _detected = false;
    window.Quagga.init({
      inputStream: {
        name: 'Live',
        type: 'LiveStream',
        target: container,
        constraints: {
          facingMode: 'environment',
          width: { ideal: 1280 },
          height: { ideal: 720 },
          aspectRatio: { ideal: 1.7777778 },
        },
        // Scan only the central horizontal band where the user aligns the code.
        area: { top: '30%', right: '0%', left: '0%', bottom: '30%' },
      },
      locator: { patchSize: 'medium', halfSample: true },
      numOfWorkers: 0, // single-thread → reliable on Safari iOS (no worker blobs)
      frequency: 10,
      decoder: {
        readers: [
          'ean_reader', 'ean_8_reader',
          'upc_reader', 'upc_e_reader',
          'code_128_reader', 'code_39_reader',
        ],
      },
      locate: true,
    }, function (err) {
      if (err) {
        console.error('[scanner] Quagga init failed:', err);
        if (container) {
          container.innerHTML =
            '<p style="color:#ff5252;padding:16px;text-align:center">' +
            'No se pudo abrir la cámara.<br>' + err + '</p>';
        }
        return;
      }
      _running = true;
      window.Quagga.start();
      window.Quagga.onDetected(_onDetected);
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /**
   * Places a transparent native HTML button exactly over the Flutter scan
   * button so that Safari receives a genuine DOM click (required for
   * getUserMedia on iOS). x, y, w, h are CSS pixels.
   */
  window.showScanTrigger = function (x, y, w, h, onDetect, onCancel) {
    _detectCb = onDetect;
    _cancelCb = onCancel;

    removeTriggerBtn();

    _triggerBtn = document.createElement('button');
    Object.assign(_triggerBtn.style, {
      position: 'fixed',
      left: x + 'px', top: y + 'px',
      width: w + 'px', height: h + 'px',
      background: 'transparent',
      border: 'none', outline: 'none',
      zIndex: '2147483646',
      cursor: 'pointer',
      touchAction: 'manipulation',
      // Uncomment to debug position:
      // background: 'rgba(255,0,0,0.3)',
    });

    _triggerBtn.addEventListener('click', function () {
      ensureAudio(); // prime audio within the user gesture so the beep works on iOS
      launchScanner();
    });

    document.body.appendChild(_triggerBtn);
  };

  window.hideScanTrigger = function () {
    removeTriggerBtn();
  };

  // Fallback: called directly (non-iOS or when position not needed)
  window.startWebScanner = function (onDetect, onCancel) {
    _detectCb = onDetect;
    _cancelCb = onCancel;
    ensureAudio();
    launchScanner();
  };

  window.stopWebScanner = function () {
    removeTriggerBtn();
    removeOverlay();
  };
})();
