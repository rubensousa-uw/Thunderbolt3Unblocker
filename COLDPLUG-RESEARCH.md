# Cold-plug investigation (not a new driver release)

The installed 1.1.0 driver and its binary have not been changed by this work.
Only read-only/user-space research utilities have been added.

## Findings for build 25G241

- On-disk disassembly of `IOThunderboltController::startScan()` shows state
  bookkeeping, conditional waiting and virtual calls. Its name is not evidence
  that calling it alone re-enumerates hardware. Its synchronization contract has
  not been established.
- `IOThunderboltSwitch::fullScan()` and `childDeviceScan()` interact with
  controller/configuration state, hardware and many private virtual methods.
  Calling them directly from kext startup has not been shown safe.
- Public `IOServiceRequestProbe` documentation in the installed SDK explicitly
  says family support is required and default `IOService::requestProbe` returns
  unsupported. The KDK ThunderboltFamily binary references that base method and
  does not expose a controller/switch override; this argues against a generic
  user-space probe solution. No probe request was issued.
- Private dispatch queues offer `dispatchSync`, `dispatchAsync` and block-based
  entry points, but their names alone do not establish lifetime, ordering and
  hardware-state preconditions for re-enumerating an already rejected router.
- Searches for the exact APIs did not yield relevant public contracts. No API
  contract is inferred from unrelated search results.

## Reproducible, read-only tools

```
make test
make inspect-scan
python3 tests/inspect_scan.py __ZN19IOThunderboltSwitch8fullScanEv
python3 tests/capture_startech.py
```

The disassembler reads the on-disk boot kernel collection and runs Zydis in
user space. It never reads live kernel memory. The target capture reads
IORegistry only, filters StarTech vendor/model 0x006f/0x0201, and omits UIDs,
serial numbers and unrelated hardware properties.

Next live diagnostic: capture once after reboot with the StarTech still
connected and the Dell black, before reconnecting; capture again after
reconnecting and obtaining display output. This can distinguish the rejected
router's published services and power state from the working state. It does
not, by itself, validate a private scan/reset call.

Cold-plug repair remains unimplemented. No private kernel APIs, controller
resets, new driver installation, startup automation or protected system-file
changes have been performed in this investigation.
