import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:api_dart/storage/mongodb_store.dart';
import 'package:api_dart/util/auth_middleware.dart';

class HistoryRoutes {
  HistoryRoutes() : _store = MongoDBStore();

  final MongoDBStore _store;

  Router get router {
    final Router r = Router();
    r.get('/me', requireAuth(_me));
    return r;
  }

  Future<Response> _me(Request req) async {
    final String email = req.context['email'] as String;
    final List<Map<String, dynamic>> images = await _store.getUserImages(email);
    return Response.ok(jsonEncode({'images': images}), headers: _json);
  }
}

const Map<String, String> _json = {
  'content-type': 'application/json; charset=utf-8',
};
