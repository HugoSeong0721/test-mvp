// 웹 미리보기 자동 점검용: 지금 판의 상태(정답 줄 포함)를 window.__pathPuzzle 에 JSON 으로 남긴다.
// 아이폰 앱에서는 아무것도 하지 않는다 (조건부 import).
export 'qa_hook_stub.dart' if (dart.library.js_interop) 'qa_hook_web.dart';
