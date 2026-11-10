import re,sys
src=open('ios-native/NeedsMe/Theme.swift').read()
def lum(h):
    c=[((h>>s)&255)/255 for s in (16,8,0)]
    c=[x/12.92 if x<=0.03928 else ((x+0.055)/1.055)**2.4 for x in c]
    return .2126*c[0]+.7152*c[1]+.0722*c[2]
def ratio(a,b):
    la,lb=sorted([lum(a),lum(b)],reverse=True); return (la+.05)/(lb+.05)
bad=0
print("### Contrast check (WCAG AA needs 4.5)")
for m in re.finditer(r'static let (\w+) = Palette\((.*)\)',src):
    n=m.group(1); v=dict((k,int(x,16)) for k,x in re.findall(r'(\w+): Color\(hex: (0x[0-9A-Fa-f]+)\)',m.group(2)))
    for fg,bg in [('ink','bg'),('ink','card'),('soft','bg'),('soft','card'),('ink','chip'),('accentInk','accent')]:
        r=ratio(v[fg],v[bg]); ok=r>=4.5; bad+=not ok
        print(f"- {n}: {fg} on {bg} = {r:.2f} {'ok' if ok else 'FAIL'}")
print("RESULT:", "FAIL" if bad else "all pass")
sys.exit(1 if bad else 0)
