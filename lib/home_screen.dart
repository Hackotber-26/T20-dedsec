import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'detection_service.dart';

enum DetectionMode { message, website, upi }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DetectionService _detector = DetectionService.instance;
  final TextEditingController _inputController = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  final MobileScannerController _scannerController =
      MobileScannerController();

  DetectionMode _mode = DetectionMode.message;
  RiskResult? _result;
  bool _isLoading = false;
  bool _showScanner = false;
  String _language = 'English';

  static const Color background = Color(0xFFF6F5F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF191614);
  static const Color muted = Color(0xFF7D777A);
  static const Color borderColor = Color(0xFFE7E4E5);
  static const Color accent = Color(0xFF534F51);

  @override
  void dispose() {
    _inputController.dispose();
    _scannerController.dispose();
    _tts.stop();
    super.dispose();
  }

  Color get _riskColor {
    if (_result == null) return muted;

    switch (_result!.level) {
      case RiskLevel.green:
        return const Color(0xFF21865B);
      case RiskLevel.yellow:
        return const Color(0xFFC28A24);
      case RiskLevel.red:
        return const Color(0xFFD94B4B);
    }
  }

  String get _riskLabel {
    if (_result == null) return 'Waiting for analysis';

    switch (_result!.level) {
      case RiskLevel.green:
        return 'LOW RISK';
      case RiskLevel.yellow:
        return 'SUSPICIOUS';
      case RiskLevel.red:
        return 'HIGH RISK';
    }
  }

  Future<void> _analyze() async {
    final input = _inputController.text.trim();

    if (input.isEmpty) {
      _showMessage('Please enter something to analyze.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _showScanner = false;
      _result = null;
    });

    try {
      RiskResult result;

      switch (_mode) {
        case DetectionMode.message:
          result = _detector.checkMessage(input);
          break;
        case DetectionMode.website:
          result = _detector.checkUrl(input);
          break;
        case DetectionMode.upi:
          result = _detector.checkUpi(input);
          break;
      }

      if (!mounted) return;

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Could not analyze this input. Please try again.');
    }
  }

  void _handleQr(String value) {
    if (value.trim().isEmpty) return;

    _inputController.text = value;

    final lower = value.toLowerCase();

    if (lower.startsWith('upi://')) {
      _mode = DetectionMode.upi;
    } else if (lower.startsWith('http://') ||
        lower.startsWith('https://')) {
      _mode = DetectionMode.website;
    } else {
      _mode = DetectionMode.message;
    }

    setState(() {
      _showScanner = false;
    });

    _analyze();
  }

  Future<void> _speakResult() async {
    if (_result == null) return;

    final languageSettings = {
      'English': {
        'locale': 'en-IN',
        'message': 'The result is ${_result!.verdict}. ${_result!.summary}',
      },
      'Hindi': {
        'locale': 'hi-IN',
        'message':
            'परिणाम है ${_result!.verdict}. ${_result!.summary}',
      },
      'Kannada': {
        'locale': 'kn-IN',
        'message':
            'ಪರಿಶೀಲನೆಯ ಫಲಿತಾಂಶ ${_result!.verdict}. ${_result!.summary}',
      },
    };

    final settings = languageSettings[_language]!;

    try {
      await _tts.setLanguage(settings['locale']!);
      await _tts.setSpeechRate(0.45);
      await _tts.speak(settings['message']!);
    } catch (_) {
      _showMessage('Speech is not available on this device.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectMode(DetectionMode mode) {
    setState(() {
      _mode = mode;
      _result = null;
      _showScanner = false;
      _inputController.clear();
    });
  }

  void _loadSample(String value, DetectionMode mode) {
    setState(() {
      _mode = mode;
      _inputController.text = value;
      _result = null;
      _showScanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            if (width >= 1000) {
              return _buildDesktopLayout();
            }

            if (width >= 650) {
              return _buildTabletLayout();
            }

            return _buildMobileLayout();
          },
        ),
      ),
    );
  }

  // DESKTOP LAYOUT

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 250,
          child: _buildSidebar(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1250),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcome(),
                          const SizedBox(height: 28),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 11,
                                child: _buildDetectionPanel(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 9,
                                child: _buildResultPanel(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildSafetyBanner(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      decoration: const BoxDecoration(
        color: surface,
        border: Border(
          right: BorderSide(color: borderColor),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(),
          const SizedBox(height: 48),
          const Text(
            'WORKSPACE',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _sidebarItem(
            Icons.dashboard_outlined,
            'Overview',
            selected: true,
          ),
          _sidebarItem(
            Icons.shield_outlined,
            'Scam detection',
            onTap: () => _selectMode(DetectionMode.message),
          ),
          _sidebarItem(
            Icons.qr_code_scanner,
            'QR scanner',
            onTap: () => setState(() => _showScanner = true),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.security, color: accent, size: 24),
                SizedBox(height: 12),
                Text(
                  'Stay protected',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Always verify suspicious links and payment requests.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PEHCHAAN  •  MVP',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String label, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? background : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? ink : muted,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? ink : accent,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Scam protection dashboard',
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          _languageSelector(),
          const SizedBox(width: 16),
          const CircleAvatar(
            radius: 17,
            backgroundColor: background,
            child: Icon(Icons.person_outline, color: ink, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR DIGITAL SAFETY COMPANION',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Detect scams before they reach you.',
          style: TextStyle(
            color: ink,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Analyze suspicious messages, links, and payment requests.',
          style: TextStyle(
            color: accent.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // TABLET LAYOUT

  Widget _buildTabletLayout() {
    return Column(
      children: [
        _buildCompactHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcome(),
                const SizedBox(height: 24),
                _buildDetectionPanel(),
                const SizedBox(height: 20),
                _buildResultPanel(),
                const SizedBox(height: 20),
                _buildSafetyBanner(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MOBILE LAYOUT

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildCompactHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detect scams before they reach you.',
                  style: TextStyle(
                    color: ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your digital safety companion.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 22),
                _buildDetectionPanel(),
                const SizedBox(height: 18),
                _buildResultPanel(),
                const SizedBox(height: 18),
                _buildSafetyBanner(),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'PEHCHAAN  •  MVP',
                    style: TextStyle(
                      color: muted.withValues(alpha: 0.8),
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 15,
      ),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        children: [
          _buildLogo(),
          const Spacer(),
          _languageSelector(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'pehchaan',
          style: TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }

  Widget _languageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _language,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          items: const [
            DropdownMenuItem(
              value: 'English',
              child: Text('English'),
            ),
            DropdownMenuItem(
              value: 'Hindi',
              child: Text('हिन्दी'),
            ),
            DropdownMenuItem(
              value: 'Kannada',
              child: Text('ಕನ್ನಡ'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _language = value);
            }
          },
        ),
      ),
    );
  }

  // DETECTION PANEL

  Widget _buildDetectionPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Analyze content',
            'Choose what you want to check.',
            Icons.search,
          ),
          const SizedBox(height: 22),
          _buildModeSelector(),
          const SizedBox(height: 20),
          if (_showScanner) ...[
            _buildScanner(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _showScanner = false);
              },
              icon: const Icon(Icons.keyboard),
              label: const Text('Enter manually instead'),
            ),
          ] else ...[
            _buildInputField(),
            const SizedBox(height: 14),
            _buildAnalyzeButton(),
            const SizedBox(height: 20),
            _buildSampleInputs(),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final modes = [
      (DetectionMode.message, Icons.message_outlined, 'Message'),
      (DetectionMode.website, Icons.language, 'Website'),
      (DetectionMode.upi, Icons.qr_code_2, 'UPI / QR'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: modes.map((item) {
            final selected = _mode == item.$1;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _selectMode(item.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? ink : background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? ink : borderColor,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          item.$2,
                          size: 19,
                          color: selected ? Colors.white : accent,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.$3,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? Colors.white : accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInputField() {
    String hint;

    switch (_mode) {
      case DetectionMode.message:
        hint = 'Paste a suspicious SMS, email, or message here...';
        break;
      case DetectionMode.website:
        hint = 'https://example.com';
        break;
      case DetectionMode.upi:
        hint = 'Paste a UPI payment link here...';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONTENT TO ANALYZE',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _inputController,
          minLines: 5,
          maxLines: 7,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(
            color: ink,
            fontSize: 13,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFAAA5A8),
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFFAF9F8),
            contentPadding: const EdgeInsets.all(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: accent, width: 1.4),
            ),
          ),
        ),
        if (_mode == DetectionMode.upi) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _showScanner = true);
              },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Scan QR using camera'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                side: const BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 49,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _analyze,
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: muted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 18),
                  SizedBox(width: 9),
                  Text(
                    'Analyze now',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSampleInputs() {
    final isMessage = _mode == DetectionMode.message;
    final isWebsite = _mode == DetectionMode.website;

    final sample = isMessage
        ? 'URGENT! Your bank account will be blocked. Verify your KYC immediately: http://example-suspicious-link.com'
        : isWebsite
            ? 'http://example-suspicious-link.com'
            : 'upi://pay?pa=example@upi&pn=Unknown&am=5000';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRY A SAMPLE',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 9),
        InkWell(
          onTap: () => _loadSample(sample, _mode),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: accent,
                  size: 17,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Load a sample input',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  color: muted,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // QR SCANNER

  Widget _buildScanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SCAN A QR CODE',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 280,
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final barcode = capture.barcodes.firstOrNull;
                final value = barcode?.rawValue;

                if (value != null && value.isNotEmpty && _showScanner) {
                  _handleQr(value);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Position the QR code inside the camera view.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }

  // RESULT PANEL

  Widget _buildResultPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Analysis result',
            'Your detection report appears here.',
            Icons.analytics_outlined,
          ),
          const SizedBox(height: 22),
          if (_result == null)
            _buildEmptyResult()
          else
            _buildActualResult(),
        ],
      ),
    );
  }

  Widget _buildEmptyResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 35,
        horizontal: 18,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 29,
              color: muted,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'No analysis yet',
            style: TextStyle(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Submit a message, website, or UPI link to see its risk assessment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActualResult() {
    final result = _result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _riskColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _riskColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    result.level == RiskLevel.green
                        ? Icons.verified_user_outlined
                        : result.level == RiskLevel.yellow
                            ? Icons.warning_amber_rounded
                            : Icons.gpp_bad_outlined,
                    color: _riskColor,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _riskLabel,
                    style: TextStyle(
                      color: _riskColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.score}',
                    style: TextStyle(
                      color: _riskColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5, left: 5),
                    child: Text(
                      '/ 100 risk score',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (result.score / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation<Color>(_riskColor),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                result.verdict,
                style: const TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.summary,
                style: const TextStyle(
                  color: accent,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'DETECTION INSIGHTS',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        if (result.reasons.isEmpty)
          const Text(
            'No specific warning indicators were detected.',
            style: TextStyle(color: muted, fontSize: 12),
          )
        else
          ...result.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: _riskColor,
                    size: 17,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        color: accent,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _speakResult,
            icon: const Icon(Icons.volume_up_outlined, size: 18),
            label: const Text('Listen to result'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              side: const BorderSide(color: borderColor),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      'Pehchaan analysis\n${result.verdict}\nRisk score: ${result.score}/100\n${result.summary}\n${result.reasons.join('\n')}',
                ),
              );
              _showMessage('Analysis copied to clipboard.');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy report'),
            style: TextButton.styleFrom(
              foregroundColor: accent,
            ),
          ),
        ),
      ],
    );
  }

  // SHARED COMPONENTS

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeading(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ink, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.white,
            size: 23,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A quick safety reminder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Never share your OTP, UPI PIN, or banking password. '
                  'Do not trust a message just because it looks official. '
                  'Always verify through the official app or website.',
                  style: TextStyle(
                    color: Color(0xFFD3CED3),
                    fontSize: 11,
                    height: 1.6,
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