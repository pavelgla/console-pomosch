#!/usr/bin/env python3
"""Переклеить платформу объектов в статических библиотеках vcpkg с «iOS» на «iOS Simulator».

Порты на configure (libvpx, ffmpeg) под триплет arm64-ios-simulator собираются с флагами устройства
(-mios-version-min), и ld отвечает «building for 'iOS-simulator', but linking in object file built for
'iOS'». vtool меняет LC_BUILD_VERSION прямо в .o, архив пересобирается и получает новый индекс (ranlib).
Использование: ios-sim-fix-platform.py <каталог-с-.a> ...
"""
import os
import re
import subprocess
import sys
import tempfile

MAGIC = b"!<arch>\n"


def platform_of(path):
    out = subprocess.run(["vtool", "-show-build", path], capture_output=True, text=True).stdout
    m = re.search(r"platform (\S+)", out)
    return m.group(1) if m else None


def fix_archive(path):
    data = open(path, "rb").read()
    if not data.startswith(MAGIC):
        return 0
    pos, out, fixed = len(MAGIC), [MAGIC], 0
    with tempfile.TemporaryDirectory() as tmp:
        while pos < len(data):
            hdr = data[pos:pos + 60]
            name, size = hdr[:16].decode(), int(hdr[48:58])
            body = data[pos + 60:pos + 60 + size]
            pos += 60 + size + (size & 1)
            n = 0
            if name.startswith("#1/"):
                n = int(name[3:].strip())
            real = body[:n].rstrip(b"\0").decode(errors="replace") if n else name.strip()
            if real.startswith("__.SYMDEF"):
                continue  # индекс пересоберёт ranlib
            obj = body[n:]
            f = os.path.join(tmp, "m.o")
            open(f, "wb").write(obj)
            if platform_of(f) == "IOS":
                g = os.path.join(tmp, "m2.o")
                r = subprocess.run(["vtool", "-set-build-version", "iossim", "14.0", "17.0",
                                    "-replace", "-output", g, f], capture_output=True, text=True)
                if r.returncode != 0:
                    sys.exit(f"vtool не справился с {real} в {path}: {r.stderr}")
                obj = open(g, "rb").read()
                obj += b"\0" * (-len(obj) % 8)  # выравнивание следующих членов архива
                fixed += 1
            body = body[:n] + obj
            newsize = len(body)
            hdr = hdr[:48] + f"{newsize:<10}".encode() + hdr[58:]
            out.append(hdr + body + (b"\n" if newsize & 1 else b""))
    if fixed:
        open(path, "wb").write(b"".join(out))
        subprocess.run(["ranlib", path], check=True)
    return fixed


total = 0
for d in sys.argv[1:]:
    for root, _, files in os.walk(d):
        for fn in sorted(files):
            if fn.endswith(".a"):
                p = os.path.join(root, fn)
                k = fix_archive(p)
                if k:
                    print(f"{p}: переклеено объектов {k}")
                total += k
print(f"всего переклеено объектов: {total}")
