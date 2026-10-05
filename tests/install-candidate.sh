#!/bin/bash
# Requires user-run sudo. Requests only an auxiliary collection rebuild.
# Does not explicitly start/load a live driver or restart.
set -euo pipefail
test "$(id -u)" -eq 0 || { echo 'Run with sudo in your own Terminal.' >&2; exit 1; }
task_repo=$(cd "$(dirname "$0")/.." && pwd)
task_source="$task_repo/build/manual/Thunderbolt3Unblocker.kext"
task_target=/Library/Extensions/Thunderbolt3Unblocker.kext
task_aux=/Library/KernelCollections/AuxiliaryKernelExtensions.kc
test "$(sw_vers -buildVersion)" = 25G241
test -d /Library/Developer/KDKs/KDK_26.7.1_25G241.kdk
test -d "$task_target"
test ! -L "$task_target"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$task_target/Contents/Info.plist")" = 1
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$task_source/Contents/Info.plist")" = 1.1.0
if /usr/sbin/nvram t3u-incompatible-v11 >/dev/null 2>&1; then
    echo 'Experimental crash guard already exists; stop and investigate.' >&2
    exit 1
fi
/usr/bin/codesign --verify --deep --strict "$task_source"
task_uuid=$(/usr/bin/xcrun dwarfdump --uuid "$task_source/Contents/MacOS/Thunderbolt3Unblocker" | /usr/bin/awk '{print $2}')
test -n "$task_uuid"
task_work=$(/usr/bin/mktemp -d /private/tmp/t3u-install.XXXXXX)
/usr/bin/ditto "$task_source" "$task_work/Candidate.kext"
/usr/sbin/chown -R root:wheel "$task_work/Candidate.kext"
/bin/chmod -R go-w "$task_work/Candidate.kext"
echo 'Revalidating candidate before any installed driver is changed...'
/usr/bin/kmutil create --new aux --arch x86_64 --explicit-only \
    --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc \
    --system-path /System/Library/KernelCollections/SystemKernelExtensions.kc \
    --auxiliary-path "$task_work/CandidateAux.kc" \
    --bundle-path "$task_work/Candidate.kext"
/usr/bin/kmutil inspect --auxiliary-path "$task_work/CandidateAux.kc" \
    --show-kext-uuids | /usr/bin/grep -F "$task_uuid"
task_backup_parent='/Library/Application Support/Thunderbolt3Unblocker-Backups'
/bin/mkdir -p "$task_backup_parent"
task_backup=$(/usr/bin/mktemp -d "$task_backup_parent/install.XXXXXX")
echo "Backup: $task_backup"
/usr/bin/ditto "$task_aux" "$task_backup/OriginalAux.kc"
task_changed=0
rollback() {
    task_result=$?
    trap - EXIT
    if [ "$task_result" -ne 0 ] && [ "$task_changed" -eq 1 ]; then
        echo 'Installation failed; restoring original driver (crash guard unchanged).' >&2
        if [ -d "$task_target" ]; then
            /bin/mv "$task_target" "$task_backup/FailedCandidate.kext"
        fi
        /bin/mv "$task_backup/Original.kext" "$task_target"
        if ! /usr/bin/cmp -s "$task_aux" "$task_backup/OriginalAux.kc"; then
            echo "Auxiliary collection changed: do NOT reboot; backup at $task_backup" >&2
        fi
    fi
    exit "$task_result"
}
trap rollback EXIT
/bin/mv "$task_target" "$task_backup/Original.kext"
task_changed=1
/usr/bin/ditto "$task_work/Candidate.kext" "$task_target"
/usr/bin/codesign --verify --deep --strict "$task_target"
# Staging is complete. Approval/rebuild may be asynchronous; never roll files
# back behind a pending approval, or claim the candidate is already installed.
task_changed=0
echo "Candidate bundle prepared: $task_uuid"
echo "Original driver preserved: $task_backup/Original.kext"
echo 'Requesting an AUXILIARY collection rebuild only...'
if ! /usr/bin/kmutil rebuild; then
    echo 'Auxiliary rebuild request did not complete. Candidate bundle remains staged.' >&2
    echo 'Do NOT restart. Send the complete output for review.' >&2
    exit 1
fi
if /usr/bin/kmutil inspect --show-kext-uuids | /usr/bin/grep -F "$task_uuid"; then
    echo 'Candidate UUID found in collection on disk; runtime remains untested.'
else
    echo 'Candidate not yet in collection. Approval/rebuild may still be pending.'
fi
echo 'No NVRAM keys were deleted. No explicit live-load request or restart performed.'
echo 'Send this output for review BEFORE restarting.'
