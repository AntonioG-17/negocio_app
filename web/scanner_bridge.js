(function () {
  'use strict';

  var _overlay = null;
  var _scanner = null;
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

  // Restrict to the 1D barcode formats we actually use (+ QR). Fewer formats
  // means ZXing spends every frame on the right decoders → far more reliable
  // 1D reads on Safari iOS, which has no native BarcodeDetector.
  function supportedFormats() {
    var F = window.Html5QrcodeSupportedFormats;
    if (!F) return undefined;
    return [
      F.EAN_13, F.EAN_8, F.UPC_A, F.UPC_E,
      F.CODE_128, F.CODE_39, F.CODE_93, F.ITF,
      F.CODABAR, F.QR_CODE,
    ];
  }

  function qrboxFn(vw, vh) {
    // Wide, short window suited for 1D barcodes.
    var w = Math.floor(Math.min(vw, 360) * 0.88);
    var h = Math.floor(Math.min(vh, 320) * 0.50);
    return { width: Math.max(w, 200), height: Math.max(h, 110) };
  }

  function removeOverlay() {
    if (_scanner) {
      try { _scanner.stop(); } catch (e) {}
      _scanner = null;
    }
    if (_overlay && _overlay.parentNode) {
      _overlay.parentNode.removeChild(_overlay);
    }
    _overlay = null;
    _detectCb = null;
    _cancelCb = null;
  }

  function removeTriggerBtn() {
    if (_triggerBtn && _triggerBtn.parentNode) {
      _triggerBtn.parentNode.removeChild(_triggerBtn);
    }
    _triggerBtn = null;
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
      width: '360px', maxWidth: '92vw',
      borderRadius: '12px', overflow: 'hidden', background: '#000',
      minHeight: '280px',
    });
    _overlay.appendChild(container);

    var btn = document.createElement('button');
    btn.textContent = 'Cancelar';
    Object.assign(btn.style, {
      marginTop: '20px', padding: '12px 40px',
      background: 'rgba(255,255,255,0.15)', color: '#fff',
      border: '1px solid rgba(255,255,255,0.35)', borderRadius: '24px',
      fontSize: '16px', cursor: 'pointer', touchAction: 'manipulation',
    });
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      removeOverlay();
      if (_cancelCb) _cancelCb();
    });
    _overlay.appendChild(btn);

    document.body.appendChild(_overlay);

    // ── Start html5-qrcode ────────────────────────────────────────────────
    try {
      var cfg = {
        verbose: false,
        experimentalFeatures: { useBarCodeDetectorIfSupported: true },
      };
      var fmts = supportedFormats();
      if (fmts) cfg.formatsToSupport = fmts;

      _scanner = new Html5Qrcode(container.id, cfg);
      _scanner.start(
        // Higher resolution → sharper bars → ZXing reads 1D codes reliably.
        { facingMode: 'environment', width: { ideal: 1920 }, height: { ideal: 1080 } },
        { fps: 15, qrbox: qrboxFn, disableFlip: false },
        function (text) {
          var cb = _detectCb;
          beep();
          removeOverlay();
          if (cb) cb(text);
        },
        function () { /* frame miss — ignore */ }
      ).catch(function (err) {
        console.error('[scanner] start failed:', err);
        container.innerHTML = '<p style="color:#ff5252;padding:16px;text-align:center">No se pudo abrir la cámara.<br>' + err + '</p>';
      });
    } catch (e) {
      console.error('[scanner] init error:', e);
      removeOverlay();
      if (_cancelCb) _cancelCb();
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /**
   * Places a transparent native HTML button exactly over the Flutter scan
   * button so that Safari receives a genuine DOM click (required for
   * getUserMedia on iOS).
   *
   * x, y, w, h — logical pixels (Flutter devicePixelRatio already applied
   * by the caller if needed; here we expect CSS pixels).
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
