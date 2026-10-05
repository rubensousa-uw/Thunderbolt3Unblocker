"""Disassemble one function from the on-disk collection, never live memory.

Calls a user-space disassembler built from the existing Zydis dependency.
This is NOT an API caller and does not load, probe, reset or scan any device.
"""
import re
import struct
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
collection = Path('/System/Library/KernelCollections/BootKernelExtensions.kc')
wanted = sys.argv[1] if len(sys.argv) > 1 else '__ZN23IOThunderboltController9startScanEv'
symbols = {}
for line in subprocess.check_output(['xcrun', 'nm', str(collection)], text=True).splitlines():
    fields = line.split()
    if len(fields) == 3 and fields[1] in ('T', 't'):
        symbols.setdefault(int(fields[0], 16), []).append(fields[2])
address = next(a for a, names in symbols.items() if wanted in names)
end = min(a for a in symbols if a > address)
size = end - address
if size > 8192:
    raise SystemExit('Function exceeds diagnostic size limit')
data = collection.read_bytes()

def commands(offset):
    magic, _, _, _, count, _, _, _ = struct.unpack_from('<8I', data, offset)
    if magic != 0xfeedfacf:
        raise ValueError('Not a 64-bit Mach-O')
    position = offset + 32
    for _ in range(count):
        command, length = struct.unpack_from('<II', data, position)
        if length < 8:
            raise ValueError('Invalid command length')
        yield command, position
        position += length

for command, entry in commands(0):
    if command != 0x80000035:
        continue
    _, _, _, image, name_offset, _ = struct.unpack_from('<IIQQII', data, entry)
    name = data[entry + name_offset:].split(b'\0', 1)[0].decode()
    if name != 'com.apple.iokit.IOThunderboltFamily':
        continue
    for command, segment in commands(image):
        if command != 0x19:
            continue
        _, _, _, vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<II16sQQQQ', data, segment)
        if vmaddr <= address and end <= vmaddr + min(vmsize, filesize):
            position = fileoff + address - vmaddr
            payload = f'{address:x}\n' + data[position:position + size].hex(' ')
            output = subprocess.check_output([str(root / 'build/disassemble-bytes')],
                                             input=payload, text=True)
            print(f'{wanted}: {size} bytes, on-disk only')
            for line in output.splitlines():
                target = re.search(r'\b(?:call|jmp) 0x([0-9A-Fa-f]+)', line)
                if target:
                    names = symbols.get(int(target[1], 16), [])
                    if names:
                        line += ' ; ' + ', '.join(names)
                print(line)
            raise SystemExit(0)
raise SystemExit('Function not found in file-backed segments')
