import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pehchaan/service/detection_service.dart';

class AiDetectionService {
  AiDetectionService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'PEHCHAAN_API_URL',
                  defaultValue: '',
                ))
            .trim()
            .replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<RiskResult> analyze({
    required String input,
    required String inputType,
  }) async {
    if (!isConfigured) {
      throw Exception('AI backend URL is not configured.');
    }

    final trimmedInput = input.trim();

    if (trimmedInput.isEmpty) {
      throw Exception('Input cannot be empty.');
    }

    if (trimmedInput.length > 12000) {
      throw Exception('Input is too long.');
    }

    final uri = Uri.parse('$_baseUrl/v1/analyze');

    final response = await _client
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'input': trimmedInput,
            'inputType': inputType,
            'language': 'auto',
            'app': 'pehchaan',
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception(
        'AI backend error: HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid AI response.');
    }

    final rawScore = decoded['score'];

    if (rawScore is! num || rawScore is bool) {
      throw Exception('Invalid AI risk score.');
    }

    final score = rawScore.round().clamp(0, 100).toInt();

    final rawReasons = decoded['reasons'];

    final reasons = rawReasons is List
        ? rawReasons
            .whereType<String>()
            .map((reason) => reason.trim())
            .where((reason) => reason.isNotEmpty)
            .take(3)
            .toList()
        : <String>[];

    final summary = decoded['summary'];

    final RiskLevel level;

    if (score >= DetectionService.redThreshold) {
      level = RiskLevel.red;
    } else if (score >= DetectionService.yellowThreshold) {
      level = RiskLevel.yellow;
    } else {
      level = RiskLevel.green;
    }

    return RiskResult(
      score: score,
      level: level,
      reasons: reasons,
      summary: summary is String && summary.trim().isNotEmpty
          ? summary.trim()
          : 'AI analysis completed. Verify independently before taking action.',
      inputType: inputType,
    );
  }

  void dispose() {
    _client.close();
  }
}