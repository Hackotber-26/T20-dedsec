import 'package:flutter/material.dart';

import '../data/demo_test_data.dart';

class DemoSamplesPanel extends StatefulWidget {
  final ValueChanged<DemoSample> onSampleSelected;

  const DemoSamplesPanel({super.key, required this.onSampleSelected});

  @override
  State<DemoSamplesPanel> createState() => _DemoSamplesPanelState();
}

class _DemoSamplesPanelState extends State<DemoSamplesPanel> {
  final TextEditingController _searchController = TextEditingController();

  DemoRiskCategory? _riskFilter;
  DemoSampleMode? _modeFilter;

  static const ink = Color(0xFF191614);
  static const muted = Color(0xFF7D777A);
  static const border = Color(0xFFE7E4E5);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _riskColor(DemoRiskCategory risk) {
    switch (risk) {
      case DemoRiskCategory.high:
        return const Color(0xFFD94B4B);
      case DemoRiskCategory.suspicious:
        return const Color(0xFFC28A24);
      case DemoRiskCategory.low:
        return const Color(0xFF21865B);
    }
  }

  IconData _modeIcon(DemoSampleMode mode) {
    switch (mode) {
      case DemoSampleMode.message:
        return Icons.message_outlined;
      case DemoSampleMode.website:
        return Icons.language;
      case DemoSampleMode.upi:
        return Icons.qr_code_2;
    }
  }

  List<DemoSample> get _filteredSamples {
    final query = _searchController.text.trim().toLowerCase();

    return DemoTestData.samples.where((sample) {
      final matchesRisk =
          _riskFilter == null || sample.expectedRisk == _riskFilter;

      final matchesMode = _modeFilter == null || sample.mode == _modeFilter;

      final matchesSearch =
          query.isEmpty ||
          sample.title.toLowerCase().contains(query) ||
          sample.description.toLowerCase().contains(query) ||
          sample.input.toLowerCase().contains(query);

      return matchesRisk && matchesMode && matchesSearch;
    }).toList();
  }

  void _selectSample(DemoSample sample) {
    Navigator.of(context).pop();
    widget.onSampleSelected(sample);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 20),
              _searchField(),
              const SizedBox(height: 16),
              _riskFilters(),
              const SizedBox(height: 10),
              _modeFilters(),
              const SizedBox(height: 16),
              Expanded(child: _sampleList()),
              const SizedBox(height: 12),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F5F3),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.library_books_outlined, color: ink),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Demo sample library',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Choose a scenario to test Pehchaan',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search samples...',
        hintStyle: const TextStyle(color: muted, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: muted, size: 19),
        filled: true,
        fillColor: const Color(0xFFF6F5F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.clear, size: 17),
              )
            : null,
      ),
    );
  }

  Widget _riskFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterChip(
          label: 'All risks',
          selected: _riskFilter == null,
          onTap: () => setState(() => _riskFilter = null),
        ),
        _filterChip(
          label: 'High risk',
          selected: _riskFilter == DemoRiskCategory.high,
          color: _riskColor(DemoRiskCategory.high),
          onTap: () => setState(() => _riskFilter = DemoRiskCategory.high),
        ),
        _filterChip(
          label: 'Suspicious',
          selected: _riskFilter == DemoRiskCategory.suspicious,
          color: _riskColor(DemoRiskCategory.suspicious),
          onTap: () =>
              setState(() => _riskFilter = DemoRiskCategory.suspicious),
        ),
        _filterChip(
          label: 'Low risk',
          selected: _riskFilter == DemoRiskCategory.low,
          color: _riskColor(DemoRiskCategory.low),
          onTap: () => setState(() => _riskFilter = DemoRiskCategory.low),
        ),
      ],
    );
  }

  Widget _modeFilters() {
    return Wrap(
      spacing: 8,
      children: [
        _modeChip('All types', null),
        _modeChip('Messages', DemoSampleMode.message),
        _modeChip('Websites', DemoSampleMode.website),
        _modeChip('UPI', DemoSampleMode.upi),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final activeColor = color ?? ink;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: activeColor.withValues(alpha: 0.12),
      backgroundColor: const Color(0xFFF6F5F3),
      side: BorderSide(color: selected ? activeColor : border),
      labelStyle: TextStyle(
        color: selected ? activeColor : muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _modeChip(String label, DemoSampleMode? mode) {
    final selected = _modeFilter == mode;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _modeFilter = mode),
      selectedColor: ink,
      backgroundColor: const Color(0xFFF6F5F3),
      side: BorderSide(color: selected ? ink : border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _sampleList() {
    final samples = _filteredSamples;

    if (samples.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 34, color: muted),
            SizedBox(height: 10),
            Text(
              'No samples found',
              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 5),
            Text(
              'Try another search or filter.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: samples.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final sample = samples[index];
        final color = _riskColor(sample.expectedRisk);

        return Material(
          color: const Color(0xFFFAF9F8),
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: () => _selectSample(sample),
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Container(
                    height: 39,
                    width: 39,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(_modeIcon(sample.mode), color: ink, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sample.title,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sample.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          sample.modeLabel,
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          sample.riskLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(Icons.arrow_forward, size: 15, color: muted),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _footer() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_filteredSamples.length} of ${DemoTestData.samples.length} samples',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _riskFilter = null;
              _modeFilter = null;
              _searchController.clear();
            });
          },
          child: const Text('Reset filters'),
        ),
      ],
    );
  }
}
