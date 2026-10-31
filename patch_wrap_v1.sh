#!/usr/bin/env bash
# شجرة عائلتي - التفاف النص الطويل في سطرين أو أكثر
#  - الخريطة الذهنية: صناديق الزواج «تزوج ...» والأسماء أضيق عرضاً فيلتف الاسم الطويل
#  - الشجرة: اسم الشخص يمتد إلى سطرين بدل القص بنقاط
# شغّله من جذر المستودع: bash patch_wrap_v1.sh
set -euo pipefail

m=lib/ui/mind_map_screen.dart
t=lib/ui/tree_screen.dart
test -f "$m" || { echo "ملف الخريطة غير موجود"; exit 1; }
test -f "$t" || { echo "ملف الشجرة غير موجود"; exit 1; }
grep -q "weight: FontWeight.w500," "$m" || { echo "لم يُعثر على نمط عقدة الزواج في الخريطة"; exit 1; }
if grep -q "maxTextW: 150," "$m"; then echo "مطبّق سابقاً"; exit 0; fi

# ───────────────────────── 1) الخريطة: عرض نص أضيق وأسطر أكثر ─────────────────────────
# عقدة الزواج: من 3 أسطر/190 إلى 4 أسطر/150
sed -i -e '/weight: FontWeight.w500,/{' \
       -e 'n;s/maxLines: 3,/maxLines: 4,/' \
       -e 'n;s/maxTextW: 190,/maxTextW: 150,/' \
       -e '}' "$m"
# عقدة الشخص: 3 أسطر/150 (والجذر 220)
sed -i 's/maxTextW: isRoot ? 240 : 190,/maxTextW: isRoot ? 220 : 150,/' "$m"
sed -i 's/maxLines: isRoot ? 3 : 2,/maxLines: 3,/' "$m"

grep -q "maxLines: 4," "$m"
grep -q "maxTextW: 150," "$m"
grep -q "maxTextW: isRoot ? 220 : 150," "$m"
grep -q "weight: isRoot ? FontWeight.w700 : FontWeight.w600," "$m"

# ───────────────────────── 2) الشجرة: اسم من سطرين ─────────────────────────
sed -i 's/^\( *\)maxLines: 1,$/\1maxLines: 2,/' "$t"
grep -q "maxLines: 2," "$t"
if grep -q "maxLines: 1," "$t"; then echo "تعذّر تعديل سطور الشجرة"; exit 1; fi

echo "تم: النص الطويل يلتف في الخريطة والشجرة."
