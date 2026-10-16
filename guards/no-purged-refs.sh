#!/usr/bin/env bash
# يمنع الاستشهاد بأي التزام أو تشغيلة مطهَّرة في أي وثيقة حاكمة.
# السبب: بقاء استشهاد بمطهَّر يجعل الوثيقة تصف واقعًا غير موجود (م٦/٥، م١٦/٤، م٢٠/٤).
# وتصحيح النص مرة لا يكفي — فالحارس هو ما يمنع العودة (م٢٢: مصدر حقيقة واحد).
set -uo pipefail
LOG="نبض/purges.log"
[ -f "$LOG" ] || { echo "FAIL: no purges log at $LOG"; exit 2; }
mapfile -t PURGED < <(grep -oE '\b[0-9a-f]{7,40}\b' "$LOG" | sort -u)
[ "${#PURGED[@]}" -gt 0 ] || { echo "FAIL: purges log carries no identifier — nothing to guard"; exit 2; }
echo "فاحص الاستشهاد بالمطهَّر — ${#PURGED[@]} معرّفًا مطهَّرًا في المرجع"
BAD=0
for d in inner guards scripts .github نبض README.md; do
  [ -e "$d" ] || continue
  for sha in "${PURGED[@]}"; do
    # -z على مخرَج git غير لازم هنا (find/grep)، لكن المسارات العربية تُعالج بـ -print0
    while IFS= read -r -d '' f; do
      case "$f" in
        */purges.log|*سجل-توسيم*|*واردة-٠٠٣*) continue ;;   # السجل نفسه والوثائق **عن** التطهير
      esac
      if grep -qF "$sha" "$f" 2>/dev/null; then
        # يُستثنى الذكر المؤشَّر صراحةً بأنه مطهَّر/تاريخي
        if grep -F "$sha" "$f" | grep -qE 'مطهَّر|مطهّرة|تاريخي|~~|لا يُستشهد|404|422'; then continue; fi
        echo "  ✗ $f يستشهد بالمطهَّر $sha بلا تأشير تاريخي"; BAD=$((BAD+1))
      fi
    done < <(find "$d" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.yml' -o -name '*.log' \) -print0 2>/dev/null)
  done
done
if [ "$BAD" -eq 0 ]; then echo "OK — صفر استشهاد غير مؤشَّر بمعرّف مطهَّر"; exit 0
else echo "REJECTED — $BAD استشهادًا بمطهَّر (م٦/٥، م١٦/٤)"; exit 1; fi
