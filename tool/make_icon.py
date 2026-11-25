import math, os, sys
from PIL import Image, ImageDraw, ImageFilter
S = 1024  # work canvas
PINE=(15,92,79); PINE_D=(10,67,57); PINE_L=(22,112,95); GOLD=(201,165,76); GOLD_L=(235,213,143); CREAM=(252,248,238)

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

def foreground(size, scale=1.0):
    """النجمة الذهبية + الكتاب المفتوح، في منتصف المساحة الآمنة"""
    img = Image.new('RGBA',(size,size),(0,0,0,0))
    d = ImageDraw.Draw(img)
    cx=cy=size/2
    R = size*0.30*scale
    # glow
    glow = Image.new('RGBA',(size,size),(0,0,0,0)); gd=ImageDraw.Draw(glow)
    gd.ellipse([cx-R*1.05,cy-R*1.05,cx+R*1.05,cy+R*1.05], fill=(233,207,139,90))
    glow = glow.filter(ImageFilter.GaussianBlur(size*0.04))
    img = Image.alpha_composite(img, glow); d = ImageDraw.Draw(img)
    d.polygon(star_points(cx,cy,R,R*0.74), fill=GOLD)
    d.polygon(star_points(cx,cy,R*0.88,R*0.65), outline=GOLD_L, width=max(2,int(size*0.006)))
    # open book
    bw = R*0.58; bh = R*0.42; top = cy - bh*0.55
    lw = max(2,int(size*0.012))
    for side in (-1,1):
        x0 = cx; x1 = cx + side*bw
        page = [(x0, top+bh*0.12), (x1, top), (x1, top+bh), (x0, top+bh*1.12)]
        d.polygon(page, fill=CREAM)
        # lines on pages
        for k in range(1,4):
            yy = top + bh*(0.22*k+0.06)
            d.line([(x0+side*bw*0.16, yy+bh*0.06), (x1-side*bw*0.12, yy-bh*0.02)], fill=(201,165,76), width=max(1,int(size*0.006)))
    d.line([(cx, top+bh*0.12),(cx, top+bh*1.12)], fill=PINE_D, width=lw)
    # small stand under book
    d.polygon([(cx-bw*0.55, top+bh*1.30),(cx, top+bh*1.05),(cx+bw*0.55, top+bh*1.30),(cx, top+bh*1.55)], fill=PINE_D)
    return img

def full_icon(size, rounded=True):
    bg = background(size)
    fg = foreground(size, scale=1.25)
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
