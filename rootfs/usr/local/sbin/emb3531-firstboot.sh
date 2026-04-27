#!/bin/sh
set -eu

ROOT_PART="/dev/mmcblk2p4"
DISK="/dev/mmcblk2"
MARKER_DIR="/var/lib/emb3531"
MARKER_FILE="${MARKER_DIR}/firstboot.done"

log() { echo "[emb3531-firstboot] $1"; }

[ -f "${MARKER_FILE}" ] && exit 0
mkdir -p "${MARKER_DIR}"

log "Best-effort RTC sync..."
if command -v chronyc >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
    timeout 2 chronyc waitsync 2 1 >/dev/null 2>&1 || true
fi
hwclock --systohc --utc >/dev/null 2>&1 || true

need_grow=1
if [ -r /sys/class/block/mmcblk2/size ] && [ -r /sys/class/block/mmcblk2p4/start ] && [ -r /sys/class/block/mmcblk2p4/size ]; then
    disk_sectors="$(cat /sys/class/block/mmcblk2/size || echo 0)"
    part_start="$(cat /sys/class/block/mmcblk2p4/start || echo 0)"
    part_sectors="$(cat /sys/class/block/mmcblk2p4/size || echo 0)"
    max_part_sectors=$((disk_sectors - part_start - 34))
    if [ "$part_sectors" -ge $((max_part_sectors - 2048)) ]; then
        need_grow=0
    fi
fi

if [ "$need_grow" -eq 1 ]; then
    log "Growing rootfs partition and filesystem..."
    if command -v sgdisk >/dev/null 2>&1; then
        part_start="$(cat /sys/class/block/mmcblk2p4/start 2>/dev/null || echo 0)"
        timeout 8 sgdisk -e "${DISK}" >/dev/null 2>&1 || true
        timeout 8 sgdisk -d 4 "${DISK}" >/dev/null 2>&1 || true
        timeout 8 sgdisk -n "4:${part_start}:0" -t 4:8300 -c 4:rootfs "${DISK}" >/dev/null 2>&1 || true
    else
        timeout 8 sh -c "echo ',+' | sfdisk -N 4 --no-reread --force '${DISK}'" >/dev/null 2>&1 || true
    fi
    timeout 5 blockdev --rereadpt "${DISK}" >/dev/null 2>&1 || true
    timeout 5 partx -u "${DISK}" >/dev/null 2>&1 || true
    udevadm settle --timeout=5 >/dev/null 2>&1 || true
    timeout 120 resize2fs "${ROOT_PART}" >/dev/null 2>&1 || true
else
    log "Rootfs already full size, skip grow."
fi

sync
touch "${MARKER_FILE}"

systemctl disable emb3531-firstboot.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/multi-user.target.wants/emb3531-firstboot.service
rm -f /etc/systemd/system/emb3531-firstboot.service
rm -f /usr/local/sbin/emb3531-firstboot.sh
systemctl daemon-reload >/dev/null 2>&1 || true

log "Done, rebooting..."
systemctl --no-block reboot
