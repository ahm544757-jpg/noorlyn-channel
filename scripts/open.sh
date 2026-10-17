#!/usr/bin/env bash
# فتح القناة — §٥/١: استنساخ جزئي ← مفتاح بإدخال مخفي ← جلب أحدث الأحجام والأدوات.
# يقرأ أحدث حجم بعد جلب البعيد (§٣/١٠)، ويفكّه إلى مساحة مؤقتة خارج اللقطة (§٢).
set -euo pipefail
KEY="${CHANNEL_KEY_FILE:-/tmp/nlwork/channel.key}"
AGE="$(command -v age || echo "$(dirname "$0")/../age")"
# د-١٨: مساحة العمل لا تحفظ بيت التنفيذ عند الاستعادة، فيعود `age` بلا +x
# ويظهر «Permission denied» الذي **يُقرأ كأنه رفض** — وهي علّة عطّلت افتتاح جولة كاملة.
[ -f "$AGE" ] && [ ! -x "$AGE" ] && chmod +x "$AGE" 2>/dev/null || true
[ -r "$KEY" ] || { echo "FAIL: key not readable at $KEY — paste it from the recruitment message (§صفر/٣)"; exit 1; }
cd "$(dirname "$0")/.."
git pull --quiet 2>/dev/null || echo "  (no remote yet — reading local volumes)"
LATEST=$(ls vault/*.enc 2>/dev/null | grep -oE 'v-[0-9]+' | sort -V | tail -1 || true)
[ -n "$LATEST" ] || { echo "FAIL: no volumes in vault/ — nothing to open"; exit 1; }
VOL="vault/$LATEST.enc"
DEST="${1:-/tmp/nlwork/inner}"
mkdir -p "$DEST"
"$AGE" -d -i "$KEY" "$VOL" | tar xzf - -C "$DEST"
echo "OK opened $VOL -> $DEST  ($(find "$DEST" -type f | wc -l) files)"
