// 웹이면 브라우저 위치 API, 아이폰·안드로이드면 geolocator.
export 'location_native.dart' if (dart.library.js_interop) 'location_web.dart';
