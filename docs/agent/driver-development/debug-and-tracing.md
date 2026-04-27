# docs/agent/driver-development/debug-and-tracing.md

**Scope**: Kernel debugging on the EMB3531 target — log collection, dynamic debug, ftrace, boot log interpretation.
**Local source**: All commands reference drivers in `workspace/linux-6.18.24/drivers/`. Target IP from `.agent/local-target.md`.
**Pitfalls**: Dynamic debug requires `CONFIG_DYNAMIC_DEBUG=y`. ftrace requires tracefs mounted. Target IP may change.

## dmesg

```bash
# On target:
dmesg                          # Full kernel log
dmesg -T                       # With human-readable timestamps
dmesg -l err,warn              # Only errors and warnings
dmesg | grep -i <subsystem>    # Filter by keyword
dmesg -w                       # Follow (like tail -f)
dmesg --level=debug            # Include debug messages (if enabled)
```

## Dynamic Debug

Enable verbose logging without recompiling:

```bash
# Enable all debug prints in a driver
echo 'file drivers/thermal/rockchip_thermal.c +p' > /sys/kernel/debug/dynamic_debug/control

# Enable all debug prints in a subsystem
echo 'file drivers/usb/* +p' > /sys/kernel/debug/dynamic_debug/control

# Enable for specific function
echo 'func rockchip_thermal_probe +p' > /sys/kernel/debug/dynamic_debug/control

# Disable
echo 'file drivers/thermal/rockchip_thermal.c -p' > /sys/kernel/debug/dynamic_debug/control

# List current settings
cat /sys/kernel/debug/dynamic_debug/control | head
```

Prerequisites: `CONFIG_DYNAMIC_DEBUG=y` (check defconfig). Debugfs must be mounted.

## ftrace

Documentation: `Documentation/trace/ftrace.rst`, `Documentation/trace/ftrace-design.rst`.

```bash
# On target:
mount -t tracefs tracefs /sys/kernel/tracing 2>/dev/null || true

# Trace a specific function
echo function > /sys/kernel/tracing/current_tracer
echo rockchip_thermal_probe > /sys/kernel/tracing/set_ftrace_filter
echo 1 > /sys/kernel/tracing/tracing_on
# ... trigger the function ...
cat /sys/kernel/tracing/trace
echo 0 > /sys/kernel/tracing/tracing_on

# Function graph tracer
echo function_graph > /sys/kernel/tracing/current_tracer
echo rockchip_thermal_probe > /sys/kernel/tracing/set_graph_function
echo 1 > /sys/kernel/tracing/tracing_on
cat /sys/kernel/tracing/trace

# Reset
echo nop > /sys/kernel/tracing/current_tracer
```

## Tracepoints

```bash
# List available tracepoints
cat /sys/kernel/tracing/available_events | grep -i <keyword>

# Enable a tracepoint
echo 1 > /sys/kernel/tracing/events/<subsystem>/<event>/enable
cat /sys/kernel/tracing/trace
```

## Debugfs/Sysfs

```bash
# Mount debugfs if not mounted
mount -t debugfs debugfs /sys/kernel/debug

# Common debugfs locations
ls /sys/kernel/debug/clk/          # Clock tree
ls /sys/kernel/debug/regulator/    # Regulator state
ls /sys/kernel/debug/gpio          # GPIO state
ls /sys/kernel/debug/pinctrl/      # Pinctrl state

# Sysfs device attributes
cat /sys/bus/platform/devices/<dev>/modalias
ls /sys/class/thermal/             # Thermal zones
```

## Module Parameters

```bash
# List module parameters
cat /sys/module/<module_name>/parameters/<param>

# Set at load time
insmod my_driver.ko my_param=1
```

## dev_dbg/dev_info/dev_err

Kernel logging levels used in drivers:

| Function | Level | Notes |
|----------|-------|-------|
| `dev_err()` | ERR | Always visible |
| `dev_warn()` | WARNING | Always visible |
| `dev_info()` | INFO | Always visible |
| `dev_dbg()` | DEBUG | Only with `CONFIG_DYNAMIC_DEBUG` or `DEBUG` define |

Pattern:
```c
dev_err(dev, "failed to get clock: %d\n", ret);
dev_info(dev, "probed successfully\n");
dev_dbg(dev, "register read: 0x%08x\n", val);
```

## Target Board Log Collection

Read `.agent/local-target.md` for target IP. Save logs to `/tmp/` on host to avoid polluting the project tree.

```bash
ssh root@<TARGET_IP> 'dmesg -T' > /tmp/boot.log
ssh root@<TARGET_IP> 'dmesg | grep -i usb' > /tmp/usb.log
ssh root@<TARGET_IP> 'journalctl -k --no-pager --since "5 min ago"' > /tmp/recent.log
```

## Boot Log Interpretation Workflow

1. Look for `Linux version` line — confirms correct kernel.
2. Look for `Machine model: Rockchip EMB3531` — confirms correct DTB.
3. Look for probe success/failure of key drivers: stmmac, dwc3, sdhci, rk808, thermal.
4. Search for `probe` + `failed` / `error` to find driver probe issues.
5. Search for `defer` to find deferred probes (usually resolve later, but worth checking).
6. Check for `panic` / `oops` / `BUG` for kernel crashes.

```bash
ssh root@<TARGET_IP> 'dmesg | grep -E "probe|defer|error|failed|panic|oops|BUG"'
```

## Verification Checklist

- [ ] Dynamic debug: `CONFIG_DYNAMIC_DEBUG=y` in defconfig
- [ ] ftrace: tracefs mounted on target
- [ ] Boot log shows `Machine model: Rockchip EMB3531`
- [ ] No panic/oops/BUG in dmesg
