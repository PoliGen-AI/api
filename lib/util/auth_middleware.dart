import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

Handler requireAuth(Handler next) {
  return (Request req) async {
    String? token;

    // First try to get token from Authorization header
    final String? authHeader =
        req.headers['authorization'] ?? req.headers['Authorization'];
    if (authHeader != null && authHeader.toLowerCase().startsWith('bearer ')) {
      token = authHeader.substring(7);
    }

    // If no token in header, try to get from cookie
    if (token == null) {
      final String? cookieHeader = req.headers['cookie'];
      print('Cookie header received: $cookieHeader'); // Debug logging
      if (cookieHeader != null) {
        // Parse cookies to find the auth token
        final List<String> cookies = cookieHeader.split(';');
        for (final String cookie in cookies) {
          final String trimmedCookie = cookie.trim();
          // Find the first equals sign to split key and value
          final int equalsIndex = trimmedCookie.indexOf('=');
          if (equalsIndex > 0) {
            final String key = trimmedCookie.substring(0, equalsIndex).trim();
            final String value = trimmedCookie
                .substring(equalsIndex + 1)
                .trim();
            print('Cookie part: "$key" = "$value"'); // Debug logging
            if (key == 'auth_token') {
              token = value;
              print(
                'Found auth_token: ${token.substring(0, 20)}...',
              ); // Debug logging (truncated)
              break;
            }
          }
        }
      }
    }

    if (token == null || token.isEmpty) {
      print('Auth middleware: No token found in request');
      return Response(
        HttpStatus.unauthorized,
        body: 'Missing authentication token',
      );
    }

    final String secret =
        Platform.environment['JWT_SECRET'] ?? 'dev-secret-change-me';
    print('Auth middleware: Using JWT secret: ${secret.substring(0, 10)}...');
    print('Auth middleware: Token to verify: ${token.substring(0, 20)}...');

    try {
      final JWT jwt = JWT.verify(token, SecretKey(secret));
      final String? email = jwt.payload['email'] as String?;
      print('Auth middleware: JWT verified successfully for email: $email');

      if (email == null) {
        print('Auth middleware: Email is null in JWT payload');
        return Response(HttpStatus.unauthorized, body: 'Invalid token payload');
      }

      final Request nextReq = req.change(context: {'email': email});
      print(
        'Auth middleware: Proceeding with authenticated request for: $email',
      );
      return await next(nextReq);
    } catch (e) {
      // Clean up the error message to avoid serialization issues
      final String errorMessage = e.toString().replaceAll(
        RegExp(r'Instance of [_$][^ ]+'),
        '[Object]',
      );
      print('Auth middleware: JWT verification failed: $errorMessage');
      return Response(HttpStatus.unauthorized, body: 'Invalid token');
    }
  };
}
