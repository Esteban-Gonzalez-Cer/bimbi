# Usage: python3 scripts/generate_native_buddy.py android/app/src/main/res
"""Generates Android VectorDrawables for the Bimbi buddy from canvas geometry."""
import sys, os
RES = sys.argv[1]
P1, SPLASH, P0, BLOOM = '#FFC3B1FF', '#FFDFD6FF', '#FFECE7FE', '#99F1EEFC'
INK, PUPIL, WHITE = '#FF31233F', '#FF221B17', '#FFFFFFFF'

def circle(cx, cy, r): return ellipse(cx, cy, r, r)
def ellipse(cx, cy, rx, ry):
    return f'M{cx-rx},{cy} a{rx},{ry} 0 1,0 {2*rx},0 a{rx},{ry} 0 1,0 {-2*rx},0 Z'
def rrect(x, y, w, h, r):
    return (f'M{x+r},{y} h{w-2*r} a{r},{r} 0 0 1 {r},{r} v{h-2*r} a{r},{r} 0 0 1 {-r},{r} '
            f'h{-(w-2*r)} a{r},{r} 0 0 1 {-r},{-r} v{-(h-2*r)} a{r},{r} 0 0 1 {r},{-r} Z')
BELL = 'M-29,10 C-31,-26 31,-26 29,10 C20,15 -20,15 -29,10 Z'
SMILE = 'M149,190 C155,196 167,196 173,190 C167,197 155,197 149,190 Z'  # mouth +12 y

def grad(x1, y1, x2, y2):
    return (f'<aapt:attr name="android:fillColor"><gradient android:type="linear" '
            f'android:startX="{x1}" android:startY="{y1}" android:endX="{x2}" android:endY="{y2}">'
            f'<item android:offset="0" android:color="{P1}"/><item android:offset="0.55" android:color="{SPLASH}"/>'
            f'<item android:offset="1" android:color="{P0}"/></gradient></aapt:attr>')

def path(d, fill=None, stroke=None, width=None, cap=None, g=None):
    a = f'<path android:pathData="{d}"'
    if fill: a += f' android:fillColor="{fill}"'
    if stroke: a += f' android:strokeColor="{stroke}" android:strokeWidth="{width}"'
    if cap: a += f' android:strokeLineCap="{cap}" android:strokeLineJoin="round"'
    if g: return a + '>' + g + '</path>'
    return a + '/>'

def ear(x, y, rot):
    return (f'<group android:translateX="{x}" android:translateY="{y}" android:rotation="{rot}">'
            + path('M0,10 L0,30', stroke='#FFC3B1FF', width=9, cap='round')
            + path(BELL, g=grad(-12.4, -17, 12.4, 14))
            + path(circle(0, -21, 6.5), g=grad(-2.6, -27.5, 2.6, -14.5))
            + '</group>')

def buddy(face=True):
    s = path(rrect(139, 62, 44, 22, 11), g=grad(152.2, 62, 169.8, 84))
    s += ear(79, 84, -40) + ear(243, 84, 40)
    s += path(circle(161, 182, 104), g=grad(119.4, 78, 202.6, 286))
    s += path(circle(161, 182, 101), stroke=BLOOM, width=4)
    if not face: return s
    s += path(ellipse(106, 176, 15, 10), fill='#CCF2A09B') + path(ellipse(216, 176, 15, 10), fill='#CCF2A09B')
    s += path('M100,172 L102,179 M106,171 L108,179 M112,172 L114,179 M210,172 L208,179 M216,171 L214,179 M222,172 L220,179',
              stroke='#BFD9706B', width=2, cap='round')
    for cx in (126, 196):
        s += path(ellipse(cx, 146, 15, 19), fill=PUPIL)
        s += path(circle(cx - 5, 152, 6), fill=WHITE) + path(circle(cx + 6, 139, 3.5), fill=WHITE)
    s += path('M114,120 C120,115 130,114 138,117', stroke=INK, width=3.5, cap='round')
    s += path('M184,117 C192,114 202,115 208,120', stroke=INK, width=3.5, cap='round')
    s += path(SMILE, fill=INK) + path(SMILE, stroke=INK, width=2.4, cap='round')
    s += f'<group><clip-path android:pathData="{SMILE}"/>' + path(ellipse(161, 210, 15, 10), fill='#FFF26B8F') + '</group>'
    s += path(ellipse(161, 168, 11, 7.5), fill=INK) + path(ellipse(157, 165, 3.5, 1.8), fill='#99FFFFFF')
    return s

HEAD = ('<?xml version="1.0" encoding="utf-8"?>\n<!-- Generated from the Brand Buddy canvas geometry. Do not edit by hand. -->\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android" xmlns:aapt="http://schemas.android.com/aapt" '
        'android:width="{w}dp" android:height="{w}dp" android:viewportWidth="{v}" android:viewportHeight="{v}">\n')

def write(name, w, v, body):
    os.makedirs(os.path.join(RES, 'drawable'), exist_ok=True)
    with open(os.path.join(RES, 'drawable', name + '.xml'), 'w') as f:
        f.write(HEAD.format(w=w, v=v) + body + '\n</vector>\n')

# Full buddy for the native alarm screen.
write('ic_bimbi_buddy', 200, 320, buddy())
# Adaptive launcher foreground: 108dp canvas, buddy ~70dp inside the 66dp safe circle.
k = 0.27
write('ic_launcher_foreground', 108, 108,
      f'<group android:scaleX="{k}" android:scaleY="{k}" android:translateX="{54-161*k:.2f}" android:translateY="{54-176*k:.2f}">' + buddy() + '</group>')
# Monochrome (themed icons): silhouette with eyes and smile cut out.
sil = (circle(161, 182, 104) + ' ' + ellipse(126, 146, 15, 19) + ' '
       + ellipse(196, 146, 15, 19) + ' ' + SMILE)
mono = (f'<group android:scaleX="{k}" android:scaleY="{k}" android:translateX="{54-161*k:.2f}" android:translateY="{54-176*k:.2f}">'
        f'<path android:fillColor="#FF000000" android:pathData="{rrect(139, 62, 44, 22, 11)}"/>'
        f'<path android:fillType="evenOdd" android:fillColor="#FF000000" android:pathData="{sil}"/>'
        + ''.join(f'<group android:translateX="{x}" android:translateY="84" android:rotation="{r}"><path android:fillColor="#FF000000" android:pathData="{BELL} {circle(0,-21,6.5)}"/></group>'
                  for x, r in ((79, -40), (243, 40)))
        + '</group>')
write('ic_launcher_monochrome', 108, 108, mono)
# Notification small icon: brand alarm glyph, white.
write('ic_stat_bimbi', 24, 24,
      path(circle(12, 13, 7), stroke='#FFFFFFFF', width=2, cap='round')
      + path('M12,10 v3 l2,1.5 M4.5,6.5 L7,4 M19.5,6.5 L17,4 M7.5,19 L6,21 M16.5,19 L18,21', stroke='#FFFFFFFF', width=2, cap='round'))
print('ok')
