import 'models.dart';
import 'speed_test_service.dart';

class UnsupportedSpeedTestService implements SpeedTestService {
  UnsupportedError _unsupported() => UnsupportedError(
    'This speed test implementation is only available on Flutter Web.',
  );

  @override
  Future<ConnectionInfo> fetchConnectionInfo() async => throw _unsupported();

  @override
  Future<double> measureLatency({
    void Function(String label)? onProgress,
  }) async {
    throw _unsupported();
  }

  @override
  Future<SpeedTestResult> measureDownloadSpeed({
    void Function(SpeedTestProgress progress)? onProgress,
  }) async => throw _unsupported();

  @override
  Future<SpeedTestResult> measureUploadSpeed({
    void Function(SpeedTestProgress progress)? onProgress,
  }) async => throw _unsupported();

  @override
  Future<TestServerInfo> resolveTestServer() async => throw _unsupported();
}

SpeedTestService createPlatformSpeedTestService() =>
    UnsupportedSpeedTestService();
