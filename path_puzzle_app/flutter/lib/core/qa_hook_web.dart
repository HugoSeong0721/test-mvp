import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void qaPublish(Map<String, Object?> state) {
  globalContext.setProperty('__pathPuzzle'.toJS, jsonEncode(state).toJS);
}
