import math, os, sys
from PIL import Image, ImageDraw, ImageFilter
S = 1024  # work canvas
PINE=(30,58,110); PINE_D=(15,31,61); PINE_L=(35,92,134); GOLD=(226,161,59); GOLD_L=(245,211,148); CREAM=(252,248,238); TEAL=(42,157,154)

def star_points(cx, cy, r_out, r_in, n=8, rot=-math.pi/2):
    pts=[]
    for i in range(n*2):
        r = r_out if i%2==0 else r_in
        a = rot + i*math.pi/n
        pts.append((cx+math.cos(a)*r, cy+math.sin(a)*r))
    return pts

def background(size):
    img = Image.new('RGB',(size,size))
    d = ImageDraw.Draw(img)
    for y in range(size):  # diagonal-ish vertical gradient
        t = y/size
        c = tuple(int(PINE_L[k]*(1-t)+PINE_D[k]*t) for k in range(3))
        d.line([(0,y),(size,y)], fill=c)
    # subtle pattern of small stars
    ov = Image.new('RGBA',(size,size),(0,0,0,0)); od=ImageDraw.Draw(ov)
    cell=size//6
    for yy in range(-cell, size+cell, cell):
        for xx in range(-cell, size+cell, cell):
            od.polygon(star_points(xx+cell/2, yy+cell/2, cell*.34, cell*.22), outline=(255,255,255,18), width=max(1,size//400))
    img = Image.alpha_composite(img.convert('RGBA'), ov)
    return img

def arch(cx, top, w, h):
    """قوس محراب: مستطيل تحت وقوس مدبّب فوق (مضلع ناعم)"""
    left, right, bottom = cx - w/2, cx + w/2, top + h
    shoulder = top + h*0.42
    pts=[(left,bottom),(left,shoulder)]
    n=40
    for i in range(n+1):  # منحنى من الكتف الشمال للقمة
        t=i/n; x=(1-t)**2*left+2*(1-t)*t*left+t*t*cx; y=(1-t)**2*shoulder+2*(1-t)*t*(top+h*0.12)+t*t*top; pts.append((x,y))
    for i in range(n+1):
        t=i/n; x=(1-t)**2*cx+2*(1-t)*t*right+t*t*right; y=(1-t)**2*top+2*(1-t)*t*(top+h*0.12)+t*t*shoulder; pts.append((x,y))
    pts.append((right,bottom))
    return pts

def foreground(size, scale=1.0):
    """محراب كهرماني + محراب فيروزي جوّه + كتاب مفتوح أبيض"""
    img = Image.new('RGBA',(size,size),(0,0,0,0))
    cx=size/2; W=size*0.40*scale; H=size*0.50*scale; top=size/2-H/2
    glow = Image.new('RGBA',(size,size),(0,0,0,0)); gd=ImageDraw.Draw(glow)
    gd.polygon(arch(cx, top-size*0.01, W*1.08, H*1.04), fill=(245,211,148,80))
    glow = glow.filter(ImageFilter.GaussianBlur(size*0.03))
    img = Image.alpha_composite(img, glow); d = ImageDraw.Draw(img)
    d.polygon(arch(cx, top, W, H), fill=GOLD)
    d.polygon(arch(cx, top+H*0.10, W*0.74, H*0.84), fill=TEAL)
    # كتاب مفتوح
    bw=W*0.30; bh=H*0.17; by=top+H*0.60
    for side in (-1,1):
        page=[(cx,by+bh*0.12),(cx+side*bw,by),(cx+side*bw,by+bh),(cx,by+bh*1.12)]
        d.polygon(page, fill=CREAM)
        for k in range(1,4):
            yy=by+bh*(0.22*k+0.06)
            d.line([(cx+side*bw*0.16,yy+bh*0.06),(cx+side*bw*0.85,yy-bh*0.02)], fill=GOLD, width=max(1,int(size*0.005)))
    d.line([(cx,by+bh*0.12),(cx,by+bh*1.12)], fill=PINE_D, width=max(2,int(size*0.008)))
    # نجمة صغيرة فوق الكتاب
    r=W*0.07; sy=top+H*0.36
    star=[]
    for i in range(16):
        rr=r if i%2==0 else r*0.45; a=-math.pi/2+i*math.pi/8; star.append((cx+math.cos(a)*rr, sy+math.sin(a)*rr))
    d.polygon(star, fill=GOLD_L)
    return img

def full_icon(size, rounded=True):
    bg = background(size)
    fg = foreground(size, scale=1.3)
    img = Image.alpha_composite(bg, fg)
    if rounded:
        mask = Image.new('L',(size,size),0)
        ImageDraw.Draw(mask).rounded_rectangle([0,0,size-1,size-1], radius=int(size*0.22), fill=255)
        out = Image.new('RGBA',(size,size),(0,0,0,0)); out.paste(img,(0,0),mask); return out
    return img

out = sys.argv[1]
res = os.path.join(out,'android/app/src/main/res')
# legacy launcher icons (rounded square)
for name,px in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    os.makedirs(f'{res}/mipmap-{name}',exist_ok=True)
    full_icon(S).resize((px,px),Image.LANCZOS).save(f'{res}/mipmap-{name}/ic_launcher.png')
    # adaptive foreground: 108dp canvas
    fpx = int(px*108/48)
    fg = foreground(S, scale=1.0).resize((fpx,fpx),Image.LANCZOS)
    fg.save(f'{res}/mipmap-{name}/ic_launcher_foreground.png')
    background(S).resize((fpx,fpx),Image.LANCZOS).save(f'{res}/mipmap-{name}/ic_launcher_background.png')
os.makedirs(f'{res}/mipmap-anydpi-v26',exist_ok=True)
xml='''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml','w').write(xml)
# store listing icon + splash logo
os.makedirs(os.path.join(out,'branding'),exist_ok=True)
full_icon(S, rounded=False).resize((512,512),Image.LANCZOS).convert('RGB').save(os.path.join(out,'branding/play-store-icon-512.png'))
full_icon(S).resize((512,512),Image.LANCZOS).save(os.path.join(out,'branding/icon-preview.png'))
for name,px in [('mdpi',96),('hdpi',144),('xhdpi',192),('xxhdpi',288),('xxxhdpi',384)]:
    os.makedirs(f'{res}/drawable-{name}',exist_ok=True)
    foreground(S, scale=1.3).resize((px,px),Image.LANCZOS).save(f'{res}/drawable-{name}/splash_logo.png')
print('ok')
