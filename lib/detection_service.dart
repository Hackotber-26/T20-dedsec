import 'dart:math' as math;

import 'package:pehchaan/widgets/result_card.dart';

enum RiskLevel { green, yellow, red }

class RiskResult {
  final int score;
  final RiskLevel level;
  final List<String> reasons;
  final String summary;
  final String inputType;

  const RiskResult({
    required this.score,
    required this.level,
    required this.reasons,
    required this.summary,
    required this.inputType,
  });

  String get verdict {
    switch (level) {
      case RiskLevel.green:
        return 'LOW RISK';
      case RiskLevel.yellow:
        return 'CAUTION';
      case RiskLevel.red:
        return 'HIGH RISK';
    }
  }

  String get color {
    switch (level) {
      case RiskLevel.green:
        return 'green';
      case RiskLevel.yellow:
        return 'yellow';
      case RiskLevel.red:
        return 'red';
    }
  }

  @override
  String toString() {
    return 'RiskResult(score: $score, '
        'level: $level, reasons: $reasons)';
  }
}

class UpiDetails {
  final String? payeeAddress;
  final String? payeeName;
  final String? amount;
  final String? currency;
  final String? transactionNote;
  final bool isPaymentRequest;

  const UpiDetails({
    this.payeeAddress,
    this.payeeName,
    this.amount,
    this.currency,
    this.transactionNote,
    required this.isPaymentRequest,
  });
}

class DetectionService {
  DetectionService._();

  static final DetectionService instance = DetectionService._();

  static const int yellowThreshold = 25;
  static const int redThreshold = 60;

  static const int maxReasons = 3;

  static const Set<String> shorteners = {
    'bit.ly',
    'tinyurl.com',
    't.co',
    'is.gd',
    'cutt.ly',
    'shorturl.at',
    'rb.gy',
    'rebrand.ly',
    'ow.ly',
    'buff.ly',
  };

  static const Map<String, String> trustedDomains = {
    'sbi': 'sbi.co.in',
    'hdfc': 'hdfcbank.com',
    'icici': 'icicibank.com',
    'axis': 'axisbank.com',
    'paytm': 'paytm.com',
    'google': 'google.com',
    'amazon': 'amazon.in',
  };

  RiskResult _buildResult({
    required String inputType,
    required int score,
    required List<String> reasons,
    String? customSummary,
  }) {
    final safeScore = score.clamp(0, 100);

    final RiskLevel level;

    if (safeScore >= redThreshold) {
      level = RiskLevel.red;
    } else if (safeScore >= yellowThreshold) {
      level = RiskLevel.yellow;
    } else {
      level = RiskLevel.green;
    }

    return RiskResult(
      score: safeScore,
      level: level,
      reasons: reasons.take(maxReasons).toList(),
      summary: customSummary ?? _defaultSummary(level),
      inputType: inputType,
    );
  }

  String _defaultSummary(RiskLevel level) {
    switch (level) {
      case RiskLevel.green:
        return 'No strong warning signs were detected. '
            'Stay alert and verify before taking action.';

      case RiskLevel.yellow:
        return 'Some suspicious indicators were detected. '
            'Verify independently before proceeding.';

      case RiskLevel.red:
        return 'Multiple or serious warning signs were '
            'detected. Do not share sensitive information '
            'or proceed without independent verification.';
    }
  }

