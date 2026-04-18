import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'speed_test_service.dart';

void main() {
  runApp(const SpeedLensApp());
}

class SpeedLensApp extends StatelessWidget {
  const SpeedLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Speed Lens',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
        useMaterial3: true,
      ),
      home: const SpeedTestPage(),
    );
  }
}

class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({super.key});

  @override
  State<SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> {
  final SpeedTestService _service = createSpeedTestService();
  SpeedSnapshot _snapshot = const SpeedSnapshot();
  bool _isRunning = false;
  bool _serviceReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      unawaited(_primeService());
    }
  }

  Future<void> _primeService() async {
    try {
      final results = await Future.wait<Object>([
        _service.fetchConnectionInfo(),
        _service.resolveTestServer(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = _snapshot.copyWith(
          connectionInfo: results[0] as ConnectionInfo,
          serverInfo: results[1] as TestServerInfo,
          methodLabel: (results[1] as TestServerInfo).modeLabel,
          status: 'Ready to test',
        );
        _serviceReady = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _serviceReady = false;
        _error = 'Could not initialize the speed test: $error';
      });
    }
  }

  Future<void> _runSpeedTest() async {
    setState(() {
      _isRunning = true;
      _error = null;
      _snapshot = _snapshot.copyWith(
        status: 'Preparing test',
        clearDownloadLive: true,
        clearUploadLive: true,
        clearFinalDownload: true,
        clearFinalUpload: true,
        clearPing: true,
        clearSamples: true,
      );
    });

    try {
      final connectionInfo =
          _snapshot.connectionInfo ?? await _service.fetchConnectionInfo();
      final serverInfo =
          _snapshot.serverInfo ?? await _service.resolveTestServer();

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = _snapshot.copyWith(
          connectionInfo: connectionInfo,
          serverInfo: serverInfo,
          methodLabel: serverInfo.modeLabel,
          status: 'Measuring latency',
        );
      });

      final latencyMs = await _service.measureLatency(
        onProgress: (label) {
          if (!mounted) {
            return;
          }
          setState(() {
            _snapshot = _snapshot.copyWith(status: label);
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = _snapshot.copyWith(
          pingMs: latencyMs,
          status: 'Running download samples',
        );
      });

      final downloadResult = await _service.measureDownloadSpeed(
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _snapshot = _snapshot.copyWith(
              status:
                  '${progress.phaseLabel} (${progress.sampleIndex}/${progress.totalSamples})',
              downloadLiveMbps:
                  progress.currentMbps ?? _snapshot.downloadLiveMbps,
            );
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = _snapshot.copyWith(
          downloadLiveMbps: downloadResult.averageMbps,
          finalDownloadMbps: downloadResult.averageMbps,
          downloadSamples: downloadResult.samplesMbps,
          status: 'Running upload samples',
        );
      });

      final uploadResult = await _service.measureUploadSpeed(
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _snapshot = _snapshot.copyWith(
              status:
                  '${progress.phaseLabel} (${progress.sampleIndex}/${progress.totalSamples})',
              uploadLiveMbps: progress.currentMbps ?? _snapshot.uploadLiveMbps,
            );
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = _snapshot.copyWith(
          uploadLiveMbps: uploadResult.averageMbps,
          finalUploadMbps: uploadResult.averageMbps,
          uploadSamples: uploadResult.samplesMbps,
          status: 'Completed',
        );
        _serviceReady = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Speed test failed: $error';
        _serviceReady = false;
        _snapshot = _snapshot.copyWith(status: 'Failed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This project is intended for Flutter Web. Run it with a web target.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE6FFFB), Color(0xFFF9FAFB), Color(0xFFEFF6FF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1140),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          SizedBox(
                            width: 520,
                            child: _HeroPanel(
                              snapshot: _snapshot,
                              isRunning: _isRunning,
                              error: _error,
                              serviceReady: _serviceReady,
                              onRun: _runSpeedTest,
                            ),
                          ),
                          SizedBox(
                            width: 596,
                            child: Column(
                              children: [
                                _MetricStrip(snapshot: _snapshot),
                                const SizedBox(height: 20),
                                _InfoCard(
                                  title: 'Network identity',
                                  children: [
                                    _InfoRow(
                                      label: 'Client IP',
                                      value:
                                          _snapshot.connectionInfo?.clientIp ??
                                          'Loading',
                                    ),
                                    _InfoRow(
                                      label: 'ISP / organization',
                                      value:
                                          _snapshot.connectionInfo?.isp ??
                                          'Loading',
                                    ),
                                    _InfoRow(
                                      label: 'Region',
                                      value:
                                          _snapshot
                                              .connectionInfo
                                              ?.regionLabel ??
                                          'Loading',
                                    ),
                                    _InfoRow(
                                      label: 'IP lookup source',
                                      value:
                                          _snapshot
                                              .connectionInfo
                                              ?.lookupSource ??
                                          'Loading',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _InfoCard(
                                  title: 'Test server',
                                  children: [
                                    _InfoRow(
                                      label: 'Server label',
                                      value:
                                          _snapshot.serverInfo?.label ??
                                          'Resolving',
                                    ),
                                    _InfoRow(
                                      label: 'Test mode',
                                      value:
                                          _snapshot.serverInfo?.modeLabel ??
                                          'Resolving',
                                    ),
                                    _InfoRow(
                                      label: 'Location',
                                      value:
                                          _snapshot.serverInfo?.locationLabel ??
                                          'Resolving',
                                    ),
                                    _InfoRow(
                                      label: 'Endpoint',
                                      value:
                                          _snapshot.serverInfo?.endpoint ??
                                          'Resolving',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _InfoCard(
                                  title: 'Sample details',
                                  children: [
                                    _SampleRow(
                                      label: 'Download samples',
                                      samples: _snapshot.downloadSamples,
                                      color: const Color(0xFF14B8A6),
                                    ),
                                    const SizedBox(height: 14),
                                    _SampleRow(
                                      label: 'Upload samples',
                                      samples: _snapshot.uploadSamples,
                                      color: const Color(0xFF0EA5E9),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _InfoCard(
                                  title: 'Method notes',
                                  children: [
                                    Text(
                                      'Browser-only mode measures HTTP transfers directly from the client browser to Cloudflare test endpoints. Backend-assisted mode measures browser-to-your hosted backend and is the better option when you need a controlled test server for hosted deployments.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFF475569),
                                            height: 1.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.snapshot,
    required this.isRunning,
    required this.error,
    required this.serviceReady,
    required this.onRun,
  });

  final SpeedSnapshot snapshot;
  final bool isRunning;
  final String? error;
  final bool serviceReady;
  final Future<void> Function() onRun;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(
                text: 'Flutter Web Internet Speed Test',
                background: const Color(0x1AFFFFFF),
                border: Colors.transparent,
                foreground: Colors.white,
              ),
              _Pill(
                text: serviceReady
                    ? 'Service ready'
                    : 'Waiting for service or IP lookup',
                background: serviceReady
                    ? const Color(0x3322C55E)
                    : const Color(0x33F97316),
                border: serviceReady
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFF97316),
                foreground: serviceReady
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFED7AA),
              ),
              _Pill(
                text: snapshot.methodLabel,
                background: const Color(0x3322D3EE),
                border: const Color(0xFF22D3EE),
                foreground: const Color(0xFFCFFAFE),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Measure latency, average multiple transfer samples, and separate your client network identity from the chosen test server.',
            style: textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            snapshot.status,
            style: textTheme.titleMedium?.copyWith(
              color: const Color(0xFF99F6E4),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(
              error!,
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFFCA5A5),
              ),
            ),
          ],
          const SizedBox(height: 28),
          _MetricSummary(
            pingMs: snapshot.pingMs,
            downloadMbps:
                snapshot.finalDownloadMbps ?? snapshot.downloadLiveMbps,
            uploadMbps: snapshot.finalUploadMbps ?? snapshot.uploadLiveMbps,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: isRunning ? null : onRun,
            icon: Icon(isRunning ? Icons.hourglass_top : Icons.speed),
            label: Text(isRunning ? 'Running test' : 'Run speed test'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: const Color(0xFF042F2E),
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({
    required this.pingMs,
    required this.downloadMbps,
    required this.uploadMbps,
  });

  final double? pingMs;
  final double? downloadMbps;
  final double? uploadMbps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Ping',
            value: pingMs == null ? '--' : pingMs!.toStringAsFixed(0),
            unit: 'ms',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: 'Down',
            value: downloadMbps == null
                ? '--'
                : downloadMbps!.toStringAsFixed(2),
            unit: 'Mbps',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: 'Up',
            value: uploadMbps == null ? '--' : uploadMbps!.toStringAsFixed(2),
            unit: 'Mbps',
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFCBD5E1))),
          const SizedBox(height: 8),
          Text(
            '$value $unit',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.snapshot});

  final SpeedSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Download average',
            value:
                snapshot.finalDownloadMbps?.toStringAsFixed(2) ??
                snapshot.downloadLiveMbps?.toStringAsFixed(2) ??
                '--',
            unit: 'Mbps',
            accent: const Color(0xFF14B8A6),
            icon: Icons.south,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _MetricCard(
            label: 'Upload average',
            value:
                snapshot.finalUploadMbps?.toStringAsFixed(2) ??
                snapshot.uploadLiveMbps?.toStringAsFixed(2) ??
                '--',
            unit: 'Mbps',
            accent: const Color(0xFF0EA5E9),
            icon: Icons.north,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _MetricCard(
            label: 'Latency',
            value: snapshot.pingMs?.toStringAsFixed(0) ?? '--',
            unit: 'ms',
            accent: const Color(0xFFF97316),
            icon: Icons.network_ping,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accent.withValues(alpha: 0.14),
            foregroundColor: accent,
            child: Icon(icon),
          ),
          const SizedBox(height: 22),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleRow extends StatelessWidget {
  const _SampleRow({
    required this.label,
    required this.samples,
    required this.color,
  });

  final String label;
  final List<double> samples;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (samples.isEmpty)
          Text(
            'No samples yet',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < samples.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'S${i + 1}: ${samples[i].toStringAsFixed(2)} Mbps',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
