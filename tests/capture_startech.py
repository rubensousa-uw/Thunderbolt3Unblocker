"""Read-only, targeted IORegistry snapshot; never sends probe/reset requests."""
import json
import plistlib
import subprocess

raw = subprocess.check_output(['ioreg', '-a', '-r', '-c', 'IOThunderboltSwitchType3'])
entries = plistlib.loads(raw)
keys = ('IORegistryEntryName', 'IOObjectClass', 'Device Model Name',
        'Device Vendor Name', 'Device Vendor ID', 'Device Model ID',
        'Device Model Revision', 'Route String', 'Router ID',
        'IOServiceBusyState', 'IOPowerManagement')
found = []
seen = set()

def visit(entry):
    if not isinstance(entry, dict):
        return
    if entry.get('Device Vendor ID') == 0x6f and entry.get('Device Model ID') == 0x201:
        identity = entry.get('IORegistryEntryID')
        if identity not in seen:
            seen.add(identity)
            item = {key: entry[key] for key in keys if key in entry}
            item['children'] = [
                {'class': child.get('IOObjectClass'),
                 'name': child.get('IORegistryEntryName')}
                for child in entry.get('IORegistryEntryChildren', [])
            ]
            found.append(item)
    for child in entry.get('IORegistryEntryChildren', []):
        visit(child)

for entry in entries:
    visit(entry)
print(json.dumps({'startech_count': len(found), 'devices': found}, indent=2,
                 default=lambda value: '<binary property omitted>'))
