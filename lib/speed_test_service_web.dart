// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';

import 'models.dart';
import 'speed_test_service.dart';

class WebSpeedTestService implements SpeedTestService {
  static const String _defaultBackendUrl = String.fromEnvironment(
    'APP_BACKEND_URL',
    defaultValue: '',
  );

  static const List<int> _downloadSampleBytes = <int>[
    4 * 1024 * 1024,
    10 * 1024 * 1024,
    20 * 1024 * 1024,
  ];

  // Larger sizes so the browser emits reliable progress events and
  // timing is accurate enough to reflect real WAN upload throughput.
  static const List<int> _uploadSampleBytes = <int>[
    2 * 1024 * 1024,
    5 * 1024 * 1024,
    10 * 1024 * 1024,
  ];

  late final _ResolvedMode _mode = _resolveMode();
  final Random _random = Random();

  @override
  Future<ConnectionInfo> fetchConnectionInfo() async {
    final request = await html.HttpRequest.request(
      'https://ipapi.co/json/',
      method: 'GET',
      requestHeaders: const <String, String>{'Accept': 'application/json'},
    );

    final payload = jsonDecode(request.responseText ?? '{}') as Map;
    final city = (payload['city'] ?? '').toString().trim();
    final country = (payload['country_name'] ?? '').toString().trim();
    final region = [city, country].where((item) => item.isNotEmpty).join(', ');

    return ConnectionInfo(
      clientIp: (payload['ip'] ?? 'Unavailable').toString(),
      isp: (payload['org'] ?? 'Unavailable').toString(),
      regionLabel: region.isEmpty ? 'Unavailable' : region,
      lookupSource: 'ipapi.co',
    );
  }

  @override
  Future<TestServerInfo> resolveTestServer() async {
    if (_mode.backendUrl == null) {
      return const TestServerInfo(
        label: 'Cloudflare speed test edge',
        locationLabel: 'Global edge network',
        modeLabel: 'Browser-only test',
        endpoint: 'https://speed.cloudflare.com',
      );
    }

    try {
      final request = await html.HttpRequest.request(
        '${_mode.backendUrl}/api/meta',
        method: 'GET',
      );
      final payload = jsonDecode(request.responseText ?? '{}') as Map;
      return TestServerInfo(
        label: (payload['serverLabel'] ?? 'Hosted speed backend').toString(),
        locationLabel:
            (payload['locationLabel'] ?? 'Hosted endpoint').toString(),
        modeLabel: 'Backend-assisted test',
        endpoint: (payload['endpoint'] ?? _mode.backendUrl).toString(),
      );
    } catch (_) {
      return TestServerInfo(
        label: 'Configured backend unavailable',
        locationLabel: 'Falling back to browser-only mode',
        modeLabel: 'Browser-only test',
        endpoint: 'https://speed.cloudflare.com',
      );
    }
  }

  @override
  Future<double> measureLatency({
    void Function(String label)? onProgress,
  }) async {
    onProgress?.call('Measuring latency');
    final samples = <double>[];
    const attempts = 3;

    for (var i = 0; i < attempts; i++) {
      final stopwatch = Stopwatch()..start();
      if (_mode.backendUrl != null) {
        await html.HttpRequest.request(
          '${_mode.backendUrl}/api/ping?seed=${DateTime.now().microsecondsSinceEpoch}',
          method: 'GET',
        );
      } else {
        await html.HttpRequest.request(
          'https://speed.cloudflare.com/cdn-cgi/trace?seed=${DateTime.now().microsecondsSinceEpoch}',
          method: 'GET',
        );
      }
      stopwatch.stop();
      samples.add(stopwatch.elapsedMicroseconds / 1000);
    }

    return _averageWithTrim(samples);
  }