  RiskResult checkMessage(String input) {
    final text = input.trim().toLowerCase();

    if (text.isEmpty) {
      return _invalidResult('message');
    }

    int score = 0;
    final List<String> reasons = [];

    void addRule(int points, String reason) {
      score += points;
      reasons.add(reason);
    }

    final credentialRequest = RegExp(
      r'(share|send|provide|tell|enter|submit|reveal|'
      r'forward|give|verify|confirm).{0,50}'
      r'(otp|one.?time password|pin|password|'
      r'cvv|card number|security code)',
    );

    final credentialRequestReverse = RegExp(
      r'(otp|one.?time password|pin|password|'
      r'cvv|security code).{0,50}'
      r'(share|send|provide|tell|reveal|forward)',
    );

    if (credentialRequest.hasMatch(text) ||
        credentialRequestReverse.hasMatch(text)) {
      addRule(
        45,
        'The message appears to request sensitive '
        'credentials such as an OTP, PIN or password.',
      );
    }

    final urgencyPatterns = [
      RegExp(r'account.{0,30}(block|suspend|deactivat)'),
      RegExp(r'(immediately|urgent|right now|within \d+)'),
      RegExp(r'last warning'),
      RegExp(r'limited time'),
      RegExp(r'will be.{0,20}(blocked|closed|suspended)'),
      RegExp(r'account.{0,30}expir'),
    ];

    if (urgencyPatterns.any((p) => p.hasMatch(text))) {
      addRule(
        25,
        'The message uses urgency or threatens account '
        'suspension to pressure you.',
      );
    }

    final rewardPatterns = [
      RegExp(r'you have won'),
      RegExp(r'you won'),
      RegExp(r'congratulations.{0,40}(winner|prize|reward)'),
      RegExp(r'claim.{0,30}(reward|prize|cash|gift)'),
      RegExp(r'free.{0,20}(gift|money|iphone|prize)'),
      RegExp(r'lucky winner'),
    ];

    if (rewardPatterns.any((p) => p.hasMatch(text))) {
      addRule(
        20,
        'The message advertises an unexpected prize '
        'or reward.',
      );
    }

    final paymentPatterns = [
      RegExp(r'(pay|transfer).{0,40}(now|immediately)'),
      RegExp(r'avoid.{0,30}(penalty|suspension|fine)'),
      RegExp(r'payment.{0,30}(pending|failed|urgent)'),
      RegExp(r'send money'),
      RegExp(r'pay.{0,20}to.{0,20}(receive|unlock|claim)'),
    ];

    if (paymentPatterns.any((p) => p.hasMatch(text))) {
      addRule(
        25,
        'The message pressures you to make an urgent '
        'payment or transfer.',
      );
    }

    final impersonationPatterns = [
      RegExp(r'\b(bank|sbi|hdfc|icici|axis bank)\b'),
      RegExp(r'\b(rbi|income tax|government department)\b'),
      RegExp(r'\b(customer care|support team|kyc department)\b'),
      RegExp(r'\b(upi department|bank officer)\b'),
    ];

    if (impersonationPatterns.any((p) => p.hasMatch(text))) {
      addRule(
        15,
        'The message claims to represent a bank or '
        'trusted organisation. Verify its authenticity.',
      );
    }

    final containsUrl = RegExp(r'(https?:|www\.)\S+').hasMatch(text);

    if (containsUrl) {
      addRule(
        20,
        'The message contains a link. Check its destination '
        'independently before opening it.',
      );
    }

    if (reasons.isEmpty) {
      reasons.add(
        'No strong scam indicators were detected '
        'in this message.',
      );
    }

    return _buildResult(inputType: 'message', score: score, reasons: reasons);
  }

  RiskResult checkUrl(String input) {
    final raw = input.trim();

    if (raw.isEmpty) {
      return _invalidResult('url');
    }

    String normalized = raw;

    if (!normalized.contains(':')) {
      normalized = 'https:$normalized';
    }

    final uri = Uri.tryParse(normalized);

    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return _invalidResult('url');
    }

    final host = uri.host.toLowerCase();

    if (host.contains(' ') || host.startsWith('.') || host.endsWith('.')) {
      return _invalidResult('url');
    }

    int score = 0;
    final List<String> reasons = [];

    void addRule(int points, String reason) {
      score += points;
      reasons.add(reason);
    }

    if (uri.scheme.toLowerCase() == 'http') {
      addRule(
        10,
        'This URL uses HTTP instead of HTTPS. '
        'Its connection is not encrypted.',
      );
    }

    if (shorteners.contains(host)) {
      addRule(
        20,
        'This URL uses a link-shortening service. '
        'Its final destination is hidden.',
      );
    }

    final isIpv4 = RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$').hasMatch(host);

    final isIpv6 = host.contains(':');

    if (isIpv4 || isIpv6) {
      addRule(
        25,
        'This URL uses an IP address instead of '
        'a recognizable domain name.',
      );
    }

    if (uri.userInfo.isNotEmpty) {
      addRule(
        35,
        'This URL contains user-information fields '
        'that can disguise its actual destination.',
      );
    }

    if (host.contains('xn--')) {
      addRule(
        30,
        'This domain uses internationalized encoding. '
        'Check for possible lookalike characters.',
      );
    }

    final suspiciousWords = [
      'login',
      'verify',
      'secure',
      'update',
      'account',
      'kyc',
      'banking',
      'wallet',
    ];

    final hasBrandKeyword = trustedDomains.keys.any(
      (brand) => host.contains(brand),
    );

    final hasSuspiciousWord = suspiciousWords.any(
      (word) => host.contains(word),
    );

    if (hasBrandKeyword && hasSuspiciousWord && !_isTrustedHost(host)) {
      addRule(
        20,
        'The hostname combines a trusted brand name '
        'with suspicious account or login terminology.',
      );
    }

    for (final entry in trustedDomains.entries) {
      final brand = entry.key;
      final officialDomain = entry.value;

      if (_isTrustedHost(host)) {
        break;
      }

      final labels = host.split('.');
      final similarity = _similarity(labels.first, brand);

      final hasBrandText = host.contains(brand);

      if (similarity >= 0.70 ||
          (hasBrandText &&
              host != officialDomain &&
              !host.endsWith('.$officialDomain'))) {
        addRule(
          35,
          'This domain may imitate $brand. '
          'Verify the official website independently.',
        );
        break;
      }
    }

    final suspiciousPath = RegExp(
      r'(verify-account|confirm-otp|'
      r'bank-login|update-kyc|free-reward)',
      caseSensitive: false,
    );

