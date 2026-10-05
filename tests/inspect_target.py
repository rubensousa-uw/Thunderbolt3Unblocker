"""Read the target bytes from a Mach-O kernel collection; never access live memory."""
import struct
import subprocess
from pathlib import Path

collection = Path('/System/Library/KernelCollections/BootKernelExtensions.kc')
symbol = '__ZN24IOThunderboltSwitchType321shouldSkipEnumerationEv'
symbols = subprocess.check_output(['xcrun', 'nm', str(collection)], text=True)
address = int(next(line.split()[0] for line in symbols.splitlines()
                   if line.split()[-1:] == [symbol]), 16)
data = collection.read_bytes()

def commands(offset):
    magic, _, _, _, count, _, _, _ = struct.unpack_from('<8I', data, offset)
    assert magic == 0xfeedfacf
    current = offset + 32
    for _ in range(count):
        command, size = struct.unpack_from('<II', data, current)
        yield command, current
        current += size

for command, entry in commands(0):
    if command != 0x80000035:  # LC_FILESET_ENTRY
        continue
    _, _, _, image_offset, name_offset, _ = struct.unpack_from('<IIQQII', data, entry)
    name = data[entry + name_offset:].split(b'\0', 1)[0].decode()
    if name != 'com.apple.iokit.IOThunderboltFamily':
        continue
    for segment_command, segment in commands(image_offset):
        if segment_command != 0x19:  # LC_SEGMENT_64
            continue
        _, _, _, vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<II16sQQQQ', data, segment)
        if vmaddr <= address < vmaddr + min(vmsize, filesize):
            position = fileoff + address - vmaddr
            print(f'{name} {symbol} address={address:#x} fileoff={position:#x}')
            print(data[position:position+64].hex(' '))
            raise SystemExit(0)
raise SystemExit('Target not found in file-backed segments')
