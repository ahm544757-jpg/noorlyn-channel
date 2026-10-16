#!/usr/bin/env bash
# الامتحان الذاتي للفاحص — واو م٧ «النفي قبل الثقة»
# الغرض: إثبات أن guards/state-contract.sh يرفض فعلًا، لا أنه يطبع ✓ على كل شيء.
#
# القاعدة الحاكمة (مستفادة من أربعة امتحانات معيبة كشفها م١ وم٢):
#   ١. كل طفرة تُطبَّق على **بنية العقد**، لا على نصّ ملف بعينه — فطفرة مربوطة بنصّ
#      معيّن تصير فارغة عند أول تحرير وتمرّ بصمت.
#   ٢. **المُسخِّر يحكم على نفسه**: إن لم يتغيّر الملف بعد الطفرة فالطفرة فارغة،
#      ويُحسب الامتحان فاشلًا لا ناجحًا. (كشف هذا: طفرات `empty_field` التي نسيت
#      تمرير الوسيط إلى python فكانت عشر طفرات أصفارًا ومرّت «بنجاح».)
#   ٣. المقام مشتقّ لا مكتوب.
#   ٤. السلبي يُمتحن مع النفي — فاحص يرفض كل شيء بلا فائدة.
set -uo pipefail
STATE="${1:-inner/الحالة/active-state.md}"
GUARD="guards/state-contract.sh"
[ -f "$STATE" ] || { echo "FAIL: no state at $STATE"; exit 2; }
[ -f "$GUARD" ] || { echo "FAIL: no guard at $GUARD"; exit 2; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp "$STATE" "$TMP/base"
BASE=$(sha256sum "$TMP/base" | cut -d' ' -f1)

T=0; R=0; VAC=0; FAILED_LIST=""

# ---- صنف أ: إفراغ قيمة كل حقل سطري في العقد (١٣ حقلًا) ----
FIELDS=( 'المهمة الواحدة الحية' 'صاحب المهمة' 'precondition' 'completion_marker' \
         'idempotency_rule' 'resume_action' 'المرحلة' 'حالة المهمة' \
         'آخر فحص أخضر' 'شكل التسليم' 'سطر مراجعة ذاتية' 'المدة الحقيقية المقدرة' \
         'الخطوة التالية حرفيًا' )
for f in "${FIELDS[@]}"; do
  T=$((T+1))
  python3 -c '
import sys
p=sys.argv[1]; L=open(p,encoding="utf-8").read().split("\n")
name=sys.argv[2]; done=False
for i,l in enumerate(L):
    if l.startswith("- **"+name+":**"):
        assert l.strip() != "- **"+name+":**", "فارغ أصلًا"
        L[i]="- **"+name+":**"; done=True; break
assert done, "الحقل غير موجود: "+name
open(p,"w",encoding="utf-8").write("\n".join(L))' "$STATE" "$f" 2>"$TMP/err"
  MUTRC=$?
  NOW=$(sha256sum "$STATE" | cut -d' ' -f1)
  if [ $MUTRC -ne 0 ] || [ "$NOW" = "$BASE" ]; then
    VAC=$((VAC+1)); FAILED_LIST="$FAILED_LIST [فارغة:$f]"
    cp "$TMP/base" "$STATE"; continue
  fi
  bash "$GUARD" "$STATE" >/dev/null 2>&1 && { FAILED_LIST="$FAILED_LIST [مرّت:$f]"; } || R=$((R+1))
  cp "$TMP/base" "$STATE"
done

# ---- صنف ب: إسناد ملكية المهمة إلى المحقق (§٢/١١) ----
T=$((T+1))
python3 -c '
import sys
p=sys.argv[1]; s=open(p,encoding="utf-8").read()
s2=s.replace("**صاحب المهمة:** م١","**صاحب المهمة:** م٢ — المحقق",1)
assert s2!=s, "لم تتغيّر"
open(p,"w",encoding="utf-8").write(s2)' "$STATE" 2>/dev/null
[ "$(sha256sum "$STATE" | cut -d' ' -f1)" = "$BASE" ] && VAC=$((VAC+1)) || {
  bash "$GUARD" "$STATE" >/dev/null 2>&1 && FAILED_LIST="$FAILED_LIST [مرّت:§٢/١١]" || R=$((R+1)); }
cp "$TMP/base" "$STATE"

# ---- صنف ج: حذف جدول العوائق كلّه (حقل قسمي) ----
T=$((T+1))
python3 -c '
import sys
p=sys.argv[1]; L=open(p,encoding="utf-8").read().split("\n")
out=[l for l in L if not (l.startswith("| العائق") or l.startswith("|---") or (l.startswith("|") and ("reversible-default" in l or "blocking-" in l)))]
assert len(out)<len(L), "لم يُحذف شيء"
open(p,"w",encoding="utf-8").write("\n".join(out))' "$STATE" 2>/dev/null
[ "$(sha256sum "$STATE" | cut -d' ' -f1)" = "$BASE" ] && VAC=$((VAC+1)) || {
  bash "$GUARD" "$STATE" >/dev/null 2>&1 && FAILED_LIST="$FAILED_LIST [مرّت:العوائق]" || R=$((R+1)); }
cp "$TMP/base" "$STATE"

# ---- صنف د: حارة ثانية حية (§٤/٦) ----
T=$((T+1))
python3 -c '
import sys
p=sys.argv[1]; s=open(p,encoding="utf-8").read()
s2=s.replace("- **حالة المهمة:**","- **المهمة الواحدة الحية:** مهمة ثانية مخالفة\n- **حالة المهمة:**",1)
assert s2!=s, "لم تتغيّر"
open(p,"w",encoding="utf-8").write(s2)' "$STATE" 2>/dev/null
[ "$(sha256sum "$STATE" | cut -d' ' -f1)" = "$BASE" ] && VAC=$((VAC+1)) || {
  bash "$GUARD" "$STATE" >/dev/null 2>&1 && FAILED_LIST="$FAILED_LIST [مرّت:حارة ثانية]" || R=$((R+1)); }
cp "$TMP/base" "$STATE"

# ---- السلبي: الحالة السليمة يجب أن تمرّ ----
NEG=0
bash "$GUARD" "$STATE" >/dev/null 2>&1 && NEG=1

# ---- سلامة الملف بعد الامتحان ----
AFTER=$(sha256sum "$STATE" | cut -d' ' -f1)
RESTORED=0; [ "$AFTER" = "$BASE" ] && RESTORED=1

echo "──────── الامتحان الذاتي للفاحص ────────"
echo "  الطفرات:            $T   (المقام مشتقّ)"
echo "  المرفوضة:           $R"
echo "  الفارغة:            $VAC   ⟵ إن ≠ ٠ فالامتحان يحكم على نفسه بالفشل"
echo "  السلبي يمرّ:        $([ $NEG -eq 1 ] && echo نعم || echo لا)"
echo "  الملف أُعيد كما كان: $([ $RESTORED -eq 1 ] && echo نعم || echo لا)"
[ -n "$FAILED_LIST" ] && echo "  المواضع الفاشلة:   $FAILED_LIST"

if [ $VAC -ne 0 ] || [ $R -ne $T ] || [ $NEG -ne 1 ] || [ $RESTORED -ne 1 ]; then
  echo "REJECTED — الفاحص غير جدير بالثقة (واو م٧)"; exit 1
fi
echo "OK — $R/$T طفرات مرفوضة، صفر فراغة، والسلبي يمرّ"; exit 0
