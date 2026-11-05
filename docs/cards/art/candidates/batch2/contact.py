from PIL import Image, ImageDraw, ImageFont
import numpy as np
P="/workspace/flow-img/w2-7a/batch2/previews"
def font(sz):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf","/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        try: return ImageFont.truetype(f,sz)
        except Exception: pass
    return ImageFont.load_default()
F,FS=font(28),font(40)
rows=[("Counter bg 320x180, one scene relit (x4)",[("I-101","bg.counter.day"),("I-101_dusk","bg.counter.dusk"),("I-101_night","bg.counter.night")]),
      ("Portrait 48x64 (x4)",[("I-104","portrait.linsao"),("I-105","portrait.suanming"),("I-106","portrait.postman")]),
      ("Walk sheet 64x128, 4x4 frames 16x32 (x4)",[("I-107","walk.ex_newsboy"),("I-108","walk.ex_porter"),("I-109","walk.stranger_peddler")]),
      ("Item 64x64 (x4)",[("I-110","item.jewelry.hairpin"),("I-111","item.utensils.clock"),("I-112","item.jewelry.jade")]),
      ("Card frame 36x50 nine [6,6,6,6] (x4)",[("I-113","frame.person"),("I-114","frame.gold"),("I-115","frame.event")]),
      ("Small illus 64x48 (x4)",[("I-116","illus.es.shopfront"),("I-117","illus.ev.any.fortune_teller"),("I-118","illus.nt.family_dinner")])]
G=40; blocks=[]
for title,items in rows:
    ims=[Image.open(f"{P}/{i}.png").convert("RGBA") for i,_ in items]
    ims=[im.resize((im.width*4,im.height*4),Image.NEAREST) for im in ims]
    h=max(im.height for im in ims)+85; w=sum(max(im.width,440)+G for im in ims)+G
    blocks.append((title,items,ims,w,h))
W=max(b[3] for b in blocks); H=60+sum(b[4]+70 for b in blocks)
sheet=Image.new("RGBA",(W,H),(60,60,60,255)); d=ImageDraw.Draw(sheet)
d.text((G,12),"Dehoudang W2-7a batch2 candidates (Flow / Nano Banana 2.1, AI art for the AI-disclosed build, #212) - pick one style per row",font=F,fill=(255,255,255))
y=60
for title,items,ims,w,h in blocks:
    d.text((G,y+10),title,font=FS,fill=(255,210,90)); y+=70; x=G
    for (i,mid),im in zip(items,ims):
        # checkerboard behind for transparency
        cb=Image.new("RGBA",im.size)
        a=((np.indices((im.height,im.width))//16).sum(0)%2)
        cb=Image.fromarray(np.where(a[...,None]==1,[200,200,200,255],[150,150,150,255]).astype(np.uint8))
        cb.alpha_composite(im); sheet.paste(cb,(x,y))
        d.text((x,y+im.height+8),i,font=F,fill=(255,255,255)); d.text((x,y+im.height+40),mid,font=F,fill=(200,200,200)); x+=max(im.width,440)+G
    y+=h
sheet.convert("RGB").save("/workspace/flow-img/w2-7a/batch2_contact.png",optimize=True)
print(sheet.size)
