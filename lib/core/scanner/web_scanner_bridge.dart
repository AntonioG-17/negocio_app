import 'dart:js_interop';

@JS('startWebScanner')
external void _jsStart(JSFunction onDetect, JSFunction onCancel);

@JS('stopWebScanner')
external void _jsStop();

void startWebScanner({
  required void Function(String barcode) onDetect,
  required void Function() onCancel,
}) {
  _jsStart(
    ((JSString code) => onDetect(code.toDart)).toJS,
    onCancel.toJS,
  );
}

void stopWebScanner() => _jsStop();
