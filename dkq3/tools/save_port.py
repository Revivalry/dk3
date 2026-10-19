#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Carry native saves (DK3SAVE v1) across a map re-conversion.

Every world in a save records the checksum of the map it was made with (`asset_crc`), and the
runtime refuses a save whose map has changed. A re-conversion that only changes surface or
contents flags (the shader table, the brushes' shader indices) or lighting leaves everything a
save refers to (entities, inline models, geometry) as it was. For each world this tool finds the
converted map the save was made with, checks that only such lumps differ from the installed map,
and re-stamps the checksum. A world whose structure changed is refused and the save left alone.

    save_port.py --maps <installed dk3-maps.pk3> [--history <older dk3-maps.pk3> ...] <save.sav> ...
    save_port.py ... --write     # replace each portable save, keeping <save>.pre-port
"""
import argparse
import json
import re
import struct
import sys
import zipfile
import zlib
from pathlib import Path

LUMPS = ['entities', 'shaders', 'planes', 'nodes', 'leafs', 'leafsurfaces', 'leafbrushes', 'models',
         'brushes', 'brushsides', 'drawverts', 'drawindexes', 'fogs', 'surfaces', 'lightmaps',
         'lightgrid', 'visibility']
# What a save refers to by number or position. Flags, lighting and visibility may change freely;
# brush sides may change their shader number but not their plane.
STRUCTURAL = ['entities', 'planes', 'nodes', 'leafs', 'leafsurfaces', 'leafbrushes', 'models',
              'brushsides', 'drawverts', 'drawindexes', 'surfaces']


def structural(name, data):
    if name == 'brushsides':  # { int plane; int shader; }: the plane only
        return data[0::8] + data[1::8] + data[2::8] + data[3::8]
    return data


# --- MD4 (RFC 1320), as the engine's map checksum uses it -------------------------------------
def _rotl(value, shift):
    value &= 0xffffffff
    return ((value << shift) | (value >> (32 - shift))) & 0xffffffff


def md4_words(data):
    message = bytearray(data)
    length = (8 * len(data)) & 0xffffffffffffffff
    message.append(0x80)
    while len(message) % 64 != 56:
        message.append(0)
    message += struct.pack('<Q', length)
    a, b, c, d = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
    for offset in range(0, len(message), 64):
        x = struct.unpack_from('<16I', message, offset)
        aa, bb, cc, dd = a, b, c, d
        f = lambda x_, y, z: (x_ & y) | (~x_ & z)
        g = lambda x_, y, z: (x_ & y) | (x_ & z) | (y & z)
        h = lambda x_, y, z: x_ ^ y ^ z
        for i in (0, 4, 8, 12):
            a = _rotl(a + f(b, c, d) + x[i], 3)
            d = _rotl(d + f(a, b, c) + x[i + 1], 7)
            c = _rotl(c + f(d, a, b) + x[i + 2], 11)
            b = _rotl(b + f(c, d, a) + x[i + 3], 19)
        for i in (0, 1, 2, 3):
            a = _rotl(a + g(b, c, d) + x[i] + 0x5a827999, 3)
            d = _rotl(d + g(a, b, c) + x[i + 4] + 0x5a827999, 5)
            c = _rotl(c + g(d, a, b) + x[i + 8] + 0x5a827999, 9)
            b = _rotl(b + g(c, d, a) + x[i + 12] + 0x5a827999, 13)
        for i in (0, 2, 1, 3):
            a = _rotl(a + h(b, c, d) + x[i] + 0x6ed9eba1, 3)
            d = _rotl(d + h(a, b, c) + x[i + 8] + 0x6ed9eba1, 9)
            c = _rotl(c + h(d, a, b) + x[i + 4] + 0x6ed9eba1, 11)
            b = _rotl(b + h(c, d, a) + x[i + 12] + 0x6ed9eba1, 15)
        a, b, c, d = [(p + q) & 0xffffffff for p, q in zip((a, b, c, d), (aa, bb, cc, dd))]
    return a, b, c, d


def _libcrypto_md4():
    """libcrypto's MD4 (hashlib hides it behind OpenSSL's legacy provider); None without it."""
    import ctypes
    import ctypes.util
    try:
        library = ctypes.CDLL(ctypes.util.find_library('crypto') or 'libcrypto.so')
        function = library.MD4
    except (OSError, AttributeError, TypeError):
        return None
    function.restype = ctypes.c_void_p
    function.argtypes = [ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]

    def digest(data):
        out = ctypes.create_string_buffer(16)
        function(bytes(data), len(data), out)
        return struct.unpack('<4I', out.raw)
    return digest if digest(b'abc') == md4_words(b'abc') else None


_fast_md4 = _libcrypto_md4()
_checksums = {}


def map_checksum(data):
    """The engine's world checksum: the MD4 digest's four words XORed (memoized per content)."""
    import hashlib
    key = hashlib.sha1(data).digest()
    if key not in _checksums:
        a, b, c, d = (_fast_md4 or md4_words)(data)
        _checksums[key] = a ^ b ^ c ^ d
    return _checksums[key]


def lumps(data):
    out = {}
    for index, name in enumerate(LUMPS):
        offset, length = struct.unpack_from('<ii', data, 8 + index * 8)
        out[name] = data[offset:offset + length]
    return out


# --- DK3SAVE v1 records ---------------------------------------------------------------------
def read_records(data):
    if data[:8] != b'DK3SAVE\0' or struct.unpack_from('<I', data, 8)[0] != 1:
        raise ValueError('not a DK3SAVE v1 file')
    if struct.unpack_from('<I', data, 20)[0] != zlib.crc32(data[24:]):
        raise ValueError('save checksum mismatch')
    records, offset = [], 24
    while offset < len(data):
        size, identity, count, length, _ = struct.unpack_from('<IIHBB', data, offset)
        name = data[offset + 12:offset + 12 + length].decode()
        cursor, fields = offset + 12 + length, []
        for _ in range(count):
            kind, key_length, _, items = struct.unpack_from('<BBHI', data, cursor)
            key = data[cursor + 8:cursor + 8 + key_length].decode()
            end = cursor + 8 + key_length + items * (4 if kind in (1, 2) else 1)
            fields.append([key, kind, data[cursor + 8 + key_length:end]])
            cursor = end
        records.append((name, identity, fields))
        offset += size
    return records


def write_records(records):
    body = bytearray()
    for name, identity, fields in records:
        record = bytearray(struct.pack('<IIHBB', 0, identity, len(fields), len(name), 0)) + name.encode()
        for key, kind, value in fields:
            items = len(value) // 4 if kind in (1, 2) else len(value)
            record += struct.pack('<BBHI', kind, len(key), 0, items) + key.encode() + value
        struct.pack_into('<I', record, 0, len(record))
        body += record
    header = bytearray(b'DK3SAVE\0') + struct.pack('<IIII', 1, 24 + len(body), len(records), zlib.crc32(body))
    return bytes(header + body)


# --- Maps -----------------------------------------------------------------------------------
class Maps:
    def __init__(self, installed, history):
        self.installed = zipfile.ZipFile(installed)
        self.history = [p for p in history if p.exists()]
        self.by_checksum = None

    def current(self, name):
        return self.installed.read(f'maps/{name}.bsp')

    def original(self, name, checksum):
        """The converted map (from any kept generation) whose checksum the save recorded."""
        for package in [self.installed.filename] + [str(p) for p in self.history]:
            try:
                data = zipfile.ZipFile(package).read(f'maps/{name}.bsp')
            except (KeyError, zipfile.BadZipFile):
                continue
            if map_checksum(data) == checksum:
                return data, package
        return None, None


def port_world(maps, name, saved_crc, report):
    current = maps.current(name)
    current_crc = map_checksum(current)
    if saved_crc in (0, current_crc):
        report.append(f'{name}: already current')
        return current_crc, True
    original, source = maps.original(name, saved_crc)
    if original is None:
        report.append(f'{name}: refused, the map this save was made with ({saved_crc}) is not kept')
        return None, False
    old, new = lumps(original), lumps(current)
    changed = [lump for lump in STRUCTURAL if structural(lump, old[lump]) != structural(lump, new[lump])]
    if changed:
        report.append(f'{name}: refused, structure changed ({", ".join(changed)})')
        return None, False
    flags = [lump for lump in LUMPS if lump not in STRUCTURAL and old[lump] != new[lump]]
    report.append(f'{name}: portable (made with {Path(source).parent.parent.name[:12]}; only {", ".join(flags) or "nothing"} changed)')
    return current_crc, True


def port_blob(maps, data, report):
    """Re-stamps every world in a save (nested resident levels too). None when any is refused."""
    records = read_records(data)
    ok = True
    for name, _, fields in records:
        values = {key: value for key, _, value in fields}
        if name == 'campaign' and 'state' in values:
            world = values['map'].decode()
            state = values['state']
            saved = int(re.search(rb'"asset_crc":(\d+)', state).group(1))
            stamp, portable = port_world(maps, world, saved, report)
            ok &= portable
            if portable:
                for field in fields:
                    if field[0] == 'state':
                        field[2] = re.sub(rb'"asset_crc":\d+', b'"asset_crc":%d' % stamp, state, count=1)
        if name == 'resident_level':
            for field in fields:
                if field[0] == 'snapshot':
                    nested = port_blob(maps, field[2], report)
                    if nested is None:
                        ok = False
                    else:
                        field[2] = nested
    return write_records(records) if ok else None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--maps', type=Path, required=True, help='the installed dk3-maps.pk3')
    parser.add_argument('--history', type=Path, action='append', default=[], help='an older dk3-maps.pk3 to find the original maps in (repeatable)')
    parser.add_argument('--write', action='store_true', help='replace each portable save (keeping <save>.pre-port)')
    parser.add_argument('saves', type=Path, nargs='+')
    args = parser.parse_args(argv)
    maps = Maps(args.maps, args.history)
    failed = False
    for save in args.saves:
        report = []
        ported = port_blob(maps, save.read_bytes(), report)
        print(f'{save.name}: {"portable" if ported else "refused"}')
        for line in report:
            print(f'  {line}')
        if ported is None:
            failed = True
            continue
        read_records(ported)  # the result must read back
        if args.write and ported != save.read_bytes():
            backup = save.with_name(save.name + '.pre-port')
            if not backup.exists():
                backup.write_bytes(save.read_bytes())
            save.write_bytes(ported)
            print(f'  written (backup {backup.name})')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
