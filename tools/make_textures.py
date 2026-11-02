# Builds the rope overlay textures from generated source images.
#   rope_albedo.png  seamless horizontal rope tile with alpha
#   rope_normal.png  tangent-space normal map derived from the rope's luminance
#   spark_atlas.png  4x4 additive spark frames on black (256px cells)
import sys, json, math
from PIL import Image, ImageFilter, ImageChops, ImageOps
rope_src, spark_src, out = sys.argv[1], sys.argv[2], sys.argv[3]

# ---------- rope ----------
src = Image.open(rope_src).convert('RGB')
W, H = src.size
lum = src.convert('L')
rows = [sum(lum.crop((0, y, W, y + 1)).getdata()) / W for y in range(H)]
on = [y for y, v in enumerate(rows) if v > 35]
y0, y1 = on[0], on[-1]
pad = int((y1 - y0) * 0.12)
y0, y1 = max(0, y0 - pad), min(H, y1 + pad)
band = src.crop((0, y0, W, y1))
bl = band.convert('L')
bw, bh = band.size
# twist period from autocorrelation of the column profile (centre rows only)
core = bl.crop((0, int(bh * .3), bw, int(bh * .7))).resize((bw, 1), Image.BOX)
prof = list(core.getdata()); m = sum(prof) / len(prof); prof = [p - m for p in prof]
def ac(l): return sum(prof[i] * prof[i + l] for i in range(len(prof) - l)) / (len(prof) - l)
lags = range(int(bh * .5), int(bh * 1.6))
best = max(lags, key=ac)
# refine by checking multiples: take as many whole periods as fit in ~80% of width
n = max(1, int(bw * 0.8 / best))
tile_w = best * n
x0 = (bw - tile_w) // 2
tile = band.crop((x0, 0, x0 + tile_w, bh))
# crossfade a short overlap so the seam is invisible
ov = max(8, best // 3)
ext = band.crop((x0 + tile_w, 0, x0 + tile_w + ov, bh))
head = tile.crop((0, 0, ov, bh))
mask = Image.linear_gradient('L').rotate(90, expand=True).resize((ov, bh))  # 255 -> 0 left to right
# after rotate: 0 at left -> 255 at right, so left shows ext and right shows head
blend = Image.composite(head, ext, mask)  # left: ext (continuation) -> right: original head
tile.paste(blend, (0, 0))
# alpha from brightness (black background), keeping fine hairs soft
tl = tile.convert('L')
alpha = tl.point(lambda v: 0 if v < 38 else min(255, int((v - 38) * 255 / 50)))
# fade stray hairs that stick out beyond the rope body
rows_t = [sum(tl.crop((0, y, tile.size[0], y + 1)).getdata()) / tile.size[0] for y in range(bh)]
body = [y for y, v in enumerate(rows_t) if v > 70]
b0, b1 = body[0], body[-1]
vm = Image.new('L', (1, bh))
for y in range(bh):
    d = (b0 - y) if y < b0 else (y - b1) if y > b1 else 0
    vm.putpixel((0, y), max(0, 255 - d * 40))
alpha = ImageChops.multiply(alpha, vm.resize(tile.size))
# the dark grooves inside the rope body stay opaque (they are shadow, not background)
inner = Image.new('L', (1, bh))
m0, m1 = b0 + int((b1 - b0) * .16), b1 - int((b1 - b0) * .16)
for y in range(bh):
    d = (m0 - y) if y < m0 else (y - m1) if y > m1 else 0
    inner.putpixel((0, y), max(0, 255 - d * 30))
alpha = ImageChops.lighter(alpha, inner.resize(tile.size))
alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))
# un-premultiply the dark fringe a little so edges are not grey
rgba = tile.copy(); rgba.putalpha(alpha)
rgba.save(f'{out}/rope_albedo.png')
# normal map from blurred luminance as height
hgt = tl.filter(ImageFilter.GaussianBlur(1.2))
gx = hgt.filter(ImageFilter.Kernel((3, 3), [-1, 0, 1, -2, 0, 2, -1, 0, 1], 1, 128))
gy = hgt.filter(ImageFilter.Kernel((3, 3), [-1, -2, -1, 0, 0, 0, 1, 2, 1], 1, 128))
strength = 2.2
px = []
for a, b in zip(gx.getdata(), gy.getdata()):
    nx = -(a - 128) / 128 * strength; ny = -(b - 128) / 128 * strength; nz = 1.0
    l = math.sqrt(nx * nx + ny * ny + nz * nz)
    px.append((int((nx / l * .5 + .5) * 255), int((ny / l * .5 + .5) * 255), int((nz / l * .5 + .5) * 255)))
