import 'models.dart';
import 'speed_test_service_stub.dart'
    if (dart.library.html) 'speed_test_service_web.dart';

abstract class SpeedTestService {
  Future<ConnectionInfo> fetchConnectionInfo();

  Future<TestServerInfo> resolveTestServer();

  Future<double> measureLatency({void Function(String label)? onProgress});

  Future<SpeedTestResult> measureDownloadSpeed({
    void Function(SpeedTestProgress progress)? onProgress,
  });

  Future<SpeedTestResult> measureUploadSpeed({
    void Function(SpeedTestProgress progress)? onProgress,
  });
}

SpeedTestService createSpeedTestService() => createPlatformSpeedTestService();
