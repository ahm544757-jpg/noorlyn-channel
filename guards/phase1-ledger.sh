#!/usr/bin/env bash
# إقفال بنيتَي م٩/٣ من السجل الآلي — لا من الوثيقة.
# يسدّ الثغرات C0..C5 التي مرّت في v1 (حكم م٢ على v-017).
set -uo pipefail
T="${1:-inner/العمل/المرحلة-١-سجل-المطالب-v2.tsv}"
M="${2-inner/العمل/المرحلة-١-المنطق-v2.md}"
[ -f "$M" ] || M=""
[ -f "$T" ] || { echo "FAIL: no ledger at $T"; exit 2; }
# سجل الاكتشافات بجانب السجل (v2) أو عيّنة CI
DIR=$(dirname "$T")
D=""
for cand in "$DIR/المرحلة-١-سجل-الاكتشافات-v2.tsv" "$DIR/discoveries-sample.tsv"; do
  [ -f "$cand" ] && D="$cand" && break
done
python3 - "$T" "${M:-}" "${D:-}" <<'PY'
import sys, collections, re, hashlib, os
T, M, D = sys.argv[1], sys.argv[2] if len(sys.argv)>2 else "", sys.argv[3] if len(sys.argv)>3 else ""
DISP={'in_plan','owner_package','representation_blocker','deferred_with_reason','out_of_scope_with_reason'}
BINS={'plan','owner','representation','knowledge_gap'}
KINDS={'parent','member','standalone','prose'}
REQ=['id','kind','area','disposition','rule','reason','text']
bad=0
def fail(msg):
    global bad
    print(f"  ✗ {msg}"); bad=1
def ok(msg):
    print(f"  ✓ {msg}")

raw=open(T,encoding='utf-8').read()
lines=[l for l in raw.split('\n') if l.strip()]
rows=[l.split('\t') for l in lines]
hdr, body = rows[0], rows[1:]
tot=len(body); W=len(hdr)
col={name:i for i,name in enumerate(hdr)}

# عرض الصف
narrow=[(r[col.get('id',0)] if r else '?', len(r)) for r in body if len(r)!=W]
if narrow: fail(f"{len(narrow)} صفًّا عرضه ≠ {W} أعمدة: {narrow[:4]}")
else: ok(f"كل الصفوف بعرض الترويسة: {W} عمودًا × {tot} صفوف")

missing=[c for c in ['id','disposition'] if c not in col]
if missing:
    print(f"FAIL: السجل بلا أعمدة {missing}"); sys.exit(2)

def g(r,k,default=''):
    i=col.get(k)
    return r[i] if i is not None and i<len(r) else default

# C5: فراغ الحقول الإلزامية
empty=[]
for r in body:
    for c in REQ:
        if c in col and not g(r,c).strip():
            empty.append((g(r,'id'), c)); break
if empty: fail(f"حقول إلزامية فارغة: {empty[:6]}")
else: ok("لا حقل إلزامي فارغ (id/kind/area/disposition/rule/reason/text)")

# المصائر — C0: valid_cnt من DISP فقط لا sum(Counter) على كل الصفوف
orph=[g(r,'id') for r in body if g(r,'disposition') not in DISP]
cnt=collections.Counter(g(r,'disposition') for r in body)
valid_cnt=sum(v for k,v in cnt.items() if k in DISP)
ids=collections.Counter(g(r,'id') for r in body)
dup=[k for k,v in ids.items() if v>1]
print(f"  total_extracted_rows     = {tot}")
print(f"  classified_requirements  = {valid_cnt}")
print(f"  أيتام (خارج المفردات)    = {len(orph)}")
print(f"  معرّفات مكررة            = {len(dup)}")
for d in sorted(DISP): print(f"    {d:32} {cnt.get(d,0):4}")
if orph: fail(f"أيتام: {orph[:5]}")
if dup: fail(f"تكرار معرّف: {dup[:5]}")
if valid_cnt!=tot: fail(f"classified ({valid_cnt}) ≠ total ({tot}) — C0")  # يرفض مصيرًا خارج DISP
else: ok("البنية الأولى: classified = total، صفر يتيم، صفر تكرار")

# الأنواع
kcnt=collections.Counter(g(r,'kind') for r in body)
unk=[k for k in kcnt if k not in KINDS]
if unk: fail(f"نوع خارج المفردات: {unk}")
atomic_col='atomic' in col
n_atomic=sum(1 for r in body if g(r,'atomic')=='yes') if atomic_col else tot

# C5: تكامل الأبوة
par={g(r,'id') for r in body if g(r,'kind')=='parent'}
mem_par={g(r,'parent') for r in body if g(r,'kind')=='member'}
dang=sorted(p for p in mem_par if p and p not in par)
has_child={g(r,'parent') for r in body if g(r,'parent')}
nopar=sorted(par-has_child)
if dang: fail(f"member يشير إلى أب غير موجود: {dang[:6]}")
else: ok("كل member يشير إلى parent موجود")
if nopar: fail(f"parent بلا أبناء: {nopar[:6]}")
else: ok("كل parent له ≥ ١ ابن — كان سيكشف P-0119 وS-0335")

