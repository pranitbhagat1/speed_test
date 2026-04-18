import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  stdout.writeln('Speed test backend listening on http://127.0.0.1:8080');

  await for (final request in server) {
    try {
      _addCorsHeaders(request.response);

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        continue;
      }

      final path = request.uri.path;
      if (request.method == 'GET' && path == '/api/info') {
        await _handleInfo(request);
        continue;
      }

      if (request.method == 'GET' && path == '/api/download') {
        await _handleDownload(request);
        continue;
      }

      if (request.method == 'POST' && path == '/api/upload') {
        await _handleUpload(request);
        continue;
      }

      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Not found'}));
      await request.response.close();
    } catch (error, stackTrace) {
      stderr.writeln('Request handling failed: $error');
      stderr.writeln(stackTrace);
      try {
        _addCorsHeaders(request.response);
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': error.toString()}));
      } catch (_) {}
      await request.response.close();
    }
  }
}

void _addCorsHeaders(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Content-Type')
    ..set('Access-Control-Expose-Headers', 'Content-Length');
}

Future<void> _handleInfo(HttpRequest request) async {
  final response = request.response;

  response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(
      jsonEncode({
        'ip': '127.0.0.1',
        'provider': 'Local speed test backend',
        'regionLabel': 'Local machine',
        'server': 'Localhost Dart HTTP server',
      }),
    );
  await response.close();
}

Future<void> _handleDownload(HttpRequest request) async {
  final response = request.response;
  final bytes =
      int.tryParse(request.uri.queryParameters['bytes'] ?? '') ??
      (25 * 1024 * 1024);
  final chunkSize = 64 * 1024;
  final random = Random(42);

  response.statusCode = HttpStatus.ok;
  response.headers.contentType = ContentType.binary;
  response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
  response.headers.set(HttpHeaders.contentLengthHeader, bytes.toString());

  var remaining = bytes;
  while (remaining > 0) {
    final size = min(chunkSize, remaining);
    final chunk = Uint8List.fromList(
      List<int>.generate(size, (_) => random.nextInt(256)),
    );
    response.add(chunk);
    await response.flush();
    remaining -= size;
  }

  await response.close();
}

Future<void> _handleUpload(HttpRequest request) async {
  var totalBytes = 0;
  await for (final chunk in request) {
    totalBytes += chunk.length;
  }

  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({'receivedBytes': totalBytes}));
  await request.response.close();
}
