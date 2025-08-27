import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:api_dart/storage/mongodb_store.dart';
import 'package:api_dart/util/auth_middleware.dart';

class AuthRoutes {
  AuthRoutes() : _store = MongoDBStore();

  final MongoDBStore _store;

  Router get router {
    final Router r = Router();

    // Public routes (no authentication required)
    r.post('/register', _register);
    r.post('/login', _login);
    r.post('/logout', _logout);
    r.get('/debug', _debug);

    // Protected routes (authentication required)
    final Router authRouter = Router();
    authRouter.get('/me', _me);
    authRouter.get('/test-auth', _testAuth);

    // Apply auth middleware to protected routes
    r.mount('/', requireAuth(authRouter));

    return r;
  }

  Future<Response> _register(Request req) async {
    final Map<String, dynamic> body = await _readJson(req);
    final String? name = body['name']?.toString();
    final String? email = body['email']?.toString();
    final String? password = body['password']?.toString();

    if (name == null ||
        name.isEmpty ||
        email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return _bad('name, email and password are required');
    }

    if (await _store.userExists(email)) {
      return _bad('user already exists', status: HttpStatus.conflict);
    }

    final String hash = _hashPassword(password);
    await _store.createUser(name: name, email: email, passwordHash: hash);

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
    final String token = _signJwt(email, user['name'] as String);

    // Create cookie with the JWT token
    final DateTime expiration = DateTime.now().add(const Duration(hours: 12));

    final String cookieValue =
        'auth_token=$token; HttpOnly; Path=/; '
        'Expires=${expiration.toUtc().toString().replaceAll(' ', '-').replaceAll(':', '%3A')}; '
        'Max-Age=${12 * 60 * 60}; ' // 12 hours in seconds
        'SameSite=Lax${Platform.environment['PRODUCTION'] == 'true' ? '; Secure' : ''}';

    final Map<String, String> headers = Map<String, String>.from(_json);
    headers['set-cookie'] = cookieValue;

    print('Setting cookie: $cookieValue'); // Debug logging

    return Response.ok(
      jsonEncode({'token': token, 'message': 'Login successful, cookie set'}),
      headers: headers,
    );
  }

  Future<Response> _logout(Request req) async {
    // Clear the authentication cookie
    final String cookieValue =
        'auth_token=; HttpOnly; Path=/; '
        'Expires=Thu, 01 Jan 1970 00:00:00 GMT; '
        'Max-Age=0; SameSite=Lax';

    final Map<String, String> headers = Map<String, String>.from(_json);
    headers['set-cookie'] = cookieValue;

    print('Clearing cookie: $cookieValue'); // Debug logging

    return Response.ok(
      jsonEncode({'message': 'Logged out successfully'}),
      headers: headers,
    );
  }

  Future<Response> _me(Request req) async {
    // Get user email from the context (set by auth middleware)
    final String? email = req.context['email'] as String?;
    if (email == null) {
      return _bad('User not authenticated', status: HttpStatus.unauthorized);
    }

    // Fetch user details from database
    final Map<String, dynamic>? user = await _store.getUser(email);
    if (user == null) {
      return _bad('User not found', status: HttpStatus.notFound);
    }

    // Return user information (excluding sensitive data)
    final Map<String, dynamic> userInfo = {
      'email': user['email'],
      'name': user['name'],
      'createdAt': user['createdAt'],
    };

    return Response.ok(jsonEncode(userInfo), headers: _json);
  }

  Future<Response> _testAuth(Request req) async {
    final String? cookieHeader = req.headers['cookie'];
    final String? authHeader =
        req.headers['authorization'] ?? req.headers['Authorization'];

    final Map<String, dynamic> testInfo = {
      'timestamp': DateTime.now().toIso8601String(),
      'cookie_header': cookieHeader,
      'authorization_header': authHeader,
      'method': req.method,
      'url': req.url.toString(),
      'context': req.context,
    };

    // Test cookie parsing
    String? token = null;
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
      testInfo['token_source'] = 'authorization_header';
    } else if (cookieHeader != null) {
      final List<String> cookies = cookieHeader.split(';');
      for (final String cookie in cookies) {
        final String trimmedCookie = cookie.trim();
        final int equalsIndex = trimmedCookie.indexOf('=');
        if (equalsIndex > 0) {
          final String key = trimmedCookie.substring(0, equalsIndex).trim();
          final String value = trimmedCookie.substring(equalsIndex + 1).trim();
          if (key == 'auth_token') {
            token = value;
            testInfo['token_source'] = 'cookie';
            break;
          }
        }
      }
    }

