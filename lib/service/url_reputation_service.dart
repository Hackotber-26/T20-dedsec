import 'dart:convert';
import 'package:http/http.dart' as http;

class UrlReputationResult {
  const UrlReputationResult({
    required this.domain,
    required this.score,
    required this.signals,
    required this.rdapStatus,
    required this.cached,
  });

  final String domain;
  final int score;
  final List<String> signals;
  final String rdapStatus;
  final bool cached;
}

class UrlReputationService {
  UrlReputationService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ??
                const String.fromEnvironment('PEHCHAAN_API_URL', defaultValue: ''))
            .trim()
            .replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<UrlReputationResult> lookup(String url) async {
    if (_baseUrl.isEmpty) throw Exception('Backend URL is not configured.');
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/v1/url/reputation'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 9));

    if (response.statusCode != 200) {
      throw Exception('URL reputation lookup failed: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid URL reputation response.');
    }
    final rawScore = decoded['reputationScore'];
    final rawSignals = decoded['signals'];
    return UrlReputationResult(
      domain: decoded['domain'] is String ? decoded['domain'] as String : '',
      score: rawScore is num ? rawScore.round().clamp(0, 40).toInt() : 0,
      signals: rawSignals is List
          ? rawSignals
              .whereType<Map>()
              .map((item) => item['detail'])
              .whereType<String>()
              .toList()
          : const [],
      rdapStatus: decoded['rdapStatus'] is String
          ? decoded['rdapStatus'] as String
          : 'unavailable',
      cached: decoded['cached'] == true,
    );
  }

  void dispose() => _client.close();
}
