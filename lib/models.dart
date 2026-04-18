class ConnectionInfo {
  const ConnectionInfo({
    required this.clientIp,
    required this.isp,
    required this.regionLabel,
    required this.lookupSource,
  });

  final String clientIp;
  final String isp;
  final String regionLabel;
  final String lookupSource;
}

class TestServerInfo {
  const TestServerInfo({
    required this.label,
    required this.locationLabel,
    required this.modeLabel,
    required this.endpoint,
  });

  final String label;
  final String locationLabel;
  final String modeLabel;
  final String endpoint;
}

class SpeedTestResult {
  const SpeedTestResult({
    required this.averageMbps,
    required this.samplesMbps,
    required this.sampleBytes,
  });

  final double averageMbps;
  final List<double> samplesMbps;
  final List<int> sampleBytes;
}

class SpeedTestProgress {
  const SpeedTestProgress({
    required this.phaseLabel,
    required this.sampleIndex,
    required this.totalSamples,
    this.currentMbps,
  });

  final String phaseLabel;
  final int sampleIndex;
  final int totalSamples;
  final double? currentMbps;
}

class SpeedSnapshot {
  const SpeedSnapshot({
    this.downloadLiveMbps,
    this.uploadLiveMbps,
    this.finalDownloadMbps,
    this.finalUploadMbps,
    this.pingMs,
    this.downloadSamples = const <double>[],
    this.uploadSamples = const <double>[],
    this.connectionInfo,
    this.serverInfo,
    this.status = 'Ready to test',
    this.methodLabel = 'Auto',
  });

  final double? downloadLiveMbps;
  final double? uploadLiveMbps;
  final double? finalDownloadMbps;
  final double? finalUploadMbps;
  final double? pingMs;
  final List<double> downloadSamples;
  final List<double> uploadSamples;
  final ConnectionInfo? connectionInfo;
  final TestServerInfo? serverInfo;
  final String status;
  final String methodLabel;

  SpeedSnapshot copyWith({
    double? downloadLiveMbps,
    double? uploadLiveMbps,
    double? finalDownloadMbps,
    double? finalUploadMbps,
    double? pingMs,
    List<double>? downloadSamples,
    List<double>? uploadSamples,
    ConnectionInfo? connectionInfo,
    TestServerInfo? serverInfo,
    String? status,
    String? methodLabel,
    bool clearDownloadLive = false,
    bool clearUploadLive = false,
    bool clearFinalDownload = false,
    bool clearFinalUpload = false,
    bool clearPing = false,
    bool clearSamples = false,
  }) {
    return SpeedSnapshot(
      downloadLiveMbps: clearDownloadLive
          ? null
          : (downloadLiveMbps ?? this.downloadLiveMbps),
      uploadLiveMbps: clearUploadLive
          ? null
          : (uploadLiveMbps ?? this.uploadLiveMbps),
      finalDownloadMbps: clearFinalDownload
          ? null
          : (finalDownloadMbps ?? this.finalDownloadMbps),
      finalUploadMbps: clearFinalUpload
          ? null
          : (finalUploadMbps ?? this.finalUploadMbps),
      pingMs: clearPing ? null : (pingMs ?? this.pingMs),
      downloadSamples: clearSamples
          ? const <double>[]
          : (downloadSamples ?? this.downloadSamples),
      uploadSamples: clearSamples
          ? const <double>[]
          : (uploadSamples ?? this.uploadSamples),
      connectionInfo: connectionInfo ?? this.connectionInfo,
      serverInfo: serverInfo ?? this.serverInfo,
      status: status ?? this.status,
      methodLabel: methodLabel ?? this.methodLabel,
    );
  }
}
