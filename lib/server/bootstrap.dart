import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:api_dart/routes/auth_routes.dart';
import 'package:api_dart/routes/image_routes.dart';
import 'package:api_dart/routes/history_routes.dart';

Router buildRouter() {
  final Router router = Router();

  // Health
  router.get(
    '/health',
    (Request req) => Response.ok(jsonEncode({'ok': true}), headers: _json),
  );

  // Auth
  final AuthRoutes authRoutes = AuthRoutes();
  router.mount('/auth/', authRoutes.router);

  // Image generation
  final ImageRoutes imageRoutes = ImageRoutes();
  router.mount('/image/', imageRoutes.router);

  // User history
  final HistoryRoutes historyRoutes = HistoryRoutes();
  router.mount('/history/', historyRoutes.router);

  // 404 fallback
  router.all(
    '/<ignored|.*>',
    (Request req) =>
        Response.notFound(jsonEncode({'error': 'Not Found'}), headers: _json),
  );

  return router;
}

const Map<String, String> _json = {
  'content-type': 'application/json; charset=utf-8',
};