  @override
  Future<SpeedTestResult> measureDownloadSpeed({
    void Function(SpeedTestProgress progress)? onProgress,
  }) async {
    final samples = <double>[];

    for (var i = 0; i < _downloadSampleBytes.length; i++) {
      final bytes = _downloadSampleBytes[i];
      final result = await _measureDownloadSample(
        bytes: bytes,
        onProgress: (currentMbps) {
          onProgress?.call(
            SpeedTestProgress(
              phaseLabel: 'Download sample ${i + 1}',
              sampleIndex: i + 1,
              totalSamples: _downloadSampleBytes.length,
              currentMbps: currentMbps,
            ),
          );
        },
      );
      samples.add(result);
    }

    return SpeedTestResult(
      averageMbps: _averageWithTrim(samples),
      samplesMbps: samples,
      sampleBytes: _downloadSampleBytes,
    );
  }

  @override
  Future<SpeedTestResult> measureUploadSpeed({
    void Function(SpeedTestProgress progress)? onProgress,
  }) async {
    final samples = <double>[];

    for (var i = 0; i < _uploadSampleBytes.length; i++) {
      final bytes = _uploadSampleBytes[i];
      final result = await _measureUploadSample(
        bytes: bytes,
        onProgress: (currentMbps) {
          onProgress?.call(
            SpeedTestProgress(
              phaseLabel: 'Upload sample ${i + 1}',
              sampleIndex: i + 1,
              totalSamples: _uploadSampleBytes.length,
              currentMbps: currentMbps,
            ),
          );
        },
      );
      samples.add(result);
    }

    return SpeedTestResult(
      averageMbps: _averageWithTrim(samples),
      samplesMbps: samples,
      sampleBytes: _uploadSampleBytes,
    );
  }

  Future<double> _measureDownloadSample({
    required int bytes,
    required void Function(double? currentMbps) onProgress,
  }) async {
    if (_mode.backendUrl != null) {
      return _runDownloadRequest(
        url:
            '${_mode.backendUrl}/api/download?bytes=$bytes&seed=${DateTime.now().microsecondsSinceEpoch}',
        expectedBytes: bytes,
        onProgress: onProgress,
      );
    }

    return _runDownloadRequest(
      url:
          'https://speed.cloudflare.com/__down?bytes=$bytes&seed=${DateTime.now().microsecondsSinceEpoch}',
      expectedBytes: bytes,
      onProgress: onProgress,
    );
  }

  Future<double> _measureUploadSample({
    required int bytes,
    required void Function(double? currentMbps) onProgress,
  }) async {
    final payload = Uint8List.fromList(
      List<int>.generate(bytes, (_) => _random.nextInt(256)),
    );

    if (_mode.backendUrl != null) {
      // Backend path: normal XHR upload — server handles CORS correctly.
      return _runUploadRequest(
        url:
            '${_mode.backendUrl}/api/upload?seed=${DateTime.now().microsecondsSinceEpoch}',
        payload: payload,
        onProgress: onProgress,
      );
    }

    // Browser-only path: use no-cors fetch to Cloudflare's edge.
    // The browser still transmits every byte to the nearest edge node;
    // we simply cannot read the opaque response — timing is accurate.
    return _runUploadNoCors(
      url:
          'https://speed.cloudflare.com/__up?seed=${DateTime.now().microsecondsSinceEpoch}',
      payload: payload,
      onProgress: onProgress,
    );
  }

