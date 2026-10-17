#!/usr/bin/env bash
# إعادة اشتقاق محصلة تدقيق الامتثال من جدوله — واو م٢٢ «لا مصادر حقيقة متنافسة»
# السبب: كُتبت المحصلة يدًا بجانب الجدول ثلاث مرات فاختلفت عنه (١٠/٤ ثم ٩+٦+٢+٥ مقابل
# ١٠·٥·٢·٥). فالإصلاح الجذري ليس تصحيح الرقم بل **منع وجود رقم مكتوب يدًا**.
set -uo pipefail
F="${1:-guards/fixtures/tally-sample.md}"
# الافتراضي عيّنة **عامة**: فوثيقة التدقيق الحقيقية مختومة في vault/ (§٣/١) ولا يصلها CI.
# والخطأ المصحَّح: كان الافتراضي مسارًا مختومًا ففشلت الخطوة في CI بـ exit=2 («no file at inner/…»).
# وامتحانها محليًّا فقط كان **ادعاء خضرة بلا قياس في بيئة الحكم** (م١٠/٦).
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
print(f"  صفوف المعايير: {tot}")
bad=0
# المقام يُستخرج من الملف نفسه إن أعلنه، وإلا فعدد الصفوف هو المقام
m=re.search(r'المقام[^\d]*(\d+)', s)
declared=int(m.group(1)) if m else tot
if declared!=tot: print(f"  ✗ المقام المعلن {declared} ≠ عدد الصفوف {tot} — معيار بلا مصير أو صف زائد"); bad=1
else: print(f"  ✓ المقام مشتقّ: {declared} = عدد الصفوف")
# كل سطر محصلة مكتوب يدًا في الملف يجب أن يطابق المشتقّ
for m in re.finditer(r'(\d+)\s*[+·]\s*(\d+)\s*[+·]\s*(\d+)\s*[+·]\s*(\d+)\s*=\s*(\d+)', body):
    nums=[int(x) for x in m.groups()]
    if nums[:4]!=[c['✅'],c['⚠'],c['🕐'],c['❌']] and sorted(nums[:4])!=sorted([c['✅'],c['⚠'],c['❌'],c['🕐']]):
        print(f"  ✗ سطر جمع مكتوب يدًا {nums} يخالف الجدول {derived}"); bad=1
    elif nums[4]!=tot:
        print(f"  ✗ مجموع السطر {nums[4]} ≠ عدد الصفوف {tot}"); bad=1
# النمط الثالث — **جدول المحصلة العمودي** (`| ✅ مستوفى… | **١٠** | ٤٥٪ |`).
# مسبار م٢ (أ): كان المشتقّ يطابق نمطين سطريين فقط لا وجود لهما في الوثيقة الحقيقية،
# فدارت حلقتاه صفر مرة ومرّت طفرة ١٠⟶١٩ بـ exit=0. **فالحارس كان فراغيًّا على الوثيقة
# التي وُجد ليحرسها** — وكان أخضر على العيّنة العامة وحدها. والعبرة: الحارس يُمتحن
# على **الوثيقة الحقيقية** لا على عيّنته فقط (واردة-٠٠٤ §٦).
ARAB={'٠':'0','١':'1','٢':'2','٣':'3','٤':'4','٥':'5','٦':'6','٧':'7','٨':'8','٩':'9'}
def norm(t): return ''.join(ARAB.get(ch,ch) for ch in t)
vrows=re.findall(r'^\|\s*(✅|⚠|🕐|❌)[^|]*\|\s*\*\*([0-9٠-٩]+)\*\*\s*\|', body, re.M)
for sym,num in vrows:
    declared=int(norm(num))
    if declared!=c[sym]:
        print(f"  ✗ جدول المحصلة العمودي يعلن {sym}={declared} والجدول الرئيسي يعطي {c[sym]}")
        bad=1
if vrows:
    vt=sum(int(norm(n)) for _,n in vrows)
    if vt!=tot:
        print(f"  ✗ مجموع جدول المحصلة العمودي {vt} ≠ عدد الصفوف {tot}"); bad=1
    else:
        print(f"  ✓ جدول المحصلة العمودي: {len(vrows)} صفوف، مجموعها {vt} = عدد الصفوف")

for m in re.finditer(r'\*\*(\d+)\s*✅\s*·\s*(\d+)\s*⚠\s*·\s*(\d+)\s*❌\s*·\s*(\d+)\s*🕐\s*=\s*(\d+)\*\*', body):
    nums=[int(x) for x in m.groups()]
    if nums!=[c['✅'],c['⚠'],c['❌'],c['🕐'],tot]:
        print(f"  ✗ محصلة معلنة {nums} تخالف المشتقّ {derived}"); bad=1
print("OK — المحصلة المشتقّة تطابق كل محصلة معلنة" if not bad else "REJECTED — محصلة مكتوبة يدًا تخالف جدولها")
sys.exit(bad)
PY
