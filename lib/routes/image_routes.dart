import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'package:api_dart/storage/json_store.dart';
import 'package:api_dart/util/auth_middleware.dart';

class ImageRoutes {
  ImageRoutes() : _store = JsonStore();

  final JsonStore _store;
  final Uuid _uuid = const Uuid();

  Router get router {
    final Router r = Router();
    // Apply auth as a middleware to preserve path params
    final Router authed = Router();
    authed.post('/generate', _generate);
    authed.get('/file/<id>', _getFile);
    r.mount('/', requireAuth(authed));
    return r;
  }

  Future<Response> _generate(Request req) async {
    final Map<String, dynamic> body = await _readJson(req);
    final String? prompt = body['prompt']?.toString();
    final int width = int.tryParse(body['width']?.toString() ?? '') ?? 512;
    final int height = int.tryParse(body['height']?.toString() ?? '') ?? 512;
    if (prompt == null || prompt.isEmpty) {
      return _bad('prompt is required');
    }

    final String userEmail = req.context['email'] as String;
    final String id = _uuid.v4();

    // Simple placeholder image generation using noise + prompt text overlay
    final img.Image base = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int noise = ((x * 31 + y * 17 + prompt.length * 97) % 255);
        base.setPixelRgb(x, y, noise, (noise * 2) % 255, (noise * 3) % 255);
      }
    }

    // Save to disk
    final Directory outDir = await _store.imagesDir();
    final File file = File('${outDir.path}/$id.png');
    await file.writeAsBytes(img.encodePng(base));

    // Record metadata
    await _store.addImageRecord(
      userEmail: userEmail,
      id: id,
      prompt: prompt,
      path: file.path,
    );

    return Response.ok(
      jsonEncode({'id': id, 'path': 'image/file/$id'}),
      headers: _json,
    );
  }

  Future<Response> _getFile(Request req, String id) async {
    final Map<String, dynamic>? record = await _store.getImageRecord(id);
    if (record == null) {
      return Response.notFound(
        jsonEncode({'error': 'not found'}),
        headers: _json,
      );
    }
    final File file = File(record['path'] as String);
    if (!await file.exists()) {
      return Response.notFound(
        jsonEncode({'error': 'file missing'}),
        headers: _json,
      );
    }
    final List<int> bytes = await file.readAsBytes();
    return Response.ok(bytes, headers: const {'content-type': 'image/png'});
  }
}

Future<Map<String, dynamic>> _readJson(Request req) async {
  final String body = await req.readAsString();
  if (body.isEmpty) return <String, dynamic>{};
  return jsonDecode(body) as Map<String, dynamic>;
}

Response _bad(String message) =>
    Response(400, body: jsonEncode({'error': message}), headers: _json);

const Map<String, String> _json = {
  'content-type': 'application/json; charset=utf-8',
};
