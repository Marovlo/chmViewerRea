#!/usr/bin/env python3
"""Generate a small, valid, UNCOMPRESSED .chm (ITSF v3) for smoke tests.

Layout produced:
  /test.html, /html/topic1.html, /html/topic2.html  (uncompressed, section 0)
  /sample.hhc (TOC sitemap),  /sample.hhk (index sitemap)

Directory: ITSP header (0x50) + one 0x1000 PMGL chunk with real quickrefs.
"""
import struct, sys

def utf16(s):
    return s.encode("utf-16-le") + b"\x00\x00"

def cword(v):
    """chmlib's continuation-word encoding: 7 bits per byte, high bit = continue."""
    if v == 0:
        return b"\x00"
    groups = []
    while v:
        groups.append(v & 0x7F)
        v >>= 7
    groups.reverse()
    out = bytes((g | 0x80) for g in groups[:-1]) + bytes([groups[-1]])
    return out

def entry_bytes(name, section, offset, length):
    nb = utf16(name)
    return cword(len(nb)) + nb + cword(section) + cword(offset) + cword(length)

def pmgl_chunk(ents):
    """ents: list of (entry_bytes, body_offset). Builds 0x1000 chunk with quickrefs."""
    body = b""
    offsets = []
    for eb, off in ents:
        offsets.append(off)
        body += eb
    n = len(offsets)
    qr_area = 2 * n + 2                # N offsets (2B each) + final count short
    # free_space covers EVERYTHING after the last entry (padding + quickrefs):
    # chmlib computes entries-end as block_len - free_space.
    free = 4096 - 20 - len(body)
    assert free >= qr_area
    chunk = b"PMGL" + struct.pack("<iii", free, 0, -1) + struct.pack("<i", -1)
    chunk += body
    chunk += b"\x00" * (free - qr_area)
    chunk += b"".join(struct.pack("<H", o) for o in reversed(offsets))  # offN..off0
    chunk += struct.pack("<H", n)      # entry count short
    assert len(chunk) == 4096, len(chunk)
    return chunk

def build(chm_path):
    files = {
        "/test.html": b"<html><head><meta charset='utf-8'><title>Test Home</title></head>"
                      b"<body style='font-family:-apple-system'><h1>CHM RE Test Home</h1>"
                      b"<p>Links: <a href='html/topic1.html'>Topic 1</a> "
                      b"<a href='html/topic2.html'>Topic 2</a></p>"
                      b"<p>UTF-8 \xe6\xb5\x8b\xe8\xaf\x95</p></body></html>",
        "/html/topic1.html": b"<html><head><meta charset='utf-8'><title>Topic 1</title></head>"
                             b"<body><h1>Topic 1</h1><p>Hello from topic 1.</p></body></html>",
        "/html/topic2.html": b"<html><head><meta charset='utf-8'><title>Topic 2</title></head>"
                             b"<body><h1>Topic 2</h1><p>Hello from topic 2.</p></body></html>",
    }
    hhc = ("<html><head></head><body><ul>"
           "<li><object type='text/sitemap'><param name='Name' value='Home'>"
           "<param name='Local' value='test.html'></object></li>"
           "<li><object type='text/sitemap'><param name='Name' value='Chapter 1'>"
           "<param name='Local' value='html/topic1.html'></object>"
           "<ul><li><object type='text/sitemap'><param name='Name' value='Section 1.1'>"
           "<param name='Local' value='html/topic2.html'></object></li></ul></li>"
           "</ul></body></html>").encode()
    hhk = ("<html><head></head><body><ul>"
           "<li><object type='text/sitemap'><param name='Name' value='Hello'>"
           "<param name='Local' value='html/topic1.html'></object></li>"
           "</ul></body></html>").encode()

    allf = dict(files)
    allf["/sample.hhc"] = hhc
    allf["/sample.hhk"] = hhk

    payload = b""
    offsets, lengths = {}, {}
    ordered = sorted(allf.keys())          # '/' < letters; h < s < t — good order
    for name in ordered:
        data = allf[name]
        offsets[name] = len(payload)
        lengths[name] = len(data)
        payload += data

    ents, cursor = [], 0
    for name in ordered:
        eb = entry_bytes(name, 0, offsets[name], lengths[name])
        ents.append((eb, cursor))
        cursor += len(eb)

    # field order per chmlib: version, header_len, unknown_000c, block_len,
    # blockidx_intvl, index_depth, index_root, index_head, unknown_0024, num_blocks
    itsp = b"ITSP" + struct.pack("<iiiiiiiiii", 1, 0x54, 0, 0x1000, 2, 1, -1, 0, 0, 1)
    itsp += struct.pack("<i", 0x409)
    itsp += bytes.fromhex("7c01fd10aa7bd0119e0c00a0c91e9efb")   # system uuid
    itsp = itsp.ljust(0x54, b"\x00")                            # ITSP v1 header is 0x54
    assert len(itsp) == 0x54
    directory = itsp + pmgl_chunk(ents)

    itsf_len = 0x60                      # v3 header length per chmlib
    dir_offset = itsf_len
    data_offset = dir_offset + len(directory)

    header = b"ITSF" + struct.pack("<iii", 3, itsf_len, 1)
    header += struct.pack("<I", 0)        # timestamp (ignored by chmlib for v3)
    header += struct.pack("<I", 0x409)    # language
    header += bytes.fromhex("6a92025d2e211dd09df900a0c91e9ceb")  # ITSF section GUID
    header += bytes.fromhex("10fd017caa7bd0119e0c00a0c91e9efb")  # second GUID
    header += struct.pack("<QQ", 0, 0)                       # unknown section-0 area
    header += struct.pack("<QQQ", dir_offset, len(directory), data_offset)
    assert len(header) == 0x60, hex(len(header))

    with open(chm_path, "wb") as f:
        f.write(header)
        f.write(directory)
        f.write(payload)
    print(f"wrote {chm_path}: dir@0x{dir_offset:x} data@0x{data_offset:x} "
          f"({len(ordered)} files, {len(payload)} payload bytes)")

if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else "build/test.chm")
