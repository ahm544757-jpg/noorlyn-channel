#!/usr/bin/env bash
# إعادة اشتقاق محصلة تدقيق الامتثال من جدوله — واو م٢٢ «لا مصادر حقيقة متنافسة»
# السبب: كُتبت المحصلة يدًا بجانب الجدول ثلاث مرات فاختلفت عنه (١٠/٤ ثم ٩+٦+٢+٥ مقابل
# ١٠·٥·٢·٥). فالإصلاح الجذري ليس تصحيح الرقم بل **منع وجود رقم مكتوب يدًا**.
set -uo pipefail
F="${1:-inner/العمل/تدقيق-الامتثال-لواو-v2.0.md}"
[ -f "$F" ] || { echo "FAIL: no file at $F"; exit 2; }
python3 - "$F" <<'PY'
import re,sys,collections
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
# الأسطر الحاكمة فقط: صفوف الجدول. ويُستثنى الاقتباس (>) والتعليق (<!--) لأنهما شرح
# عن العيب لا محصلة معلنة — وإلا التقط المشتقّ أرقام الشرح فاتهم الوثيقة (نمط
# «الوثيقة عن العيب تحمل العيب حرفًا»، واردة-٠٠٢).
lines=[l for l in s.split('\n') if not l.lstrip().startswith(('>','<!--'))]
body='\n'.join(lines)
rows=re.findall(r'^\|\s*(م\d+)\s*\|.*?\|\s*(✅|⚠|❌|🕐)\s*\|', body, re.M)
c=collections.Counter(m for _,m in rows)
tot=len(rows)
derived=f"{c['✅']} ✅ · {c['⚠']} ⚠ · {c['❌']} ❌ · {c['🕐']} 🕐 = {tot}"
print(f"  المشتقّ من الجدول: {derived}")
print(f"  صفوف المعايير: {tot} · المقام المعلن في الملف: 22")
bad=0
if tot!=22: print(f"  ✗ عدد الصفوف {tot} ≠ ٢٢ — معيار بلا مصير أو صف زائد"); bad=1
# كل سطر محصلة مكتوب يدًا في الملف يجب أن يطابق المشتقّ
for m in re.finditer(r'(\d+)\s*[+·]\s*(\d+)\s*[+·]\s*(\d+)\s*[+·]\s*(\d+)\s*=\s*(\d+)', body):
    nums=[int(x) for x in m.groups()]
    if nums[:4]!=[c['✅'],c['⚠'],c['🕐'],c['❌']] and sorted(nums[:4])!=sorted([c['✅'],c['⚠'],c['❌'],c['🕐']]):
        print(f"  ✗ سطر جمع مكتوب يدًا {nums} يخالف الجدول {derived}"); bad=1
    elif nums[4]!=tot:
        print(f"  ✗ مجموع السطر {nums[4]} ≠ عدد الصفوف {tot}"); bad=1
for m in re.finditer(r'\*\*(\d+)\s*✅\s*·\s*(\d+)\s*⚠\s*·\s*(\d+)\s*❌\s*·\s*(\d+)\s*🕐\s*=\s*(\d+)\*\*', body):
    nums=[int(x) for x in m.groups()]
    if nums!=[c['✅'],c['⚠'],c['❌'],c['🕐'],tot]:
        print(f"  ✗ محصلة معلنة {nums} تخالف المشتقّ {derived}"); bad=1
print("OK — المحصلة المشتقّة تطابق كل محصلة معلنة" if not bad else "REJECTED — محصلة مكتوبة يدًا تخالف جدولها")
sys.exit(bad)
PY
