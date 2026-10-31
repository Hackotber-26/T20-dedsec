import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../detection_service.dart';

class ResultCard extends StatelessWidget {
  final RiskResult? result;
  final VoidCallback? onSpeak;
  final VoidCallback? onAnalyzeAgain;

  const ResultCard({
    super.key,
    required this.result,
    this.onSpeak,
    this.onAnalyzeAgain,
  });

  static const Color ink = Color(0xFF191614);
  static const Color muted = Color(0xFF7D777A);
  static const Color background = Color(0xFFF6F5F3);

  Color get riskColor {
    if (result == null) return muted;

    switch (result!.level) {
      case RiskLevel.green:
        return const Color(0xFF21865B);
      case RiskLevel.yellow:
        return const Color(0xFFC28A24);
      case RiskLevel.red:
        return const Color(0xFFD94B4B);
    }
  }

  String get riskLabel {
    if (result == null) return 'NO RESULT';

    switch (result!.level) {
      case RiskLevel.green:
        return 'LOW RISK';
      case RiskLevel.yellow:
        return 'SUSPICIOUS';
      case RiskLevel.red:
        return 'HIGH RISK';
    }
  }

  IconData get riskIcon {
    if (result == null) return Icons.shield_outlined;

    switch (result!.level) {
      case RiskLevel.green:
        return Icons.verified_user_outlined;
      case RiskLevel.yellow:
        return Icons.warning_amber_rounded;
      case RiskLevel.red:
        return Icons.gpp_bad_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return _buildEmptyState();
    }

    return _buildResult(context);
  }

  Widget _buildEmptyState() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 20),
        child: Column(
          children: [
            Container(
              height: 65,
              width: 65,
              decoration: const BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 30, color: muted),
            ),
            const SizedBox(height: 16),
            const Text(
              'No analysis yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Your detection report will appear here after analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final data = result!;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 22),

          // Risk score section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: riskColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(riskIcon, color: riskColor, size: 21),
                    const SizedBox(width: 9),
                    Text(
                      riskLabel,
                      style: TextStyle(
                        color: riskColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data.score}',
                      style: TextStyle(
                        fontSize: 48,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: riskColor,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 7, bottom: 5),
                      child: Text(
                        '/ 100 risk score',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (data.score / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white,
                    valueColor: AlwaysStoppedAnimation(riskColor),
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  data.verdict,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  data.summary,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Detection reasons
          const Text(
            'DETECTION INSIGHTS',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 14),

          if (data.reasons.isEmpty)
            const Text(
              'No specific warning indicators were detected.',
              style: TextStyle(color: muted, fontSize: 12),
            )
          else
            ...data.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: riskColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 15),

          // Listen button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSpeak,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Listen to analysis'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                side: const BorderSide(color: Color(0xFFE7E4E5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Copy report
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _copyReport(context, data);
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: muted,
                side: const BorderSide(color: Color(0xFFE7E4E5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          if (onAnalyzeAgain != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onAnalyzeAgain,
                child: const Text('Analyze another input'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.analytics_outlined, color: ink),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analysis result',
                style: TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Your detection report',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E4E5)),
      ),
      child: child,
    );
  }

  void _copyReport(BuildContext context, RiskResult data) {
    final report =
        '''
PEHCHAAN - SCAM ANALYSIS REPORT

Verdict: ${data.verdict}
Risk Level: $riskLabel
Risk Score: ${data.score}/100

Summary:
${data.summary}

Detection Insights:
${data.reasons.map((e) => '- $e').join('\n')}

Note: This is an automated heuristic assessment, not a guarantee that content is safe or fraudulent.
''';

    Clipboard.setData(ClipboardData(text: report));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