    testInfo['token_found'] = token != null;
    if (token != null) {
      testInfo['token_preview'] = token.substring(0, 20) + '...';

      // Test JWT verification
      final String secret =
          Platform.environment['JWT_SECRET'] ?? 'dev-secret-change-me';
      try {
        final JWT jwt = JWT.verify(token, SecretKey(secret));
        final String? email = jwt.payload['email'] as String?;
        final String? name = jwt.payload['name'] as String?;
        testInfo['jwt_verification'] = 'success';
        testInfo['user_email'] = email;
        testInfo['user_name'] = name;

        // Extract only serializable payload data safely
        final Map<String, dynamic> serializablePayload = {};
        try {
          jwt.payload.forEach((key, value) {
            if (value is String ||
                value is int ||
                value is bool ||
                value is double ||
                value == null) {
              serializablePayload[key] = value;
            } else {
              // Safely convert to string, handling any serialization issues
              try {
                serializablePayload[key] = value.toString();
              } catch (e) {
                serializablePayload[key] =
                    '[Non-serializable: ${value.runtimeType}]';
              }
            }
          });
          testInfo['jwt_payload'] = serializablePayload;
        } catch (e) {
          testInfo['jwt_payload'] = {
            'error': 'Could not serialize payload',
            'type': e.toString(),
          };
        }
      } catch (e) {
        testInfo['jwt_verification'] = 'failed';
        testInfo['jwt_error'] = e.toString();
      }
    }

    // Safely encode JSON to prevent serialization errors
    try {
      return Response.ok(jsonEncode(testInfo), headers: _json);
    } catch (e) {
      // If JSON encoding fails, return a simplified response
      final Map<String, dynamic> safeResponse = {
        'timestamp': testInfo['timestamp'],
        'cookie_header': testInfo['cookie_header']?.toString(),
        'authorization_header': testInfo['authorization_header']?.toString(),
        'token_found': testInfo['token_found'],
        'jwt_verification': testInfo['jwt_verification'] ?? 'failed',
        'serialization_error': e.toString(),
        'message': 'Response contained non-serializable data',
      };
      return Response.ok(jsonEncode(safeResponse), headers: _json);
    }
  }

  Future<Response> _debug(Request req) async {
    final String? cookieHeader = req.headers['cookie'];
    final String? authHeader =
        req.headers['authorization'] ?? req.headers['Authorization'];

    final Map<String, dynamic> debugInfo = {
      'timestamp': DateTime.now().toIso8601String(),
      'headers': req.headers,
      'cookie_header': cookieHeader,
      'authorization_header': authHeader,
      'method': req.method,
      'url': req.url.toString(),
    };

    // Parse cookies if present
    if (cookieHeader != null) {
      final List<String> cookies = cookieHeader.split(';');
      final Map<String, String> parsedCookies = {};

      for (final String cookie in cookies) {
        final List<String> parts = cookie.trim().split('=');
        if (parts.length >= 2) {
          parsedCookies[parts[0]] = parts.sublist(1).join('=');
        }
      }

      debugInfo['parsed_cookies'] = parsedCookies;
      debugInfo['has_auth_token'] = parsedCookies.containsKey('auth_token');
    }

    return Response.ok(jsonEncode(debugInfo), headers: _json);
  }

  String _hashPassword(String password) {
    final List<int> bytes = utf8.encode(password);
    final crypto.Digest digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  String _signJwt(String email, String name) {
    final String secret =
        Platform.environment['JWT_SECRET'] ?? 'dev-secret-change-me';
    print('JWT Signing: Using secret: ${secret.substring(0, 10)}...');

    final JWT jwt = JWT({'email': email, 'name': name});
    final String token = jwt.sign(
      SecretKey(secret),
      expiresIn: const Duration(hours: 12),
    );
    print(
      'JWT Signing: Created token for $email: ${token.substring(0, 20)}...',
    );

    // Test verify the token immediately to check for issues
    try {
      final JWT verifyJwt = JWT.verify(token, SecretKey(secret));
      print('JWT Signing: Self-verification successful');
    } catch (e) {
      print('JWT Signing: Self-verification failed: $e');
    }

    return token;
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