# ── الاكتشافات (البنية الثانية) — تفعيل BINS (C1) ──
dcnt=collections.Counter(); d_tot=0; d_closed=0
if D:
    drows=[l.split('\t') for l in open(D,encoding='utf-8').read().split('\n') if l.strip()]
    dh, db = drows[0], drows[1:]
    dcol={n:i for i,n in enumerate(dh)}
    if 'route' not in dcol or 'id' not in dcol:
        fail("سجل الاكتشافات بلا عمودي id/route")
    else:
        d_tot=len(db)
        dcnt=collections.Counter(r[dcol['route']] for r in db)
        bad_bin=[r[dcol['id']] for r in db if r[dcol['route']] not in BINS]
        dids=collections.Counter(r[dcol['id']] for r in db)
        ddup=[k for k,v in dids.items() if v>1]
        if 'status' in dcol:
            d_closed=sum(1 for r in db if r[dcol['status']]=='closed')
        if bad_bin: fail(f"اكتشاف بمسار خارج BINS: {bad_bin[:4]}")
        if ddup: fail(f"اكتشاف مكرر: {ddup[:4]}")
        if sum(v for k,v in dcnt.items() if k in BINS)!=d_tot:
            fail("routed_discoveries ≠ total_discoveries")
        else:
            ok(f"البنية الثانية: {d_tot} اكتشافًا، صفر يتيم مسار")
            for b in sorted(BINS): print(f"    {b:20} {dcnt.get(b,0):4}")
else:
    print("  · لا سجل اكتشافات بجانب السجل — تُتخطى البنية الثانية في TSV")

# ── الوثيقة ──
if not M:
    print("  · لا وثيقة — تُتخطى مطابقة الأرقام (في CI تُمرَّر العيّنة العامة)")
else:
    s=open(M,encoding='utf-8').read()
    def find_nums(key):
        # **key** | **123**  أو | `key` | 123 |
        pats=[
            rf'\*\*{re.escape(key)}\*\*\s*\|\s*\*\*(\d+)\*\*',
            rf'\|\s*`?{re.escape(key)}`?\s*\|\s*\*?\*?(\d+)\*?\*?\s*\|',
        ]
        hits=[]
        for p in pats:
            hits += [int(x) for x in re.findall(p, s)]
        return hits
    # C2: غياب السطر = فشل لا ✓ فراغي
    def require(key, expected, label=None):
        hits=find_nums(key)
        if not hits:
            fail(f"الوثيقة لا تعلن `{key}` أصلًا (C2 فراغ) — المرتقب {expected}")
            return
        for h in hits:
            if h!=expected:
                fail(f"الوثيقة تعلن {key}={h} والسجل يعطي {expected}")
                return
        ok(f"{label or key} = {expected} في الوثيقة والسجل")
    require('classified_requirements', valid_cnt)
    if find_nums('total_extracted_rows'):
        require('total_extracted_rows', tot)
    if find_nums('total_requirements'):
        require('total_requirements', tot)
    if not find_nums('total_extracted_rows') and not find_nums('total_requirements'):
        fail("لا total_extracted_rows ولا total_requirements في الوثيقة (C2)")
    if atomic_col:
        require('atomic_requirements', n_atomic)
    # C3: أعداد المصائر الخمسة والأنواع
    for d in sorted(DISP):
        require(d, cnt.get(d,0))
    for k in ['parent','member','standalone']:
        require(k, kcnt.get(k,0))
    if kcnt.get('prose',0):
        require('prose', kcnt['prose'])
    # C4: المناطق — كل منطقة في السجل يجب أن يظهر عددها
    acnt=collections.Counter(g(r,'area') for r in body)
    area_fail=0
    for a,c in sorted(acnt.items()):
        # | A-قراءة-العربية | 17 |
        hits=[int(x) for x in re.findall(rf'\|\s*{re.escape(a)}\s*\|\s*(\d+)\s*\|', s)]
        if not hits:
            fail(f"المنطقة {a}={c} غائبة عن جدول §٦ (C4)"); area_fail=1
        elif hits[0]!=c:
            fail(f"المنطقة {a}: الوثيقة {hits[0]} والسجل {c} (C4)"); area_fail=1
    if not area_fail: ok(f"جدول المناطق يطابق السجل ({len(acnt)} منطقة)")
    # بصمة السجل
    sha=hashlib.sha256(open(T,'rb').read()).hexdigest()
    if sha not in s and sha[:16] not in s:
        fail(f"بصمة السجل {sha[:16]}… غير موجودة في الوثيقة (C4)")
    else:
        ok(f"بصمة السجل في الوثيقة تطابق الملف ({sha[:16]}…)")
    # C1: الاكتشافات في الوثيقة
    if d_tot:
        require('total_discoveries', d_tot)
        require('routed_discoveries', d_tot)
        for b in sorted(BINS):
            require(b, dcnt.get(b,0))
        # كل د-XX له مسار
        missing_ids=[]
        for r in db:
            did=r[dcol['id']]
            if did not in s:
                missing_ids.append(did)
        if missing_ids: fail(f"اكتشافات في TSV غائبة عن الوثيقة: {missing_ids[:4]}")
        else: ok("كل معرّف اكتشاف في الوثيقة")

print("OK — البنيتان مقفلتان" if not bad else "REJECTED — الإقفال ناقص (م٩/٣)")
sys.exit(bad)
PY
