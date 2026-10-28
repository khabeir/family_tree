import 'package:flutter/material.dart';

import '../app_state.dart';
import 'image_export.dart';
import 'person_card.dart';
import 'ui_helpers.dart';
import 'widgets.dart';

/// معاينة بطاقة الشخص مع حفظها كصورة (بجودة تختارها) أو مشاركتها.
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

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('بطاقة الشخص')),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: RepaintBoundary(
                          key: _key,
                          child: PersonCard(state: state, person: person),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                elevation: 8,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<ImageQuality>(
                          segments: [
                            for (final q in ImageQuality.values)
                              ButtonSegment(value: q, label: Text(q.label)),
                          ],
                          selected: {_quality},
                          onSelectionChanged: (s) =>
                              setState(() => _quality = s.first),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _quality.description,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _save,
                                icon: const Icon(Icons.save_alt),
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
            ],
          );
        },
      ),
    );
  }
}
