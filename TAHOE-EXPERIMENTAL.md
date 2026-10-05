# Experimental Intel macOS investigation

This branch is NOT a confirmed working Tahoe release. The Dell UP2715K through
a StarTech TB32DP2 has not yet been tested with this build.

Observed host: iMac20,2, macOS 26.7.1 (25G241), Darwin 25.6.0.
The previous panic points at ZydisDecodeOperandRegister's register assertion.
The installed original kext refuses to start because `t3u-incompatible` contains
`25.6.0`. Merely seeing its bundle in the loaded-kext list does not mean its
startup routine succeeded.

## Changes

- Use Zydis minimal decoding for instruction lengths, avoiding operand semantic
  decoding. Reject relative instructions rather than copying unsafe trampolines.
- Bound decode input to the 32-byte trampoline budget.
- Handle allocation failure, release temporary allocations, and fix failure
  cleanup that previously indexed the executable pool using a temporary pointer.
- Bound the NVRAM compatibility buffer terminator.
- Build an x86_64 kext using Command Line Tools, SDK 15.4 and kernel-mode flags.
  No full Xcode installation is necessary for this build route.

## Reproduce

```
make test
make
codesign --verify --deep --strict build/manual/Thunderbolt3Unblocker.kext
python3 tests/inspect_target.py
```

Seven user-space tests pass, including the host's actual target prologue and
rejection of RIP-relative memory, relative call/jump and truncated instructions.
The baseline full-decoder probe checked 16,777,216 three-byte prefixes with zero
tails without reproducing the assertion. This is not proof that the reported
panic's underlying trigger has been identified. The minimal decoder avoids its
operand path but may still fail elsewhere.

## Deployment status and safety

The binary is ad-hoc signed, not Developer-ID signed. It has NOT been installed
or loaded. Existing kernel extensions, security settings and the NVRAM guard
have NOT been modified. `kextutil -n -t` is not supported by the host's modern
kmutil wrapper; sandbox output from the legacy utility is not a valid kernel
compatibility test. Administrator access is required for the remaining checks.
No matching Kernel Debug Kit is installed; do not force a collection rebuild
with `--allow-missing-kdk` just to bypass that requirement.

Before any live trial: save work and backups, disconnect nonessential external
storage, preserve the installed kext outside /Library/Extensions, and establish
a recovery plan. Do not clear `t3u-incompatible` with the old kext still eligible
to start. It protects against repeated panics. A correct deployment must replace
and verify the candidate in the kernel collection before retrying its startup.
Keep the compatibility guard logic enabled in this experimental build.

The candidate now uses `t3u-incompatible-v11`, leaving the original
`t3u-incompatible` key intact. It refuses to patch unless its own guard can be
written and read back. A failed experimental startup therefore does not require
clearing the original driver's crash guard. This is a safety change, not a
guarantee of successful boot or display output.

`tests/validate-kext.sh` creates an offline auxiliary collection only. The host
successfully built that collection after installing KDK 26.7.1 (25G241).
`tests/install-candidate.sh` must be run manually with administrator privileges;
it repeats offline validation, checks the candidate UUID, preserves the original
kext and auxiliary collection, stages the candidate and rebuilds the installed
collections. It checks the staged UUID, attempts rollback on failure, and never
loads a live driver, deletes NVRAM keys or restarts automatically. The updated
guard's runtime behavior and the installation script remain untested at this
point. Save work and arrange recovery before running it.

Deployment correction: the first live staging attempt used
`kmutil install --update-all`, which attempted boot/system rebuilds and failed on
the sealed read-only system volume. The original bundle was restored. The user
confirmed that the current auxiliary collection and its pre-install backup had
identical SHA-256 hashes. The installer was disabled while this was investigated.
It now requests `kmutil rebuild`, the documented auxiliary-only rebuild managed
by kernelmanagerd. It tolerates a pending approval without falsely claiming
that the new UUID is already present, and does not silently roll bundle files
back after a successful staging operation. No direct collection overwrite,
sealed-volume modification or explicit live-load command is used. The corrected
installation route still requires live verification by the user.

On an Intel Mac, Shift at startup enters safe mode and Command-R enters Recovery:
https://support.apple.com/en-us/102603
Do not reset all NVRAM as a workaround: that also removes the crash guard.

Remaining limitations include upstream's non-atomic cross-CPU code patching and
unverified runtime compatibility. No monitor-success claim is justified until
startup succeeds and the Dell is detected and displays correctly.
