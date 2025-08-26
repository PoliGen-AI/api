import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:api_dart/storage/json_store.dart';

class AuthRoutes {
  AuthRoutes() : _store = JsonStore();

  final JsonStore _store;

  Router get router {
    final Router r = Router();
    r.post('/register', _register);
    r.post('/login', _login);
    return r;
  }

  Future<Response> _register(Request req) async {
    final Map<String, dynamic> body = await _readJson(req);
    final String? email = body['email']?.toString();
    final String? password = body['password']?.toString();
    if (email == null ||
        password == null ||
        email.isEmpty ||
        password.isEmpty) {
      return _bad('email and password are required');
    }
    if (await _store.userExists(email)) {
      return _bad('user already exists', status: HttpStatus.conflict);
    }
    final String hash = _hashPassword(password);
    await _store.createUser(email: email, passwordHash: hash);
    return Response.ok(jsonEncode({'ok': true}), headers: _json);
  }

  Future<Response> _login(Request req) async {
    final Map<String, dynamic> body = await _readJson(req);
    final String? email = body['email']?.toString();
    final String? password = body['password']?.toString();
    if (email == null || password == null) {
      return _bad('email and password are required');
    }
    final Map<String, dynamic>? user = await _store.getUser(email);
    if (user == null) {
      return _bad('invalid credentials', status: HttpStatus.unauthorized);
    }
    final String hash = _hashPassword(password);
    if (user['passwordHash'] != hash) {
      return _bad('invalid credentials', status: HttpStatus.unauthorized);
    }
    final String token = _signJwt(email);
    return Response.ok(jsonEncode({'token': token}), headers: _json);
  }

  String _hashPassword(String password) {
    final List<int> bytes = utf8.encode(password);
    final crypto.Digest digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  String _signJwt(String email) {
    final String secret =
        Platform.environment['JWT_SECRET'] ?? 'dev-secret-change-me';
    final JWT jwt = JWT({'email': email});
    return jwt.sign(SecretKey(secret), expiresIn: const Duration(hours: 12));
  }
}

Future<Map<String, dynamic>> _readJson(Request req) async {
  final String body = await req.readAsString();
  if (body.isEmpty) return <String, dynamic>{};
  return jsonDecode(body) as Map<String, dynamic>;
}

Response _bad(String message, {int status = HttpStatus.badRequest}) {
  return Response(status, body: jsonEncode({'error': message}), headers: _json);
}

const Map<String, String> _json = {
  'content-type': 'application/json; charset=utf-8',
};
