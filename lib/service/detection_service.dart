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
    final text = input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    if (text.isEmpty) {
      return _invalidResult('message');
    }

    int score = 0;
    final List<String> reasons = [];

    // Each category is scored at most once. This prevents repeated words
    // from artificially inflating the risk score.
    void addRule(int points, String reason) {
      score += points;
      reasons.add(reason);
    }

    bool matchesAny(List<String> patterns) {
      return patterns.any((pattern) => RegExp(
            pattern,
            caseSensitive: false,
          ).hasMatch(text));
    }

    final hasUrl = RegExp(
      r'(https?://|www\.)\S+',
      caseSensitive: false,
    ).hasMatch(text);

    final asksForSecret = matchesAny([
      r'\b(share|send|provide|tell|enter|submit|reveal|forward|give|'
          r' disclose|type|reply with|confirm|verify)\b.{0,65}'
          r'\b(otp|one.?time password|verification code|pin|upi pin|'
          r'password|passcode|cvv|cvc|card number|security code)\b',
      r'\b(otp|one.?time password|verification code|upi pin|pin|'
          r'password|passcode|cvv|cvc|card number|security code)\b'
          r'.{0,65}\b(share|send|provide|tell|reveal|forward|give|'
          r'disclose|reply with)\b',
      r'\b(keep|have)\b.{0,25}\b(otp|pin|password|cvv)\b.{0,25}'
          r'\b(ready|available)\b',
    ]);

    final credentialMention = matchesAny([
      r'\b(otp|one.?time password|verification code|upi pin|'
          r'cvv|cvc|internet banking password)\b',
    ]);

    if (asksForSecret) {
      addRule(
        65,
        'The message asks you to share or enter sensitive credentials '
        'such as an OTP, UPI PIN, CVV or password. Never share these.',
      );
    } else if (credentialMention && matchesAny([
      r'\b(do not|never|dont|dont|not)\b.{0,25}'
          r'\b(share|tell|reveal|disclose)\b',
      r'\b(if you did not|if this was not)\b',
    ])) {
      // Security advice and defensive warnings should not be treated as
      // credential theft requests.
    }

    final upiCollectScam = matchesAny([
      r'\b(approve|accept|authorise|authorize)\b.{0,55}'
          r'\b(collect request|payment request|upi request)\b',
      r'\b(collect request|payment request)\b.{0,55}'
          r'\b(receive|get|claim)\b.{0,30}\b(refund|money|cashback)\b',
      r'\b(to receive|get|claim)\b.{0,35}\b(refund|money|cashback)\b'
          r'.{0,45}\b(approve|accept|enter pin|upi pin)\b',
      r'\b(scan|open)\b.{0,30}\b(qr)\b.{0,45}'
          r'\b(receive|get|claim)\b.{0,25}\b(money|refund)\b',
    ]);

    if (upiCollectScam) {
      addRule(
        60,
        'The message may be disguising a UPI collect request as a refund '
        'or incoming payment. Receiving money does not require entering '
        'your UPI PIN.',
      );
    }

    final jobOffer = matchesAny([
      r'\b(work from home|work.?from.?home|part.?time job|'
          r'data entry|typing job|online job|job opportunity|'
          r'internship|joining letter|shortlisted for)\b',
    ]);

    final jobFee = matchesAny([
      r'\b(registration|onboarding|verification|processing|'
          r'security|training|document)\s+(fee|charge|payment)\b',
      r'\b(pay|payment|deposit|transfer)\b.{0,45}'
          r'\b(job|internship|joining|interview|training|position)\b',
      r'\b(refundable|refundable fee)\b.{0,35}\b(fee|deposit|charge)\b',
      r'\b(fee|deposit|charge)\b.{0,35}\b(refundable)\b',
    ]);

    if (jobOffer && jobFee) {
      addRule(
        55,
        'The job or internship offer asks for an upfront fee. '
        'Legitimate employers generally do not require payment to secure a job.',
      );
    } else if (jobOffer && matchesAny([
      r'\b(no experience|required|earn|per day|daily income|'
          r'limited slots|easy money|guaranteed selection)\b',
    ])) {
      addRule(
        20,
        'The unsolicited job offer makes unusually easy or attractive '
        'earning claims. Verify the employer and vacancy independently.',
      );
    }

    final investmentOffer = matchesAny([
      r'\b(guaranteed|assured|fixed)\b.{0,35}'
          r'\b(returns|profit|income|double|triple)\b',
      r'\b(double|triple|3x)\b.{0,25}\b(your money|investment|capital)\b',
      r'\b(invest|investment|trading)\b.{0,65}'
          r'\b(guaranteed|assured|risk.?free|daily profit|'
          r'95% accuracy|sure shot)\b',
      r'\b(95% accuracy|100% profit|risk.?free returns|'
          r'money back guaranteed)\b',
    ]);

    if (investmentOffer) {
      addRule(
        50,
        'The message promises unusually high, guaranteed or risk-free '
        'investment returns. Such claims are a common investment-scam warning sign.',
      );
    }

    final urgency = matchesAny([
      r'\b(immediately|urgent|right now|within\s+\d+\s*(hours?|minutes?|days?)|'
          r'last warning|final warning|act now|today only|expires tonight)\b',
      r'\b(account|connection|service|card)\b.{0,35}'
          r'\b(blocked|blocked today|suspended|deactivated|closed|disconnected)\b',
      r'\b(will be|scheduled for)\b.{0,25}'
          r'\b(blocked|suspended|closed|disconnected|terminated)\b',
      r'\b(avoid|prevent)\b.{0,30}\b(disconnection|suspension|closure|block|penalty)\b',
    ]);

    final threatOrDeadline = matchesAny([
      r'\b(permanent|legal action|police case|arrest|fine|penalty)\b',
      r'\b(lose access|account access will|connection will)\b',
    ]);

    if (urgency && (threatOrDeadline || hasUrl ||
        matchesAny([r'\b(pay|kyc|verify|update|call|contact|click)\b']))) {
      addRule(
        35,
        'The message uses urgency, a threat or a short deadline to pressure '
        'you into acting before verifying the request.',
      );
    }

    final kycOrAccountAction = matchesAny([
      r'\b(kyc|know your customer)\b',
      r'\b(account|bank account|debit card|credit card)\b.{0,35}'
          r'\b(expir|restrict|block|suspend|update|reactivat)\w*\b',
      r'\b(update|complete|verify|reactivate)\b.{0,35}'
          r'\b(kyc|bank account|card details|account)\b',
    ]);

    if (kycOrAccountAction && (hasUrl || asksForSecret ||
        matchesAny([r'\b(call|pay|click|submit|update immediately)\b']))) {
      addRule(
        40,
        'The message combines a banking or KYC-related request with a link, '
        'payment or sensitive-information action. Use your bank’s official app '
        'or independently verified contact details.',
      );
    }

    final paymentPressure = matchesAny([
      r'\b(pay|transfer|send)\b.{0,45}\b(now|immediately|today|urgent)\b',
      r'\b(payment|amount|fee|charge)\b.{0,40}'
          r'\b(pending|failed|overdue|clearance|verification)\b',
      r'\b(pay|payment)\b.{0,35}\b(to receive|to unlock|to release|'
          r'to claim|to avoid)\b',
      r'\b(send money|make a payment|advance payment|pay in advance)\b',
    ]);

    final suspiciousPaymentPurpose = matchesAny([
      r'\b(customs|clearance|parcel release|delivery release|'
          r'account verification|refund processing|prize claim)\b',
      r'\b(release|unlock|receive|claim)\b.{0,35}'
          r'\b(parcel|shipment|loan|refund|reward|prize|scholarship)\b',
    ]);

    if (paymentPressure && suspiciousPaymentPurpose && !jobFee) {
      addRule(
        40,
        'The message requests payment to release, verify or receive something. '
        'Verify the charge through the organisation’s official channel.',
      );
    } else if (paymentPressure && !jobFee && !upiCollectScam) {
      addRule(
        18,
        'The message asks for a payment or transfer. Confirm the recipient '
        'and reason independently before paying.',
      );
    }

    final impersonation = matchesAny([
      r'\b(sbi|state bank of india|hdfc|icici|axis bank|'
          r'kotak|canara bank|bank of baroda|pnb|rbi|npci|'
          r'paytm|phonepe|google pay|gpay|amazon|paypal|'
          r'bescom|electricity board|customs department|income tax)\b',
      r'\b(customer care|customer support|support executive|'
          r'bank officer|kyc department|verification team)\b',
    ]);

    final impersonationAction = matchesAny([
      r'\b(click|open|visit|reply|call|contact|pay|verify|'
          r'update|share|submit|send|approve)\b',
    ]);

    if (impersonation && impersonationAction &&
        (hasUrl || urgency || asksForSecret || paymentPressure ||
            kycOrAccountAction)) {
      addRule(
        25,
        'The sender appears to invoke a trusted organisation or support team '
        'while asking you to take a sensitive action. Verify using its official '
        'app or published contact details.',
      );
    }

    final deliveryScam = matchesAny([
      r'\b(parcel|shipment|package|customs|courier|delivery)\b',
    ]) && matchesAny([
      r'\b(address incomplete|confirm your address|address verification|'
          r'customs fee|clearance charge|redelivery fee|held at customs|'
          r'pay.*delivery|delivery.*payment)\b',
    ]);

    if (deliveryScam && (hasUrl || paymentPressure ||
        matchesAny([r'\b(mobile number|personal details|pay|fee|charge)\b']))) {
      addRule(
        35,
        'The delivery message asks for extra payment or personal details '
        'to release a parcel. Check tracking directly with the courier.',
      );
    }

    final prizeScam = matchesAny([
      r'\b(you have won|you won|lucky winner|selected as a winner|'
          r'congratulations)\b',
      r'\b(free gift|cashback reward|exclusive reward|prize money|'
          r'lottery|giveaway|free iphone)\b',
    ]);

    if (prizeScam && (hasUrl || paymentPressure || asksForSecret ||
        matchesAny([r'\b(claim|activate|redeem|fee|winner)\b']))) {
      addRule(
        35,
        'The message offers an unexpected prize, gift or reward and asks '
        'you to claim or activate it. Be wary of advance fees and credential requests.',
      );
    }

    final socialAccountScam = matchesAny([
      r'\b(instagram|facebook|whatsapp|telegram|social media)\b',
    ]) && matchesAny([
      r'\b(appeal|verification|reported|impersonation|copyright|'
          r'permanent restriction|account disabled|account suspended)\b',
    ]);

    if (socialAccountScam && (hasUrl || urgency ||
        matchesAny([r'\b(login|password|verify|submit|appeal now)\b']))) {
      addRule(
        35,
        'The message uses a social-media account warning or appeal to prompt '
        'verification. Open the platform directly instead of following message links.',
      );
    }

    final unsolicitedContact = matchesAny([
      r'\b(dm me|message me|contact me|whatsapp me|telegram me)\b',
    ]);

    final bulkPromotion = matchesAny([
      r'\b(limited slots|limited stock|first \d+ members|'
          r'no experience required|earn rs\.?|earn ₹|'
          r'work only \d+ hours|easy income|daily income)\b',
    ]);

    if (bulkPromotion && unsolicitedContact && !investmentOffer && !jobFee) {
      addRule(
        15,
        'The message resembles an unsolicited bulk promotion with an '
        'unverified offer or call to action.',
      );
    }

    final secrecyOrRemoteAccess = matchesAny([
      r'\b(install anydesk|teamviewer|remote access|screen sharing)\b',
      r'\b(don.t tell anyone|keep this confidential|secret transaction)\b',
    ]);

    if (secrecyOrRemoteAccess) {
      addRule(
        40,
        'The message requests secrecy or remote access, which can be used '
        'to take control of a device or account.',
      );
    }

    if (hasUrl && (urgency || asksForSecret || kycOrAccountAction ||
        prizeScam || socialAccountScam || deliveryScam)) {
      addRule(
        25,
        'The message combines a link with a suspicious request. Do not open '
        'it until you independently verify the destination.',
      );
    } else if (hasUrl) {
      // A link alone is not proof of a scam.
      reasons.add(
        'The message contains a link. Check its destination before opening it.',
      );
    }

    // Benign transactional and institutional language is deliberately not
    // penalized by itself. It is only a weak contextual signal when no
    // stronger suspicious behavior was found.
    final benignNotification = matchesAny([
      r'\b(payment successful|transaction successful|has been debited|'
          r'has been credited|order has been shipped|expected delivery|'
          r'examination|internal assessment|classroom|interview invitation|'
          r'please confirm your availability|bill is now available|'
          r'due date|registration details|fest is happening)\b',
    ]);

    if (score == 0 && benignNotification) {
      reasons
        ..clear()
        ..add(
          'The message resembles a routine notification or announcement. '
          'This is not proof that the sender is genuine.',
        );
    }

    if (reasons.isEmpty) {
      reasons.add(
        'No strong scam or spam indicators were detected. '
        'This does not prove the sender or message is legitimate.',
      );
    }

    return _buildResult(
      inputType: 'message',
      score: score,
      reasons: reasons,
    );
  }

  RiskResult checkUrl(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return _invalidResult('url');

    // Accept bare domains, but do not mistake a port (example.com:8080)
    // for a URI scheme.
    final normalized = raw.startsWith('//')
        ? 'https:$raw'
        : (raw.contains('://') ? raw : 'https://$raw');
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return _invalidResult('url');
    }

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (host.isEmpty || host.contains(' ') || host.startsWith('.') ||
        host.endsWith('.') || host.length > 253) {
      return _invalidResult('url');
    }

    final reasons = <String>[];
    var brandRisk = 0;
    var structureRisk = 0;
    var contentRisk = 0;
    var domainRisk = 0;

    void addReason(String reason) {
      if (!reasons.contains(reason)) reasons.add(reason);
    }

    final isIpv4 = RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$').hasMatch(host);
    final isIpv6 = host.contains(':');
    final labels = host.split('.');
    final registrable = _registrableDomain(host);
    final registrableLabel = registrable.split('.').first;

    // 1. Domain/brand impersonation. Only compare meaningful labels against
    // actual official registrable domains, not short brand aliases.
    for (final entry in trustedDomains.entries) {
      final brand = entry.key;
      final officialDomain = entry.value;
      final officialLabel = _registrableDomain(officialDomain).split('.').first;
      final isOfficial = host == officialDomain || host.endsWith('.$officialDomain');
      if (isOfficial) continue;

      final normalizedBrand = _normaliseConfusables(officialLabel);
      final candidateLabels = labels.where((label) => label.isNotEmpty).toList();
      for (final label in candidateLabels) {
        final normalizedLabel = _normaliseConfusables(label);
        final similarity = _similarity(normalizedLabel, normalizedBrand);
        final exactBrandMention = normalizedLabel == _normaliseConfusables(brand) ||
            normalizedLabel == normalizedBrand ||
            normalizedLabel.contains(normalizedBrand);
        final threshold = normalizedBrand.length <= 4 ? 0.86 : 0.76;
        if (exactBrandMention ||
            (normalizedLabel.length >= 4 && similarity >= threshold)) {
          brandRisk = math.max(brandRisk, 38).toInt();
          addReason('The hostname resembles or mentions $brand but is not its official domain ($officialDomain).');
          break;
        }
      }
    }

    // 2. Hostname structure and obfuscation.
    if (uri.userInfo.isNotEmpty) {
      structureRisk += 30;
      addReason('The URL contains user-information before the hostname, which can disguise its real destination.');
    }
    if (isIpv4 || isIpv6) {
      structureRisk += 25;
      addReason('The URL uses an IP address instead of a normal domain name.');
    }
    if (host.contains('xn--')) {
      structureRisk += 18;
      addReason('The domain contains punycode-encoded labels; inspect for international-character lookalikes.');
    }
    final unicodeHost = host.runes.any((r) => r > 127);
    if (unicodeHost) {
      structureRisk += 12;
      addReason('The domain contains non-ASCII characters that may visually resemble other letters.');
    }
    if (labels.length >= 5) {
      structureRisk += 10;
      addReason('The hostname has many subdomain levels, which can make its actual owner harder to identify.');
    }
    if (host.length > 45) {
      structureRisk += 8;
      addReason('The hostname is unusually long.');
    }
    if (shorteners.contains(host)) {
      structureRisk += 15;
      addReason('This is a link-shortening domain; its final destination is not visible in the supplied URL.');
    }

    // Brand text in a subdomain is not proof of ownership. For example,
    // sbi.co.in.attacker.example is controlled by attacker.example.
    if (registrable != host && trustedDomains.keys.any((b) =>
        labels.take(labels.length - registrable.split('.').length).any((l) =>
            _normaliseConfusables(l).contains(_normaliseConfusables(b))))) {
      brandRisk = math.max(brandRisk, 38).toInt();
      addReason('A trusted brand name appears in a subdomain, but the registrable domain belongs to a different site.');
    }

    // 3. Suspicious URL content. These are weak signals unless combined with
    // brand deception or other risky behavior.
    final pathAndQuery = '${uri.path}?${uri.query}'.toLowerCase();
    final suspiciousPath = RegExp(
      r'(login|log-in|signin|sign-in|verify|verification|confirm|otp|kyc|'
      r'wallet|banking|password|reset|claim|reward|refund|payment)',
      caseSensitive: false,
    );
    if (suspiciousPath.hasMatch(pathAndQuery)) {
      contentRisk += 10;
      addReason('The URL path or query contains login, verification, payment or reward-related terms.');
    }
    if (uri.scheme.toLowerCase() == 'http') {
      contentRisk += 8;
      addReason('The URL uses HTTP rather than HTTPS; its connection is not encrypted. This alone does not prove fraud.');
    }
    if (uri.hasQuery && uri.query.length > 180) {
      contentRisk += 5;
      addReason('The URL contains an unusually long query string.');
    }

    // 4. Weak TLD signal. Never block or heavily penalise a TLD on its own.
    const higherRiskTlds = {'click', 'top', 'work', 'zip', 'rest', 'country', 'gq', 'tk', 'ml', 'cf'};
    final tld = labels.isNotEmpty ? labels.last : '';
    if (higherRiskTlds.contains(tld)) {
      domainRisk += 5;
      addReason('The domain uses a TLD sometimes seen in abusive registrations; this is only a weak signal.');
    }

    // Keep the category contributions bounded so repeated related indicators
    // do not automatically drive every result to 100.
    final score = (brandRisk.clamp(0, 40) +
            structureRisk.clamp(0, 25) +
            contentRisk.clamp(0, 15) +
            domainRisk.clamp(0, 5))
        .clamp(0, 100)
        .toInt();

    if (reasons.isEmpty) {
      addReason('No strong URL warning signs were detected. Domain reputation and website content were not verified.');
    }

    return _buildResult(
      inputType: 'url',
      score: score,
      reasons: reasons,
      customSummary: score >= redThreshold
          ? 'Multiple strong URL warning signs were detected. Do not enter credentials or payment details.'
          : score >= yellowThreshold
              ? 'Some URL warning signs were detected. Verify the domain independently before proceeding.'
              : 'No strong local URL warning signs were detected. This is not a reputation check and does not prove the website is safe.',
    );
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

  // Lightweight fallback for common multi-label public suffixes. For full
  // public-suffix accuracy, the online backend uses tldextract's bundled PSL.
  String _registrableDomain(String host) {
    final labels = host.split('.');
    if (labels.length <= 2) return host;
    const compoundSuffixes = {
      'co.in', 'com.in', 'net.in', 'org.in', 'gen.in', 'firm.in',
      'co.uk', 'org.uk', 'ac.uk', 'gov.uk', 'com.au', 'net.au',
      'org.au', 'co.nz', 'com.sg', 'com.my', 'com.br', 'com.cn',
      'com.hk', 'co.jp', 'co.za',
    };
    final lastTwo = '${labels[labels.length - 2]}.${labels.last}';
    if (compoundSuffixes.contains(lastTwo) && labels.length >= 3) {
      return labels.sublist(labels.length - 3).join('.');
    }
    return labels.sublist(labels.length - 2).join('.');
  }

  String _normaliseConfusables(String value) {
    const substitutions = {
      '0': 'o', '1': 'l', '3': 'e', '5': 's',
      'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c',
      'х': 'x', 'і': 'i', 'ј': 'j', 'у': 'y', 'к': 'k',
      'м': 'm', 'т': 't', 'в': 'b', 'н': 'h',
      'ο': 'o', 'ρ': 'p', 'ι': 'i', 'κ': 'k', 'ν': 'v',
    };
    var result = value.toLowerCase();
    substitutions.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
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
