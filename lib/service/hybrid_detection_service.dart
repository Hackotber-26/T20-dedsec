import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pehchaan/service/detection_service.dart';

import 'ai_detection_service.dart';

enum DetectionSource {
  ai,
  offline,
  localFallback,
}

class DetectionOutcome {
  const DetectionOutcome({
    required this.result,
    required this.source,
    this.fallbackReason,
  });

  final RiskResult result;
  final DetectionSource source;
  final String? fallbackReason;

  String get sourceLabel {
    switch (source) {
      case DetectionSource.ai:
        return 'AI Analysis';
      case DetectionSource.offline:
        return 'Offline Protection';
      case DetectionSource.localFallback:
        return 'Local Fallback';
    }
  }
}

class HybridDetectionService {
  HybridDetectionService({
    DetectionService? localDetector,
    AiDetectionService? aiDetector,
    Connectivity? connectivity,
  })  : _localDetector =
            localDetector ?? DetectionService.instance,
        _aiDetector = aiDetector ?? AiDetectionService(),
        _connectivity = connectivity ?? Connectivity();

  final DetectionService _localDetector;
  final AiDetectionService _aiDetector;
  final Connectivity _connectivity;

  Future<DetectionOutcome> analyzeMessage(String input) {
    return _analyze(
      input: input,
      inputType: 'message',
    );
  }

  Future<DetectionOutcome> analyzeUrl(String input) {
    return _analyze(
      input: input,
      inputType: 'url',
    );
  }

  Future<DetectionOutcome> analyzeUpi(String input) {
    return _analyze(
      input: input,
      inputType: 'upi',
    );
  }

  Future<DetectionOutcome> _analyze({
    required String input,
    required String inputType,
  }) async {
    if (input.trim().isEmpty) {
      return DetectionOutcome(
        result: _runLocal(input, inputType),
        source: DetectionSource.offline,
      );
    }

    final hasNetwork = await _hasNetwork();

    // No network: use local detection immediately.
    if (!hasNetwork) {
      return DetectionOutcome(
        result: _runLocal(input, inputType),
        source: DetectionSource.offline,
      );
    }

    // Network exists: try AI.
    try {
      final result = await _aiDetector.analyze(
        input: input,
        inputType: inputType,
      );

      return DetectionOutcome(
        result: result,
        source: DetectionSource.ai,
      );
    } catch (error) {
      // AI server failed: fall back to local detection.
      return DetectionOutcome(
        result: _runLocal(input, inputType),
        source: DetectionSource.localFallback,
        fallbackReason: error.toString(),
      );
    }
  }

  Future<bool> _hasNetwork() async {
    try {
      final connectivityResults =
          await _connectivity.checkConnectivity();

      return connectivityResults.any(
        (result) => result != ConnectivityResult.none,
      );
    } catch (_) {
      // Try AI if connectivity status cannot be determined.
      // Failed requests will fall back to local detection.
      return true;
    }
  }

  RiskResult _runLocal(
    String input,
    String inputType,
  ) {
    switch (inputType) {
      case 'url':
        return _localDetector.checkUrl(input);

      case 'upi':
        return _localDetector.checkUpi(input);

      default:
        return _localDetector.checkMessage(input);
    }
  }

  void dispose() {
    _aiDetector.dispose();
  }
}