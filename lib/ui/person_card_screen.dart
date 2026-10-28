import 'package:flutter/material.dart';

import '../app_state.dart';
import 'image_export.dart';
import 'person_card.dart';
import 'ui_helpers.dart';
import 'widgets.dart';

/// معاينة بطاقة الفرد مع اختيار اللون والمحتوى والجودة ثم الحفظ أو المشاركة.
class PersonCardScreen extends StatefulWidget {
  const PersonCardScreen({
    super.key,
    required this.state,
    required this.personId,
  });

  final AppState state;
  final int personId;

  @override
  State<PersonCardScreen> createState() => _PersonCardScreenState();
}

class _PersonCardScreenState extends State<PersonCardScreen> {
  final _key = GlobalKey();
  ImageQuality _quality = ImageQuality.fhd;
  MaterialColor? _accent; // null = تلقائي حسب الجنس
  Set<CardSection> _sections = {...CardSection.values};
  bool _busy = false;

  String get _fileName =>
      'person_card_${widget.personId}_${imageTimestamp()}.png';

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final bytes = await captureBoundaryPng(_key, _quality);
      final ok = await saveImageToDevice(bytes, _fileName);
      if (ok && mounted) showMessage(context, 'تم حفظ الصورة');
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّر حفظ الصورة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await captureBoundaryPng(_key, _quality);
      await shareImageBytes(bytes, _fileName, subject: 'بطاقة شخص - شجرة عائلتي');
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّرت المشاركة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _swatch({MaterialColor? color, required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _accent = color),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.grey.shade300,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: color == null
            ? const Icon(Icons.auto_awesome, size: 16, color: Colors.black54)
            : (selected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('بطاقة الفرد كصورة')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final person = state.byId(widget.personId);
          if (person == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              message: 'هذا الشخص غير موجود',
            );
          }
          return Column(
            children: [
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: PersonCard.width,
                          child: RepaintBoundary(
                            key: _key,
                            child: PersonCard(
                              state: state,
                              person: person,
                              accent: _accent,
                              sections: _sections,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                elevation: 10,
                child: SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('لون البطاقة'),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _swatch(selected: _accent == null),
                              for (final c in cardPalette)
                                _swatch(color: c, selected: _accent == c),
                            ],
                          ),
                          _label('المحتوى'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final s in CardSection.values)
                                FilterChip(
                                  label: Text(s.label),
                                  selected: _sections.contains(s),
                                  onSelected: (on) => setState(() {
                                    final next = {..._sections};
                                    on ? next.add(s) : next.remove(s);
                                    _sections = next;
                                  }),
                                ),
                            ],
                          ),
                          _label('الجودة'),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ImageQuality>(
                              segments: [
                                for (final q in ImageQuality.values)
                                  ButtonSegment(value: q, label: Text(q.label)),
                              ],
                              selected: {_quality},
                              onSelectionChanged: (s) =>
                                  setState(() => _quality = s.first),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _quality.description,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy ? null : _save,
                                  icon: _busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.save_alt),
                                  label: const Text('حفظ في الجهاز'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy ? null : _share,
                                  icon: const Icon(Icons.share),
                                  label: const Text('مشاركة'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'لإبقاء الجودة في واتساب أرسل الصورة كمستند.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
