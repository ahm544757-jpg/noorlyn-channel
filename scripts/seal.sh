#!/usr/bin/env bash
# ختم القناة — §٣/١٠: اقتران قراءة وكتابة (CAS).
# ينتج حجمًا مشفّرًا جديدًا هو لقطة كاملة لحالة القناة، برقم من النظام لا من عدّاد يدوي (§٤/٩).
# لا يُختم فوق رأس متحرك: إن كان البعيد يحمل حجمًا أحدث مما رأينا، يُستدرك أو يُرفض — فلا دهس.
set -euo pipefail
cd "$(dirname "$0")/.."

KEY="${CHANNEL_KEY_FILE:-/tmp/nlwork/channel.key}"
AGE="$(command -v age || echo ./age)"
# د-١٨: مساحة العمل لا تحفظ بيت التنفيذ عند الاستعادة، فيعود `age` بلا +x
# ويظهر «Permission denied» الذي **يُقرأ كأنه رفض** — وهي علّة عطّلت افتتاح جولة كاملة.
[ -f "$AGE" ] && [ ! -x "$AGE" ] && chmod +x "$AGE" 2>/dev/null || true
[ -x "$AGE" ] || { echo "FAIL: age not found"; exit 1; }
[ -r "$KEY" ] || { echo "FAIL: decryption key not readable at $KEY (§١/٤: من اللصقة إلى /tmp وضع 600)"; exit 1; }
PUB=$("$AGE"-keygen -y "$KEY" 2>/dev/null) || { echo "FAIL: cannot derive public key"; exit 1; }

# ---- حارس: لا سرّ داخل ما سيُختم (§٣/٤، §١٠/٧ حد أمان) ----
if grep -rlE 'AGE-SECRET-KEY-[1]|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----' inner/ 2>/dev/null | head -5 | grep -q .; then
  echo "FAIL: secret material detected inside inner/ — refusing to seal (حد أمان، م١٤/٢: توقّف قاطع)"
  grep -rlE 'AGE-SECRET-KEY-[1]|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----' inner/ | sed 's/^/  offending: /'
  exit 1
fi

# ---- حارس النقوش: الحالة يجب أن تحمل خطوة تالية (§٦/٢، بطاقة م١: لا تترك الحالة بلا خطوة تالية) ----
STATE="inner/الحالة/active-state.md"
if [ -f "$STATE" ]; then
  # ── مصدر واحد للحقيقة (م٢٢): لا يُعاد تنفيذ الفحص هنا بل يُستدعى الفاحص نفسه ──
  # ملاحظة م٢ (موضع رفض ٢): كانت هنا نسخة مكررة معيبة «{n;p;}» تقرأ السطر **التالي**
  # فتمرّر حالة فارغة (أخرجت ٣٥٤ حرفًا من سطر المراجعة الذاتية). الإصلاح الجذري:
  # حذف النسخة المكررة وربط الختم بالفاحص نفسه — فلا مصدران للحقيقة (م٢٢، §٢/١٠).
  GUARD="$(cd "$(dirname "$0")/.." && pwd)/guards/state-contract.sh"
  [ -f "$GUARD" ] || { echo "FAIL: guard not found at $GUARD"; exit 1; }
  if ! bash "$GUARD" "$STATE"; then
    echo "FAIL: guards/state-contract.sh rejected the state — refusing to seal (§٦/٢)"
    exit 1
  fi
fi

# ---- رقم الحجم من النظام لا من عدّاد يدوي (§٤/٩) ----
git fetch --quiet origin 2>/dev/null || true
# -z مع أن أسماء الأحجام لاتينية فلا تُقتبس: القاعدة تُعمَّم بلا استثناء، لأن الاستثناء
# يُساء قراءته لاحقًا فيُعاد إنتاج العلّة (واردة ٠٠١: الحالة نفسها وقعت مرتين).
LAST=$(git ls-tree --name-only -z HEAD vault/ 2>/dev/null | tr '\0' '\n' | grep -oE 'v-[0-9]+' | sort -V | tail -1 || true)
REMOTE_LAST=$(git ls-tree --name-only -z origin/HEAD vault/ 2>/dev/null | tr '\0' '\n' | grep -oE 'v-[0-9]+' | sort -V | tail -1 || true)
LOCAL_LAST=$(ls vault/ 2>/dev/null | grep -oE 'v-[0-9]+' | sort -V | tail -1 || true)
BASE="${REMOTE_LAST:-${LOCAL_LAST:-${LAST:-}}}"
if [ -n "$BASE" ]; then
  N=$(( 10#${BASE#v-} + 1 ))
else
  N=1
fi
# CAS: إن كان البعيد ahead مما في نسختنا، ارفض ولا تدهس
if [ -n "$REMOTE_LAST" ] && [ -n "$LOCAL_LAST" ] && [ "$((10#${REMOTE_LAST#v-}))" -gt "$((10#${LOCAL_LAST#v-}))" ]; then
  echo "FAIL: remote head is ahead (remote $REMOTE_LAST > local $LOCAL_LAST) — refusing to seal over a moving head (§٣/١٠)"
  exit 1
fi
VOL=$(printf "vault/v-%03d.enc" "$N")

# ---- بصمة ما قبل الختم، تُطبع في النبض العام (بلا مضمون) ----
PRE=$(find -L inner -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16)

tar czf /tmp/.seal-$$.tgz -C inner .
"$AGE" -r "$PUB" -o "$VOL" /tmp/.seal-$$.tgz
rm -f /tmp/.seal-$$.tgz
chmod 644 "$VOL"

# ---- تحقق أن الحجم يُفك فعلًا قبل اعتباره ختمًا (م١٢: لا ادعاء بلا دليل) ----
if ! "$AGE" -d -i "$KEY" "$VOL" | tar tzf - >/dev/null 2>&1; then
  echo "FAIL: volume $VOL does not decrypt — removing it rather than leaving a broken seal"
  rm -f "$VOL"; exit 1
fi

POST=$(find -L inner -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16)
printf '%s\n' "$(date -u +%FT%TZ)|$VOL|$PRE|$POST|$(stat -c %s "$VOL")" >> نبض/seals.log
echo "OK sealed $VOL  ($(stat -c %s "$VOL") bytes)  inner-digest=$POST"
echo "   next: git add -A && git commit && git push   (§٤/٨ ادفع قبل أن تفصل)"
