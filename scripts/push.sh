#!/usr/bin/env bash
# دفع محروس — يمنع دفع inner/ مكشوفًا إلى بيت القناة العام (§٣/١).
#
# عِلّة وُجدت ودُفعت ثمنها: git يقتبس المسارات غير اللاتينية افتراضيًّا (core.quotepath)،
# فيُخرج  "inner/\330\247\331\204\330\255\330\247\331\204\330\251/..."  مبدوءًا بعلامة اقتباس.
# فالنمط `^inner/` لا يطابقه أبدًا — وكان الحارس أعمى عن المجلد العربي الذي وُجد ليحميه.
# القياس: النمط القديم طابق 0، و`-z` طابق 1 على الملف نفسه.
# القاعدة: كل فحص على مخرَج git لمسارات يجب أن يستعمل `-z` (NUL، بلا اقتباس).
set -euo pipefail
cd "$(dirname "$0")/.."
TOKF="${TOKEN_FILE:-/tmp/nlsec/.tok}"
REPO="${CHANNEL_REPO:-ahm544757-jpg/noorlyn-channel}"
[ -r "$TOKF" ] || { echo "FAIL: token file not readable at $TOKF (§١/٤)"; exit 1; }

git add -A
# -z هو الإصلاح: NUL-separated ولا يقتبس المسارات إطلاقًا
STAGED=$(git diff --cached --name-only -z | tr '\0' '\n')
[ -n "$STAGED" ] || { echo "  nothing to commit"; exit 0; }

# --- حارس ١: قائمة إباحة (default-deny) — لا مسار حرفي ---
#
# العلّة التي دُفع ثمنها ثلاث مرات: كان الحارس يفحص `^inner/` وحده. وهذا **مسار حرفي**،
# لا قاعدة بنيوية. ففي المرة الثالثة فُكّ حجم إلى **جذر المستودع** (`tar xzf - -C .`) فظهرت
# `الحالة/` و`العمل/` و`المعرفة/` و`الملاحق/` في الجذر — بلا بادئة `inner/` إطلاقًا —
# فدفعها الحارس وهي **كل محتوى القناة مكشوفًا**. والحارس لم يُخطئ بما يفحص؛ بل كان
# فحصه **أضيق من القاعدة**. و`.gitignore` يحرس `inner/` وحده أيضًا فلم يلتقطها.
#
# القاعدة الصحيحة: **ما يُباح دفعه معدود، وكل ما عداه مرفوض.** فالقاعدة البنيوية
# لا تعتمد على اسم المجلد الذي اتُّفق عليه اليوم، بل على أن المضمون المختوم
# لا يملك أي طريق إلى الشجرة — أيًّا كان اسمه أو موضعه.
ALLOWED_TOPLEVEL='.github
.gitignore
LICENSE-NOTICE.md
README.md
STAGING-NOTICE.md
guards
scripts
vault
نبض'
# -z إجباري: git يقتبس المسارات غير اللاتينية (واردة ٠٠١) — والقائمة نفسها تحوي «نبض»
BAD_PATHS=$(echo "$STAGED" | awk -v allow="$ALLOWED_TOPLEVEL" '
  BEGIN { n=split(allow, a, "\n"); for (i=1;i<=n;i++) ok[a[i]]=1 }
  NF { top=$0; sub(/\/.*/, "", top); if (!(top in ok)) print $0 }')
if [ -n "$BAD_PATHS" ]; then
  echo "FAIL: مسار خارج قائمة الإباحة — بيت القناة عام، و§٣/١ يوجب أن يكون كل مضمون داخل vault/."
  echo "$BAD_PATHS" | sed 's/^/  offending: /'
  echo "  المباح في الجذر فقط: $(echo "$ALLOWED_TOPLEVEL" | tr '\n' ' ')"
  echo "  fix: أزل المسار من الشجرة؛ فالمحتوى يُختم في vault/ ولا يُدفع نصًّا."
  exit 1
fi
# وفحص inner/ صريحًا أيضًا (دفاع في العمق — لا بديل عن القائمة)
if echo "$STAGED" | grep -q '^inner/'; then
  echo "FAIL: inner/ is staged (§٣/١)"; echo "$STAGED" | grep '^inner/' | sed 's/^/  offending: /'; exit 1
fi

# --- حارس ٢: لا سرّ في أي متن مدفوع (§١٠/٧ — حد أمان، توقّف قاطع) ---
BAD=$(echo "$STAGED" | tr '\n' '\0' | xargs -0 grep -lIE \
  'AGE-SECRET-KEY-[1]|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY|sk-[A-Za-z0-9]{32,}' \
  2>/dev/null | head -5 || true)
if [ -n "$BAD" ]; then
  echo "FAIL: secret material staged — refusing to push (حد أمان)"
  echo "$BAD" | sed 's/^/  offending: /'
  exit 1
fi

# --- حارس ٣: لا يُدفع حجم لا يُفك (§١٢: لا ادعاء بلا دليل) ---
KEY="${CHANNEL_KEY_FILE:-/tmp/nlsec/channel.key}"
if [ -r "$KEY" ]; then
  AGE="$(command -v age || echo ./age)"
  for v in vault/*.enc; do
    [ -e "$v" ] || continue
    "$AGE" -d -i "$KEY" "$v" | tar tzf - >/dev/null 2>&1 || { echo "FAIL: $v does not decrypt"; exit 1; }
  done
  echo "  ✓ all $(ls vault/*.enc 2>/dev/null | wc -l) volume(s) decrypt"
else
  echo "  ! decryption key absent — skipping volume verification (not a failure, but not a proof either)"
fi

git commit -q -m "${1:-نقش: تحديث القناة}"
git push -q "https://$(cat "$TOKF")@github.com/${REPO}.git" main:main
echo "  ✓ pushed $(git rev-parse --short HEAD) — $(echo "$STAGED" | grep -c .) file(s)"
echo "  §٤/٨: تحقق أن البعيد يحمله قبل أن تفصل"