nm = Image.new('RGB', tile.size); nm.putdata(px); nm.save(f'{out}/rope_normal.png')

# ---------- spark atlas ----------
sp = Image.open(spark_src).convert('RGBA')
black = Image.new('RGBA', sp.size, (0, 0, 0, 255))
sp = Image.alpha_composite(black, sp).convert('RGB')
sw, sh = sp.size
CELL = 256
atlas = Image.new('RGB', (CELL * 4, CELL * 4), 'black')
centers = []
for r in range(4):
    for c in range(4):
        cx0, cy0 = int(c * sw / 4), int(r * sh / 4)
        cell = sp.crop((cx0, cy0, int((c + 1) * sw / 4), int((r + 1) * sh / 4)))
        # centre on the white-hot core: brightest point of a blurred copy
        b = cell.convert('L').filter(ImageFilter.GaussianBlur(6))
        bx, by = max(((x, y) for y in range(0, b.size[1], 2) for x in range(0, b.size[0], 2)), key=lambda p: b.getpixel(p))
        half = min(bx, by, b.size[0] - bx, b.size[1] - by, 150)
        half = max(half, 90)
        crop = cell.crop((bx - half, by - half, bx + half, by + half)).resize((CELL, CELL), Image.LANCZOS)
        # crush the faint dark halo to pure black so additive blending leaves no box
        crop = crop.point(lambda v: 0 if v < 14 else int((v - 14) * 255 / 241))
        # soft circular vignette so frame edges never show
        vg = Image.radial_gradient('L').resize((CELL, CELL)).point(lambda v: max(0, min(255, int((255 - v) * 1.6))))
        crop = Image.composite(crop, Image.new('RGB', (CELL, CELL), 'black'), vg)
        atlas.paste(crop, (c * CELL, r * CELL))
atlas.save(f'{out}/spark_atlas.png')
# ---------- web export: downscaled textures as data URLs (file:// pages cannot upload file images to WebGL) ----------
import base64, io
def durl(im, fmt='PNG'):
    b = io.BytesIO(); im.save(b, fmt, optimize=True); return 'data:image/png;base64,' + base64.b64encode(b.getvalue()).decode()
RW = 1024; RH = round(tile.size[1] * RW / tile.size[0])
alb_w = Image.open(f'{out}/rope_albedo.png').resize((RW, RH), Image.LANCZOS)
nrm_w = Image.open(f'{out}/rope_normal.png').resize((RW, RH), Image.LANCZOS)
meta = {'tileW': RW, 'tileH': RH, 'body0': b0 * RH / bh, 'body1': b1 * RH / bh, 'sparkCols': 4, 'sparkRows': 4}
with open(f'{out}/textures.js', 'w') as f:
    f.write('window.ROPE_TEX=' + json.dumps({'meta': meta, 'albedo': durl(alb_w), 'normal': durl(nrm_w), 'spark': durl(atlas.resize((768, 768), Image.LANCZOS))}) + ';\n')
json.dump({'rope': {'w': tile.size[0], 'h': tile.size[1], 'period_px': best, 'periods': n, 'body0': b0, 'body1': b1},
           'spark': {'cell': CELL, 'cols': 4, 'rows': 4}}, open(f'{out}/textures.json', 'w'), indent=1)
print('rope tile', tile.size, 'period', best, 'x', n, '| spark atlas', atlas.size)
