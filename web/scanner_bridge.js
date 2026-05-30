(function () {
  'use strict';

  var _overlay = null;
  var _scanner = null;
  var _detectCb = null;
  var _cancelCb = null;

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

  window.startWebScanner = function (onDetect, onCancel) {
    _detectCb = onDetect;
    _cancelCb = onCancel;

    if (_overlay) removeOverlay();

    // ── Overlay ──────────────────────────────────────
    _overlay = document.createElement('div');
    _overlay.style.cssText = [
      'position:fixed', 'top:0', 'left:0', 'right:0', 'bottom:0',
      'background:rgba(0,0,0,0.88)', 'z-index:99999',
      'display:flex', 'flex-direction:column',
      'align-items:center', 'justify-content:center',
      'font-family:-apple-system,BlinkMacSystemFont,sans-serif',
    ].join(';');

    // Label
    var label = document.createElement('p');
    label.textContent = 'Apunta al código de barras';
    label.style.cssText = 'color:#fff;font-size:17px;margin:0 0 18px;font-weight:500';
    _overlay.appendChild(label);

    // Scanner container (html5-qrcode attaches here)
    var container = document.createElement('div');
    container.id = '_scanner_container_' + Date.now();
    container.style.cssText = [
      'width:320px', 'max-width:90vw',
      'border-radius:16px', 'overflow:hidden',
      'background:#000',
    ].join(';');
    _overlay.appendChild(container);

    // Cancel button
    var btn = document.createElement('button');
    btn.textContent = 'Cancelar';
    btn.style.cssText = [
      'margin-top:24px', 'padding:12px 40px',
      'background:rgba(255,255,255,0.12)',
      'color:#fff', 'border:1px solid rgba(255,255,255,0.3)',
      'border-radius:24px', 'font-size:16px', 'cursor:pointer',
    ].join(';');
    btn.onclick = function () {
      removeOverlay();
      if (_cancelCb) _cancelCb();
    };
    _overlay.appendChild(btn);

    document.body.appendChild(_overlay);

    // ── Start html5-qrcode ───────────────────────────
    try {
      _scanner = new Html5Qrcode(container.id);
      _scanner.start(
        { facingMode: 'environment' },
        {
          fps: 10,
          qrbox: { width: 290, height: 110 },
          aspectRatio: 1.5,
          formatsToSupport: [
            Html5QrcodeSupportedFormats.EAN_13,
            Html5QrcodeSupportedFormats.EAN_8,
            Html5QrcodeSupportedFormats.UPC_A,
            Html5QrcodeSupportedFormats.UPC_E,
            Html5QrcodeSupportedFormats.CODE_128,
            Html5QrcodeSupportedFormats.CODE_39,
            Html5QrcodeSupportedFormats.QR_CODE,
            Html5QrcodeSupportedFormats.ITF,
          ],
        },
        function (text) {
          var cb = _detectCb;
          removeOverlay();
          if (cb) cb(text);
        },
        function () { /* scan miss — ignore */ }
      ).catch(function (err) {
        console.error('[Scanner] start error:', err);
        removeOverlay();
        if (_cancelCb) _cancelCb();
      });
    } catch (e) {
      console.error('[Scanner] init error:', e);
      removeOverlay();
      if (_cancelCb) _cancelCb();
    }
  };

  window.stopWebScanner = function () {
    removeOverlay();
  };
})();
