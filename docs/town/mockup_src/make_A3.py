"""MOCKUP A3: option A cuts to the existing side-view counter close-up when trading."""
import os
from PIL import Image, ImageDraw
from compose_A2 import text_mask, ptext
from pix import C, HERE

src = "/home/user/dehoudang/screenshots/v03b_clean_counter.png"
img = Image.open(src).convert("RGBA")
if img.size != (1280, 720):
    img = img.resize((1280, 720), Image.NEAREST)
text = "示意图 A：交易时切到柜台特写（沿用现有画面）"
lw = text_mask(text, 16, 0).width
ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
od = ImageDraw.Draw(ov)
od.rectangle((8, 8, 8 + lw + 18, 8 + 30), fill=(15, 10, 8, 200))
img.alpha_composite(ov)
ptext(img, 17, 12, text, C.paper_hi, 16, 1, spacing=0)
img.convert("RGB").save(os.path.join(HERE, "A3_counter_closeup.png"))
