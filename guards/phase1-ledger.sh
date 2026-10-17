#!/usr/bin/env bash
# إقفال بنيتَي م٩/٣ من السجل الآلي — لا من الوثيقة (فالمشتقّ يحرس المشتقَّ منه لا العكس).
# يرفض: قيمة خارج المفردات · تعدد مصير · يتيمًا · classified ≠ total · رقمًا يدويًّا في الوثيقة يخالف السجل.
set -uo pipefail
T="${1:-inner/العمل/المرحلة-١-سجل-المطالب-v1.tsv}"
# الافتراضي السجل الحقيقي، ويُمرَّر في CI مسار العيّنة **العامة** — فالسجل الحقيقي
# مختوم في vault/ (§٣/١) ولا يصله CI، والمفتاح لا يدخل CI أبدًا.
# (الدرس من فشل c3061cb3: خطوة تشير إلى مسار مختوم ⟹ exit=2 وتخطٍّ لأربع خطوات.)
M="${2-inner/العمل/المرحلة-١-المنطق-v1.md}"
[ -f "$M" ] || M=""
[ -f "$T" ] || { echo "FAIL: no ledger at $T"; exit 2; }
python3 - "$T" "${M:-}" <<'PY'
import sys, collections
T=sys.argv[1]; M=sys.argv[2] if len(sys.argv)>2 else None
DISP={'in_plan','owner_package','representation_blocker','deferred_with_reason','out_of_scope_with_reason'}
BINS={'plan','owner','representation','knowledge_gap'}
rows=[l.rstrip('\n').split('\t') for l in open(T,encoding='utf-8').read().split('\n') if l.strip()]
hdr=rows[0]; body=rows[1:]
bad=0
try:
    i_id=hdr.index('id'); i_d=hdr.index('disposition')
except ValueError:
    print("FAIL: السجل بلا عمودي id/disposition"); sys.exit(2)
tot=len(body)
W=len(hdr)
narrow=[(r[i_id],len(r)) for r in body if len(r)!=W]
if narrow:
    print(f"  ✗ {len(narrow)} صفًّا عرضه ≠ {W} أعمدة: {narrow[:4]}"); bad=1
else:
    print(f"  ✓ كل الصفوف بعرض الترويسة: {W} عمودًا × {tot} صفوف")
orph=[r for r in body if r[i_d] not in DISP]
cnt=collections.Counter(r[i_d] for r in body)
ids=collections.Counter(r[i_id] for r in body)
dup=[k for k,v in ids.items() if v>1]
print(f"  total_requirements      = {tot}")
print(f"  classified_requirements = {sum(cnt.values())}")
print(f"  أيتام (خارج المفردات)   = {len(orph)}")
print(f"  معرّفات مكررة           = {len(dup)}")
for d in sorted(DISP): print(f"    {d:32} {cnt.get(d,0):4}")
if orph: print(f"  ✗ أيتام: {[r[i_id] for r in orph][:5]}"); bad=1
if dup:  print(f"  ✗ تكرار معرّف: {dup[:5]}"); bad=1
if sum(cnt.values())!=tot: print(f"  ✗ classified ≠ total"); bad=1
if not bad: print("  ✓ البنية الأولى مقفلة: classified = total، صفر يتيم، صفر تكرار")
# الوثيقة: أي رقم total معلن يجب أن يطابق السجل
if M:
    try: s=open(M,encoding='utf-8').read()
    except FileNotFoundError: s=''
    import re
    for m in re.finditer(r'\*\*total_requirements\*\*\s*\|\s*\*\*(\d+)\*\*', s):
        if int(m.group(1))!=tot: print(f"  ✗ الوثيقة تعلن total={m.group(1)} والسجل يعطي {tot}"); bad=1
    for m in re.finditer(r'\*\*classified_requirements\*\*\s*\|\s*\*\*(\d+)\*\*', s):
        if int(m.group(1))!=sum(cnt.values()): print(f"  ✗ الوثيقة تعلن classified={m.group(1)}"); bad=1
    if not bad: print("  ✓ أرقام الوثيقة تطابق السجل (لا مصدران متنافسان — م٢٢)")
print("OK — البنيتان مقفلتان" if not bad else "REJECTED — الإقفال ناقص (م٩/٣)")
sys.exit(bad)
PY