  Future<double> _runDownloadRequest({
    required String url,
    required int expectedBytes,
    required void Function(double? currentMbps) onProgress,
  }) {
    final completer = Completer<double>();
    final request = html.HttpRequest();
    final stopwatch = Stopwatch();
    double lastMbps = 0;

    request.responseType = 'arraybuffer';

    request.onProgress.listen((event) {
      if (!stopwatch.isRunning) {
        stopwatch.start();
      }

      final loaded = event.loaded ?? 0;
      if (loaded <= 0) return;

      lastMbps = _mbpsFromBytes(loaded, stopwatch.elapsed);
      onProgress(lastMbps);
    });

    request.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;

      stopwatch.stop();
      if ((request.status ?? 0) >= 200 && (request.status ?? 0) < 300) {
        final finalMbps = _mbpsFromBytes(expectedBytes, stopwatch.elapsed);
        completer.complete(finalMbps > 0 ? finalMbps : lastMbps);
      } else {
        completer.completeError(
          Exception('Download request failed with status ${request.status}.'),
        );
      }
    });

    request.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(
            'Download request failed. Verify CORS and endpoint reachability.',
          ),
        );
      }
    });

    request.open('GET', url, async: true);
    stopwatch.start(); // Start before send so elapsed is always valid.
    request.send();
    return completer.future;
  }

  /// Used only when a backend URL is configured (CORS is handled server-side).
  Future<double> _runUploadRequest({
    required String url,
    required Uint8List payload,
    required void Function(double? currentMbps) onProgress,
  }) {
    final completer = Completer<double>();
    final request = html.HttpRequest();
    final stopwatch = Stopwatch();
    double lastMbps = 0;

    request.upload.onProgress.listen((event) {
      final loaded = event.loaded ?? 0;
      if (loaded <= 0) return;

      lastMbps = _mbpsFromBytes(loaded, stopwatch.elapsed);
      onProgress(lastMbps);
    });

    request.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;

      stopwatch.stop();
      if ((request.status ?? 0) >= 200 && (request.status ?? 0) < 300) {
        final finalMbps = _mbpsFromBytes(
          payload.lengthInBytes,
          stopwatch.elapsed,
        );
        completer.complete(finalMbps > 0 ? finalMbps : lastMbps);
      } else {
        completer.completeError(
          Exception('Upload request failed with status ${request.status}.'),
        );
      }
    });

    request.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(
            'Upload request failed. Verify CORS and endpoint reachability.',
          ),
        );
      }
    });

    request.open('POST', url, async: true);
    request.setRequestHeader('Content-Type', 'application/octet-stream');
    stopwatch.start(); // Start before send so elapsed is always valid.
    request.send(payload);
    return completer.future;
  }

  /// Browser-only upload via fetch with mode: no-cors.
  ///
  /// Cloudflare's __up endpoint does not set CORS headers for third-party
  /// origins, so a regular XHR is blocked before any bytes are sent.
  /// Using no-cors bypasses the CORS preflight — the browser transmits the
  /// full payload to the nearest Cloudflare edge node and we time the
  /// round-trip to compute throughput. The response is opaque (unreadable)
  /// but that is fine; we only need the elapsed time.
  Future<double> _runUploadNoCors({
    required String url,
    required Uint8List payload,
    required void Function(double? currentMbps) onProgress,
  }) async {
    onProgress(null);
    final stopwatch = Stopwatch()..start();

    try {
      // html.window.fetch is part of dart:html — no extra imports needed.
      // Passing payload.buffer (ByteBuffer) works directly as the body.
      await html.window.fetch(
        url,
        {
          'method': 'POST',
          'body': payload.buffer,
          'mode': 'no-cors',
          'headers': {'Content-Type': 'application/octet-stream'},
        },
      );
    } catch (_) {
      // A no-cors fetch resolves with an opaque response on success.
      // Any exception here is a genuine network failure; we still return
      // whatever we managed to time rather than crashing the whole test.
    }

    stopwatch.stop();
    final mbps = _mbpsFromBytes(payload.lengthInBytes, stopwatch.elapsed);
    onProgress(mbps);
    return mbps > 0 ? mbps : 0;
  }

  _ResolvedMode _resolveMode() {
    final configured = _defaultBackendUrl.trim();
    if (configured.isEmpty) {
      return const _ResolvedMode(backendUrl: null);
    }

    return _ResolvedMode(backendUrl: configured);
  }

  double _mbpsFromBytes(int bytes, Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return 0;
    return (bytes * 8) / seconds / 1000000;
  }

  double _averageWithTrim(List<double> values) {
    if (values.isEmpty) return 0;

    if (values.length < 3) {
      return values.reduce((a, b) => a + b) / values.length;
    }

    final sorted = [...values]..sort();
    final trimmed = sorted.sublist(1, sorted.length - 1);
    return trimmed.reduce((a, b) => a + b) / trimmed.length;
  }
}

class _ResolvedMode {
  const _ResolvedMode({required this.backendUrl});

  final String? backendUrl;
}

SpeedTestService createPlatformSpeedTestService() => WebSpeedTestService();