    if (suspiciousPath.hasMatch('${uri.path}?${uri.query}')) {
      addRule(
        15,
        'The URL contains suspicious login, verification '
        'or reward-related patterns.',
      );
    }

    if (reasons.isEmpty) {
      reasons.add(
        'No strong URL warning signs were detected. '
        'This does not guarantee that the website is safe.',
      );
    }

    return _buildResult(inputType: 'url', score: score, reasons: reasons);
  }

  RiskResult checkUpi(String input) {
    final payload = input.trim();

    if (payload.isEmpty) {
      return _invalidResult('upi');
    }

    final uri = Uri.tryParse(payload);

    if (uri == null) {
      return _invalidResult('upi');
    }

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    if (scheme != 'upi' || host != 'pay') {
      return _buildResult(
        inputType: 'upi',
        score: 0,
        reasons: [
          'This QR code does not contain a recognized '
              'UPI payment URI.',
          'Its contents could not be verified by '
              'the UPI payment analyzer.',
        ],
        customSummary:
            'Unknown QR content. Do not open unfamiliar '
            'links or follow payment instructions.',
      );
    }

    final params = uri.queryParameters;

    final payee = params['pa'];
    final name = params['pn'];
    final amount = params['am'];
    final currency = params['cu'];
    final note = params['tn'];

    final details = UpiDetails(
      payeeAddress: payee,
      payeeName: name,
      amount: amount,
      currency: currency,
      transactionNote: note,
      isPaymentRequest: true,
    );

    int score = 0;
    final List<String> reasons = [];

    void addRule(int points, String reason) {
      score += points;
      reasons.add(reason);
    }

    if (payee == null || payee.trim().isEmpty) {
      addRule(35, 'The UPI payment URI does not contain a payee address.');
    } else {
      final validVpa = RegExp(r'^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+$')
          .hasMatch(payee);

      if (!validVpa) {
        addRule(25, 'The UPI payee address has an unexpected format.');
      } else {
        reasons.add('This QR code contains a payment recipient: $payee.');
      }
    }

    if (amount != null) {
      final parsedAmount = double.tryParse(amount);

      if (parsedAmount == null || !parsedAmount.isFinite || parsedAmount <= 0) {
        addRule(30, 'The payment amount is invalid or unexpected.');
      } else if (parsedAmount >= 10000) {
        addRule(
          15,
          'This QR code requests a relatively large '
          'payment of $amount.',
        );
      } else {
        reasons.add(
          'Payment amount requested: $amount '
          '${currency ?? "currency unspecified"}.',
        );
      }
    } else {
      reasons.add('The QR code does not specify a fixed payment amount.');
    }

    if (currency != null && currency.toUpperCase() != 'INR') {
      addRule(20, 'The QR code specifies an unexpected currency.');
    }

    if (note != null) {
      final lowerNote = note.toLowerCase();

      final suspiciousNotes = [
        'otp',
        'pin',
        'password',
        'receive money',
        'cashback',
        'reward',
        'prize',
      ];

      if (suspiciousNotes.any((word) => lowerNote.contains(word))) {
        addRule(
          25,
          'The payment note contains language associated '
          'with suspicious payment instructions.',
        );
      }
    }

    if (reasons.isEmpty) {
      reasons.add('A UPI payment request was identified.');
    }

    return _buildResult(
      inputType: 'upi',
      score: score,
      reasons: reasons,
      customSummary:
          'This QR code contains a UPI payment request. '
          'Verify the recipient and amount before '
          'authorizing any payment.',
    );
  }

  UpiDetails? extractUpiDetails(String payload) {
    final uri = Uri.tryParse(payload.trim());

    if (uri == null ||
        uri.scheme.toLowerCase() != 'upi' ||
        uri.host.toLowerCase() != 'pay') {
      return null;
    }

    final params = uri.queryParameters;

    return UpiDetails(
      payeeAddress: params['pa'],
      payeeName: params['pn'],
      amount: params['am'],
      currency: params['cu'],
      transactionNote: params['tn'],
      isPaymentRequest: true,
    );
  }

  bool _isTrustedHost(String host) {
    return trustedDomains.values.any(
      (domain) => host == domain || host.endsWith('.$domain'),
    );
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final distance = _levenshtein(a, b);

    final maxLength = math.max(a.length, b.length);

    return 1.0 - distance / maxLength;
  }

  int _levenshtein(String a, String b) {
    final rows = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      rows[i][0] = i;
    }

    for (int j = 0; j <= b.length; j++) {
      rows[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        rows[i][j] = math.min(
          math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1),
          rows[i - 1][j - 1] + cost,
        );
      }
    }

    return rows[a.length][b.length];
  }

  RiskResult _invalidResult(String inputType) {
    return RiskResult(
      score: 0,
      level: RiskLevel.green,
      reasons: [
        'Invalid or empty input. Please check the '
            'provided content and try again.',
      ],
      summary: 'Unable to analyze this input.',
      inputType: inputType,
    );
  }
}
