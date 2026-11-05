"""W2-7a batch2 previews. Area (BOX) downscale + CIELAB nearest palette, no dither, PNG IHDR/IDAT/IEND only, 8-bit RGBA.
#00ff00 backgrounds keyed to alpha before downscale (premultiplied box average, alpha >= threshold -> opaque)."""
import json, sys, zlib, struct
import numpy as np
from PIL import Image
SRC = "/workspace/batch2/originals"
OUT = "/workspace/flow-img/w2-7a/batch2/previews"
BASE = ["f4e2b0","d9c49a","1f1712","3a2a1e","5a3f2a","ffd25a","b0262a","a07a2c","2f6b5a","2f4670","9aa4aa"]
FRAME = BASE + ["8c6a44","d9a520"]   # §4 frame_person, frame_gold (frame_event #5a3f2a / gold_glow #ffd25a already in BASE)
def lab(a):
    a=a/255.0; a=np.where(a>0.04045,((a+0.055)/1.055)**2.4,a/12.92)
    M=np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])
    xyz=a@M.T/np.array([0.95047,1,1.08883])
    f=np.where(xyz>0.008856,np.cbrt(xyz),7.787*xyz+16/116)
    return np.stack([116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])],-1)
def quant(rgb, pal):
    P=np.array([[int(h[i:i+2],16) for i in (0,2,4)] for h in pal],float)
    d=((lab(rgb.astype(float))[...,None,:]-lab(P))**2).sum(-1)
    return P[d.argmin(-1)].astype(np.uint8)
def chunk(t,d): return struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d)&0xffffffff)
def save(rgba, path):
    h,w,_=rgba.shape; b=rgba.astype(np.uint8).tobytes()
    raw=b"".join(b"\x00"+b[y*w*4:(y+1)*w*4] for y in range(h))
    open(path,"wb").write(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(raw,9))+chunk(b"IEND",b""))
def load(i): return np.asarray(Image.open(f"{SRC}/{i}.jpg").convert("RGB"))
def greenmask(a):
    r,g,b=[a[...,k].astype(int) for k in range(3)]
    return ~((g>90)&(g-r>50)&(g-b>50))          # True = keep (not green)
def box(a, size):  # opaque area downscale
    return np.asarray(Image.fromarray(a).resize(size,Image.BOX),float)
def box_alpha(a, m, size, thr=0.5):
    mf=m.astype(np.float32); pm=a.astype(np.float32)*mf[...,None]
    A=np.asarray(Image.fromarray(mf,"F").resize(size,Image.BOX))
    C=np.stack([np.asarray(Image.fromarray(pm[...,k],"F").resize(size,Image.BOX)) for k in range(3)],-1)
    rgb=np.where(A[...,None]>1e-6,C/np.maximum(A[...,None],1e-6),0)
    return rgb, A>=thr
def rgba(rgb, pal, keep=None):
    q=quant(rgb,pal); al=np.full(q.shape[:2],255,np.uint8) if keep is None else np.where(keep,255,0).astype(np.uint8)
    q=q.copy(); 
    if keep is not None: q[~keep]=0
    return np.dstack([q,al])
def center_crop(a, ar):
    H,W=a.shape[:2]
    if W/H>ar: cw=int(round(H*ar)); l=(W-cw)//2; return a[:,l:l+cw]
    ch=int(round(W/ar)); t=(H-ch)//2; return a[t:t+ch]
def bbox(m):
    ys,xs=np.nonzero(m); return xs.min(),ys.min(),xs.max()+1,ys.max()+1
report={}
# --- counter backgrounds: measured in the plain 16:9 crop at 320x180; align by shifting up so counter top -> y=100,
#     bottom rows filled by mirroring the under-counter strip (桌下). Door x span already ~112-208, scale kept 1.0.
MEAS={"I-101":dict(door_x=(111,209),door_top=21,counter_top=110),
      "I-102":dict(door_x=(113,209),door_top=29,counter_top=116),
      "I-103":dict(door_x=(113,207),door_top=29,counter_top=116)}
for i,m in MEAS.items():
    a=center_crop(load(i),16/9); H=a.shape[0]
    shift=m["counter_top"]-100; sp=int(round(shift*H/180))
    a2=np.concatenate([a[sp:], a[H-sp:][::-1]],0) if sp>0 else a
    save(rgba(box(a,(320,180)),BASE), f"{OUT}/{i}_unaligned.png")
    save(rgba(box(a2,(320,180)),BASE), f"{OUT}/{i}.png")
    report[i]=dict(measured=m, shift_up=shift, after=dict(door_x=m["door_x"],door_top=m["door_top"]-shift,counter_top=100),
                   bottom_mirrored_rows=shift)
