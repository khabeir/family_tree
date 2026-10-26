import 'package:flutter/material.dart';

import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../domain/family_service.dart';

String genderLabel(Gender g) => switch (g) {
      Gender.male => 'ذكر',
      Gender.female => 'أنثى',
      Gender.unknown => 'غير محدد',
    };

String marriageStatusLabel(MarriageStatus s) => switch (s) {
      MarriageStatus.married => 'قائم',
      MarriageStatus.divorced => 'انتهى بطلاق',
      MarriageStatus.widowed => 'انتهى بوفاة',
    };

IconData genderIcon(Gender g) => switch (g) {
      Gender.male => Icons.man,
      Gender.female => Icons.woman,
      Gender.unknown => Icons.person,
    };

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// ينفذ [action] ويعرض أخطاء التحقق للمستخدم. يعيد true عند النجاح.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } on FamilyValidationException catch (e) {
    showMessage(context, e.message);
  } catch (e) {
    showMessage(context, 'تعذّر تنفيذ العملية: $e');
  }
  return false;
}
