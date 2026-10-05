#!/bin/bash
# Offline candidate collection only. Does not install, load, change NVRAM,
# rebuild the system's collections, or restart the computer.
set -eu
if [ "$(id -u)" -ne 0 ]; then
    echo 'Run this validation with sudo in your own Terminal.' >&2
    exit 1
fi
task_repo=$(cd "$(dirname "$0")/.." && pwd)
task_candidate="$task_repo/build/manual/Thunderbolt3Unblocker.kext"
test -d "$task_candidate"
/usr/bin/codesign --verify --deep --strict "$task_candidate"
task_validation=$(/usr/bin/mktemp -d /private/tmp/t3u-validation.XXXXXX)
echo "Validation artifacts: $task_validation"
/usr/bin/ditto "$task_candidate" "$task_validation/Thunderbolt3Unblocker.kext"
/usr/sbin/chown -R root:wheel "$task_validation/Thunderbolt3Unblocker.kext"
/bin/chmod -R go-w "$task_validation/Thunderbolt3Unblocker.kext"
/usr/bin/kmutil create --new aux --arch x86_64 --explicit-only \
    --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc \
    --system-path /System/Library/KernelCollections/SystemKernelExtensions.kc \
    --auxiliary-path "$task_validation/CandidateAux.kc" \
    --bundle-path "$task_validation/Thunderbolt3Unblocker.kext"
echo 'Offline collection build succeeded. Driver has NOT been installed or loaded.'
