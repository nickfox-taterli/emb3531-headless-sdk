# docs/agent/target-test-workflow.md

**Scope**: How to interact with the target board — SSH, file transfer, kernel/module deployment, log collection.
**Single source of truth for IP**: `.agent/local-target.md`. Read it before any SSH command. Do not hardcode the IP elsewhere.
**Pitfalls**: Target IP may change between sessions. Always re-read `.agent/local-target.md`.

## Prerequisites

1. Read `.agent/local-target.md` for current IP and SSH access.
2. All commands below use `<TARGET_IP>` — substitute from `.agent/local-target.md`.

## Routine SSH Operations

```bash
ssh root@<TARGET_IP> 'echo OK'                # Reachability check
ssh root@<TARGET_IP> 'dmesg | tail -100'       # Recent kernel log
ssh root@<TARGET_IP> 'uname -a'                # Kernel version
ssh root@<TARGET_IP> 'lsmod'                   # Loaded modules
ssh root@<TARGET_IP> 'cat /proc/device-tree/compatible'  # DTB check
ssh root@<TARGET_IP> 'lsblk'                   # Storage layout
ssh root@<TARGET_IP> 'lsusb'                   # USB devices
```

## Copying Files

```bash
scp file root@<TARGET_IP>:/tmp/
scp my_driver.ko root@<TARGET_IP>:/tmp/
scp script.sh root@<TARGET_IP>:/tmp/ && ssh root@<TARGET_IP> 'bash /tmp/script.sh'
```

## Package Installation

- Host: `apt install` without confirmation.
- Target: `ssh root@<TARGET_IP> 'apt-get install -y <package>'` — no confirmation needed (board is recoverable).

## Kernel Replacement on Target (Quick Test)

Boot partition is `/dev/mmcblk2p3` (ext4, labelled `boot`). To test a new kernel+DTB without re-flashing the entire image:

```bash
# 1. Build kernel locally
./sdk.sh kernel

# 2. Mount boot partition on target
ssh root@<TARGET_IP> 'mount /dev/mmcblk2p3 /mnt'

# 3. Copy new kernel Image and DTB
scp workspace/linux-6.18.24/arch/arm64/boot/Image root@<TARGET_IP>:/mnt/Image
scp workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/rk3399-emb3531.dtb root@<TARGET_IP>:/mnt/dtb/rk3399-emb3531.dtb

# 4. Sync and unmount
ssh root@<TARGET_IP> 'sync && umount /mnt'

# 5. Reboot
ssh root@<TARGET_IP> 'reboot'

# 6. After reboot, verify
ssh root@<TARGET_IP> 'uname -a'
```

This requires explicit confirmation — it replaces the running kernel.

## Kernel Module Development Loop

Build a module locally, push to target, load, test, unload:

```bash
# 1. Build module (must match running kernel)
./sdk.sh kernel   # or targeted module build

# 2. Push module to target
scp workspace/linux-6.18.24/drivers/your/driver.ko root@<TARGET_IP>:/tmp/

# 3. Load module
ssh root@<TARGET_IP> 'insmod /tmp/driver.ko'

# 4. Check dmesg for probe messages / errors
ssh root@<TARGET_IP> 'dmesg | tail -30'

# 5. Test (interact via sysfs, ioctl, /dev node, etc.)

# 6. Unload module
ssh root@<TARGET_IP> 'rmmod driver'

# 7. Check unload was clean
ssh root@<TARGET_IP> 'dmesg | tail -20'
```

Module load/unload is safe and does not require confirmation. Module must be built against the same kernel version running on the target.

## Module Load/Unload

```bash
ssh root@<TARGET_IP> 'insmod /tmp/my_driver.ko'     # Load
ssh root@<TARGET_IP> 'rmmod my_driver'               # Unload
ssh root@<TARGET_IP> 'modinfo /tmp/my_driver.ko'     # Module info
ssh root@<TARGET_IP> 'dmesg | tail -20'              # Check messages
```

## Commands Requiring Explicit Confirmation

- `dd`, `mkfs.*`, `fdisk`/`gdisk`/`parted` on any block device
- `reboot`, `poweroff` (unless task explicitly requires it)
- Permanent `/etc/` modifications
- Firmware/flash update commands
- Kernel replacement on boot partition (see above)
- Any irreversible data loss on target

## Collecting Logs

Save logs to `/tmp/` on the host to avoid polluting the project tree. `*.log` is git-ignored.

```bash
ssh root@<TARGET_IP> 'dmesg -T' > /tmp/target-dmesg.log
ssh root@<TARGET_IP> 'dmesg | grep -i usb' > /tmp/target-usb.log
ssh root@<TARGET_IP> 'journalctl -k --no-pager --since "5 min ago"' > /tmp/recent.log
```

## Verification Checklist

- [ ] `.agent/local-target.md` read before any SSH command
- [ ] No hardcoded IP in commands sent to target
- [ ] Destructive operations confirmed with user
- [ ] Test results include: command, expected, actual, pass/fail
