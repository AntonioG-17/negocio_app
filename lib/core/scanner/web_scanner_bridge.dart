import 'dart:js_interop';

extension type _JSWindow._(JSObject _) implements JSObject {
  external void showScanTrigger(
    double x, double y, double w, double h,
    JSFunction onDetect,
    JSFunction onCancel,
  );
  external void hideScanTrigger();
  external void startWebScanner(JSFunction onDetect, JSFunction onCancel);
  external void stopWebScanner();
}

@JS('window')
external _JSWindow get _jsWindow;

void showScanTrigger({
  required double x,
  required double y,
  required double width,
  required double height,
  required void Function(String barcode) onDetect,
  required void Function() onCancel,
}) {
  _jsWindow.showScanTrigger(
    x, y, width, height,
    ((JSString code) => onDetect(code.toDart)).toJS,
    (() => onCancel()).toJS,
  );
}

void hideScanTrigger() => _jsWindow.hideScanTrigger();

void startWebScanner({
  required void Function(String barcode) onDetect,
  required void Function() onCancel,
}) {
  _jsWindow.startWebScanner(
    ((JSString code) => onDetect(code.toDart)).toJS,
    (() => onCancel()).toJS,
  );
}

void stopWebScanner() => _jsWindow.stopWebScanner();
