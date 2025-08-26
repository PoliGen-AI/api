import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:api_dart/server/bootstrap.dart';

Future<void> main(List<String> arguments) async {
  final int port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final Router router = buildRouter();

  final Handler handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router);

  final HttpServer server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    port,
  );
  // Disable request body size limit if needed: server.autoCompress = true;
  print('REST API listening on port ${server.port}');
}
