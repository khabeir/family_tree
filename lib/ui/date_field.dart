import 'package:flutter/material.dart';

String formatIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final initial =
        (value == null ? null : DateTime.tryParse(value!)) ?? DateTime(1980);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(formatIsoDate(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(value ?? 'غير محدد'),
      ),
    );
  }
}