# --- portraits 48x64
for i in ["I-104","I-105","I-106"]:
    save(rgba(box(center_crop(load(i),3/4),(48,64)),BASE), f"{OUT}/{i}.png")
# --- walk sheets: split 4x4 equal cells, key green, uniform per-sheet scale, feet at (8,30)
for i in ["I-107","I-108","I-109"]:
    a=load(i); H,W=a.shape[:2]; cw,ch=W/4,H/4; m=greenmask(a)
    cells=[]
    for r in range(4):
        for c in range(4):
            y0,y1,x0,x1=int(r*ch),int((r+1)*ch),int(c*cw),int((c+1)*cw)
            cm=m[y0:y1,x0:x1].copy()
            # ignore tiny specks
            bx=bbox(cm); cells.append((r,c,y0,x0,bx))
    s=min(min(16/(b[2]-b[0]),30/(b[3]-b[1])) for *_,b in cells)
    sheet=np.zeros((128,64,4),np.uint8); info=[]
    for r,c,y0,x0,(l,t,rr,bb) in cells:
        sub=a[y0+t:y0+bb,x0+l:x0+rr]; sm=m[y0+t:y0+bb,x0+l:x0+rr]
        if r==1: sub,sm=sub[:,::-1].copy(),sm[:,::-1].copy()   # Flow drew rows 2 and 3 both facing right; mirror row 2 -> facing left
        w=max(1,int(round((rr-l)*s))); h=max(1,int(round((bb-t)*s)))
        rgb,keep=box_alpha(sub,sm,(w,h)); px=rgba(rgb,BASE,keep)
        ox=c*16+8-w//2; oy=r*32+31-h
        ox=max(c*16,min(ox,c*16+16-w)); oy=max(r*32,oy)
        sheet[oy:oy+h,ox:ox+w]=px[:min(h,32),:min(w,16)]
        info.append((w,h))
    save(sheet,f"{OUT}/{i}.png"); report[i]=dict(scale=round(s,4),frame_sizes=info)
# --- items 64x64: key, bbox, longest side 60, centred
for i in ["I-110","I-111","I-112"]:
    a=load(i); m=greenmask(a); l,t,r,b=bbox(m); sub,sm=a[t:b,l:r],m[t:b,l:r]
    s=60/max(r-l,b-t); w,h=int(round((r-l)*s)),int(round((b-t)*s))
    rgb,keep=box_alpha(sub,sm,(w,h)); px=rgba(rgb,BASE,keep)
    out=np.zeros((64,64,4),np.uint8); ox,oy=(64-w)//2,(64-h)//2; out[oy:oy+h,ox:ox+w]=px
    save(out,f"{OUT}/{i}.png")
# --- frames 36x50: key, bbox of frame -> exactly 36x50, lower alpha threshold to keep thin borders
for i in ["I-113","I-114","I-115"]:
    a=load(i); m=greenmask(a); l,t,r,b=bbox(m)
    rgb,keep=box_alpha(a[t:b,l:r],m[t:b,l:r],(36,50),thr=0.35); save(rgba(rgb,FRAME,keep),f"{OUT}/{i}.png")
    report[i]=dict(bbox_src=(int(l),int(t),int(r),int(b)),bbox_aspect=round((r-l)/(b-t),3))
# --- illus 64x48: opaque paper; crop to subject bbox + margin, expanded to 4:3
for i in ["I-116","I-117","I-118"]:
    a=load(i); H,W=a.shape[:2]; paper=np.median(a[:20].reshape(-1,3),0)
    diff=np.abs(a.astype(int)-paper).sum(-1)>60; l,t,r,b=bbox(diff)
    cx,cy=(l+r)/2,(t+b)/2; w=max(r-l,(b-t)*4/3)*1.25; h=w*3/4
    w=min(w,W); h=min(h,H); w=min(w,h*4/3); h=w*3/4
    x0=int(max(0,min(cx-w/2,W-w))); y0=int(max(0,min(cy-h/2,H-h)))
    sub=a[y0:y0+int(h),x0:x0+int(w)]
    save(rgba(box(sub,(64,48)),BASE),f"{OUT}/{i}.png"); report[i]=dict(crop=(x0,y0,int(w),int(h)))
json.dump(report,open(f"{OUT}/../report.json","w"),indent=1,default=int)
print(json.dumps(report,default=int)[:3000])
