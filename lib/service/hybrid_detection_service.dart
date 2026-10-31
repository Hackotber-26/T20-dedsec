import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pehchaan/service/detection_service.dart';

import 'ai_detection_service.dart';
import 'url_reputation_service.dart';

enum DetectionSource { ai, offline, localFallback, urlEnriched }

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
        return 'AI + Local Analysis';
      case DetectionSource.offline:
        return 'Offline Protection';
      case DetectionSource.localFallback:
        return 'Local Fallback';
      case DetectionSource.urlEnriched:
        return 'URL Reputation + Hybrid Analysis';
    }
  }
}

class HybridDetectionService {
  HybridDetectionService({
    DetectionService? localDetector,
    AiDetectionService? aiDetector,
    UrlReputationService? urlReputationService,
    Connectivity? connectivity,
  })  : _localDetector = localDetector ?? DetectionService.instance,
        _aiDetector = aiDetector ?? AiDetectionService(),
        _urlReputation = urlReputationService ?? UrlReputationService(),
        _connectivity = connectivity ?? Connectivity();

  final DetectionService _localDetector;
  final AiDetectionService _aiDetector;
  final UrlReputationService _urlReputation;
  final Connectivity _connectivity;

  Future<DetectionOutcome> analyzeMessage(String input) =>
      _analyze(input: input, inputType: 'message');

  Future<DetectionOutcome> analyzeUpi(String input) =>
      _analyze(input: input, inputType: 'upi');

  Future<DetectionOutcome> analyzeUrl(String input) async {
    final local = _localDetector.checkUrl(input);
    if (input.trim().isEmpty) {
      return DetectionOutcome(result: local, source: DetectionSource.offline);
    }

    if (!await _hasNetwork()) {
      return DetectionOutcome(result: local, source: DetectionSource.offline);
    }

    // Run AI and reputation enrichment concurrently. Either can fail without
    // preventing the other result or the deterministic local detector.
    Future<RiskResult?> runAi() async {
      try {
        return await _aiDetector.analyze(input: input, inputType: 'url');
      } catch (_) {
        return null;
      }
    }

    Future<UrlReputationResult?> runReputation() async {
      try {
        return await _urlReputation.lookup(input);
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait<Object?>([runAi(), runReputation()]);
    final aiResult = results[0] as RiskResult?;
    final reputation = results[1] as UrlReputationResult?;

    if (aiResult == null && reputation == null) {
      return DetectionOutcome(
        result: local,
        source: DetectionSource.localFallback,
        fallbackReason: 'AI and URL reputation services were unavailable.',
      );
    }

    final merged = _mergeUrlResults(
      local: local,
      ai: aiResult,
      reputation: reputation,
    );

    return DetectionOutcome(
      result: merged,
      source: reputation != null
          ? DetectionSource.urlEnriched
          : DetectionSource.ai,
      fallbackReason: aiResult == null
          ? 'AI analysis was unavailable; local and available reputation signals were used.'
          : null,
    );
  }

  Future<DetectionOutcome> _analyze({
    required String input,
    required String inputType,
  }) async {
    final local = _runLocal(input, inputType);
    if (input.trim().isEmpty) {
      return DetectionOutcome(result: local, source: DetectionSource.offline);
    }
    if (!await _hasNetwork()) {
      return DetectionOutcome(result: local, source: DetectionSource.offline);
    }
    try {
      final ai = await _aiDetector.analyze(input: input, inputType: inputType);
      return DetectionOutcome(
        result: _mergeBasicResults(local, ai),
        source: DetectionSource.ai,
      );
    } catch (error) {
      return DetectionOutcome(
        result: local,
        source: DetectionSource.localFallback,
        fallbackReason: error.toString(),
      );
    }
  }

  RiskResult _mergeUrlResults({
    required RiskResult local,
    required RiskResult? ai,
    required UrlReputationResult? reputation,
  }) {
    // Local/AI scores are the base. Registration/DNS reputation is deliberately
    // a bounded modifier because domain age alone is weak evidence.
    final baseScore = math.max(local.score, ai?.score ?? 0);
    final reputationBonus = reputation == null
        ? 0
        : math.min(12, (reputation.score * 0.30).round());
    final score = (baseScore + reputationBonus).clamp(0, 100).toInt();

    final reasons = <String>[];
    for (final reason in local.reasons) {
      if (!reasons.contains(reason)) reasons.add(reason);
    }
    if (ai != null) {
      for (final reason in ai.reasons) {
        if (!reasons.contains(reason)) reasons.add(reason);
      }
    }
    if (reputation != null) {
      for (final reason in reputation.signals) {
        if (!reasons.contains(reason)) reasons.add(reason);
      }
    }

    final level = score >= DetectionService.redThreshold
        ? RiskLevel.red
        : score >= DetectionService.yellowThreshold
            ? RiskLevel.yellow
            : RiskLevel.green;

    final summary = score >= DetectionService.redThreshold
        ? 'Strong warning signs were detected. Do not enter credentials or payment details.'
        : score >= DetectionService.yellowThreshold
            ? 'Some warning signs were detected. Verify the domain independently before proceeding.'
            : 'No strong warning signs were detected by the available checks. This is not proof that the website is safe.';

    return RiskResult(
      score: score,
      level: level,
      reasons: reasons.take(DetectionService.maxReasons).toList(),
      summary: summary,
      inputType: 'url',
    );
  }

  RiskResult _mergeBasicResults(RiskResult local, RiskResult ai) {
    final score = math.max(local.score, ai.score).clamp(0, 100).toInt();
    final level = score >= DetectionService.redThreshold
        ? RiskLevel.red
        : score >= DetectionService.yellowThreshold
            ? RiskLevel.yellow
            : RiskLevel.green;
    final reasons = <String>[];
    for (final reason in [...local.reasons, ...ai.reasons]) {
      if (!reasons.contains(reason)) reasons.add(reason);
    }
    return RiskResult(
      score: score,
      level: level,
      reasons: reasons.take(DetectionService.maxReasons).toList(),
      summary: ai.summary,
      inputType: local.inputType,
    );
  }

  Future<bool> _hasNetwork() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      // Connectivity status is only a hint; actual request failures still
      // fall back to the local detector.
      return true;
    }
  }

  RiskResult _runLocal(String input, String inputType) {
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
    _urlReputation.dispose();
  }
}
