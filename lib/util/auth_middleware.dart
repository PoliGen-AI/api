import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

Handler requireAuth(Handler next) {
  return (Request req) async {
    final String? authHeader =
        req.headers['authorization'] ?? req.headers['Authorization'];
    if (authHeader == null || !authHeader.toLowerCase().startsWith('bearer ')) {
      return Response(HttpStatus.unauthorized, body: 'Missing bearer token');
    }
    final String token = authHeader.substring(7);
    final String secret =
        Platform.environment['JWT_SECRET'] ?? 'dev-secret-change-me';
    try {
      final JWT jwt = JWT.verify(token, SecretKey(secret));
      final String? email = jwt.payload['email'] as String?;
      if (email == null) {
        return Response(HttpStatus.unauthorized, body: 'Invalid token payload');
      }
      final Request nextReq = req.change(context: {'email': email});
      return await next(nextReq);
    } catch (_) {
      return Response(HttpStatus.unauthorized, body: 'Invalid token');
    }
  };
}
