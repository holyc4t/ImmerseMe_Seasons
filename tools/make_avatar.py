"""Renders the addon-list icon at 512x512 for the CurseForge project avatar: docs/images/avatar.png.

Pure Python 3, no dependencies (takes a while):

    py tools/make_avatar.py

It draws icon() from make_textures.py on a bigger canvas, so the avatar always matches
Media/icon.tga. Nothing in Media/ is touched.
"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_textures as m  # noqa: E402

SIZE = 512


def main():
    c = m.icon(SIZE)
    rows = []
    for y in range(c.h):
        row = bytearray([0])
        for x in range(c.n):
            row += bytes(m.b8(v) for v in c.px[y * c.n + x])
        rows.append(bytes(row))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    out = os.path.join(HERE, "..", "docs", "images", "avatar.png")
    with open(out, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", c.n, c.h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))
    print("wrote", os.path.abspath(out), c.n, "x", c.h)


if __name__ == "__main__":
    main()
