import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/access_code.dart';
import 'contact.dart';

/// حالة الفتح داخل الذاكرة: تبقى مفتوحة [sessionLength] بعد إدخال الكود الصحيح،
/// وبعد [maxFailures] محاولات خاطئة يُمنع الإدخال [blockLength].
class AccessGate {
  AccessGate._();

  static const Duration sessionLength = Duration(minutes: 10);
  static const Duration blockLength = Duration(minutes: 1);
  static const int maxFailures = 5;

  static DateTime? _unlockedUntil;
  static DateTime? _blockedUntil;
  static int _failures = 0;

  static bool get isUnlocked {
    final until = _unlockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  static void lockNow() => _unlockedUntil = null;

  static void _unlock(DateTime now) {
    _unlockedUntil = now.add(sessionLength);
    _failures = 0;
    _blockedUntil = null;
  }

  /// يسجّل محاولة خاطئة؛ يعيد true إن صار الإدخال ممنوعاً.
  static bool _registerFailure(DateTime now) {
    _failures++;
    if (_failures >= maxFailures) {
      _failures = 0;
      _blockedUntil = now.add(blockLength);
      return true;
    }
    return false;
  }

  /// true إن كانت الشاشة مفتوحة أو أدخل المستخدم الكود الصحيح.
  static Future<bool> ensureUnlocked(BuildContext context) async {
    if (isUnlocked) return true;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CodeDialog(),
    );
    return ok ?? false;
  }
}

class _ContactNotice extends StatefulWidget {
  const _ContactNotice();

  @override
  State<_ContactNotice> createState() => _ContactNoticeState();
}

class _ContactNoticeState extends State<_ContactNotice> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kContactNotice,
                  style: TextStyle(color: fg, height: 1.4),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone, size: 18, color: fg),
                    const SizedBox(width: 6),
                    SelectableText(
                      kContactPhone,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'نسخ الرقم',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy,
                        size: 18,
                        color: fg,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: kContactPhone),
                        );
                        if (mounted) setState(() => _copied = true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final now = DateTime.now();
    final blocked = AccessGate._blockedUntil;
    if (blocked != null && now.isBefore(blocked)) {
      final secs = blocked.difference(now).inSeconds + 1;
      setState(() => _error = 'محاولات كثيرة. انتظر $secs ثانية');
      return;
    }
    if (isValidUnlockCode(_controller.text, now)) {
      AccessGate._unlock(now);
      Navigator.of(context).pop(true);
      return;
    }
    final blockedNow = AccessGate._registerFailure(now);
    setState(() {
      _error = blockedNow ? 'محاولات كثيرة. انتظر دقيقة' : 'الكود غير صحيح';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline),
          SizedBox(width: 8),
          Text('شاشة محمية'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل الكود للمتابعة.'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'الكود',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            const _ContactNotice(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('فتح')),
      ],
    );
  }
}

/// يغلّف شاشة محمية: يطلب الكود عند فتحها، وإن أُلغي الإدخال يعود للخلف.
class Gated extends StatefulWidget {
  const Gated({super.key, required this.child});

  final Widget child;

  @override
  State<Gated> createState() => _GatedState();
}

class _GatedState extends State<Gated> {
  late bool _ok = AccessGate.isUnlocked;

  @override
  void initState() {
    super.initState();
    if (!_ok) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    final ok = await AccessGate.ensureUnlocked(context);
    if (!mounted) return;
    if (ok) {
      setState(() => _ok = true);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ok) return widget.child;
    return Scaffold(
      appBar: AppBar(title: const Text('شاشة محمية')),
      body: const Center(child: Icon(Icons.lock_outline, size: 64)),
    );
  }
}
