# بيانات مصحف المدينة (mushaf-v1.json) فيها رموز كل سطر متجمّعة، وبعض الكلمات ليها أكتر من رمز
# (الكلمة + علامة الوقف بعدها، أو علامة الحزب ۞ قبلها). السكريبت ده بيحسب عدد رموز كل كلمة (w)
# من نص Tanzil (علامات الوقف فيه منفصلة)، عشان الكلمة تتعرض حتة واحدة والضغط عليها يجيب الآية الصح.
# اتطابق في ٨٨١٢ سطر من ٨٨٢٠؛ الـ ٨ الباقيين بيتظبطوا تقريبيًا (العرض سليم، وممكن كلمة تتحسب على جارتها).
# التشغيل من فولدر murattil:  python3 tool/add_word_glyphs.py 2 assets/quran/mushaf-v1.json
import json,collections,sys
d=json.load(open('assets/quran/mushaf-v1.json'))
surahs=json.load(open('assets/quran/surahs.json'))
starts={s['start'] for s in surahs}
s9=surahs[8]['start']
ayat=[]
for s in surahs: ayat+=json.load(open(f'assets/quran/text/{s["number"]:03d}.json'))['ayat']
def is_mark(tok): return all(0x06D6<=ord(c)<=0x06ED for c in tok)
def mpw(g, hizb=1):
    toks=ayat[g-1].split()
    if g in starts and g!=1 and g!=s9 and toks[0].endswith('سْمِ'): toks=toks[4:]
    # كلمات بتتعدّ كلمة واحدة في بيانات المصحف
    out=[]; i=0
    while i<len(toks):
        if i+1<len(toks) and (toks[i],toks[i+1]) in {('بَعْدَ','مَا'),('إِلْ','يَاسِينَ')}: out.append(toks[i]+' '+toks[i+1]); i+=2
        else: out.append(toks[i]); i+=1
    words=[]; pending=0
    for tok in out:
        if is_mark(tok):
            if tok=='۞': pending+=hizb
            elif words: words[-1]+=1
        else: words.append(pending + (1 if ' ' in tok else 0)); pending=0
    return words
mode=int(sys.argv[1]) if len(sys.argv)>1 else 1
# per-line check: glyphs per word = 1 + marks
cursor=collections.defaultdict(int); bad=[]; tot=0
newpages=[]
for p in d['pages']:
    nl=[]
    for l in p['l']:
        if l['k']!='t': nl.append(l); continue
        counts=[]
        for g,e in zip(l['a'],l['e']):
            if e: counts.append(1); continue
            m=mpw(g,mode); i=cursor[g]; cursor[g]+=1
            counts.append(1+m[i])
        tot+=1
        diff=len(l['c'])-sum(counts)
        if diff!=0:
            bad.append((p['p'],l['n'],sum(counts),len(l['c'])))
            while diff<0:
                i=max(range(len(counts)),key=lambda k:counts[k]); counts[i]-=1; diff+=1
            if diff>0:
                i=max(k for k in range(len(counts)) if not l['e'][k]) if any(not x for x in l['e']) else len(counts)-1
                counts[i]+=diff
        assert sum(counts)==len(l['c']) and all(c>=1 for c in counts)
        nl.append({**l,'w':counts})
    newpages.append({'p':p['p'],'l':nl})
print('lines',tot,'bad',len(bad),bad[:10])
if len(sys.argv)>2:
    json.dump({'source':d['source']+'; word glyph counts (w) from Tanzil pause marks','pages':newpages},open(sys.argv[2],'w'),ensure_ascii=False,separators=(',',':'))
