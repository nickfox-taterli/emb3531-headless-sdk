# docs/agent/kconfig-workflow.md

**Scope**: Safe Kconfig symbol inspection and defconfig modification for this kernel tree.
**Pitfalls**: Do not delete unrelated symbols. `CONFIG_EFI_PARTITION` ≠ UEFI boot. Copy `.config` back to `patches/kernel/emb3531_headless_defconfig` to persist changes.
**Verification**: After defconfig change, run `./sdk.sh kernel` and confirm the symbol appears in the build.

## Find Symbol Definition

```bash
rg 'config <SYMBOL>' workspace/linux-6.18.24/ --include='Kconfig*' -n
```

Example: Find `CONFIG_ROCKCHIP_THERMAL`:
```bash
rg 'config ROCKCHIP_THERMAL' workspace/linux-6.18.24/ --include='Kconfig*' -n
# → drivers/thermal/Kconfig:...
```

## Inspect Dependencies

After finding the Kconfig file, read the surrounding block:

```bash
rg -A 20 'config ROCKCHIP_THERMAL' workspace/linux-6.18.24/drivers/thermal/Kconfig
```

Look for:
- `depends on` — hard dependency. All must be met.
- `select` — forces another symbol on. Be careful of recursive selects.
- `imply` — weak suggestion. User can still override.
- `default` — default value when not explicitly set.

## Find Symbol Users

```bash
# Who depends on this symbol?
rg '<SYMBOL>' workspace/linux-6.18.24/ --include='Kconfig*'

# Who uses it in Makefile?
rg '<SYMBOL>' workspace/linux-6.18.24/ --include='Makefile*'

# Who uses it in C code?
rg 'CONFIG_<SYMBOL>' workspace/linux-6.18.24/drivers/ --include='*.c' -l
```

## Check Current Defconfig

```bash
rg '<SYMBOL>' patches/kernel/emb3531_headless_defconfig
```

## Modify Defconfig

1. Run `make menuconfig` or edit `.config` directly.
2. Copy back:
   ```bash
   cp workspace/linux-6.18.24/.config patches/kernel/emb3531_headless_defconfig
   ```
3. Or edit `patches/kernel/emb3531_headless_defconfig` directly (safer for simple additions).

### Do Not Delete Unrelated Symbols

When editing the defconfig, only add or change symbols relevant to the task. Do not remove or modify symbols you did not intend to change.

## Report Config Deltas

After modifying, report what changed:

```bash
diff -u <old> patches/kernel/emb3531_headless_defconfig
```

## GPT Partition Parsing vs UEFI Boot

- `CONFIG_EFI_PARTITION=y` is needed for GPT partition table parsing. It is **not** UEFI firmware boot.
- This SDK uses extlinux boot via U-Boot, not UEFI.
- `CONFIG_EFI_PARTITION` is defined in `block/partitions/Kconfig`.
- It is set to `y` in `emb3531_headless_defconfig`.
- Do not confuse `CONFIG_EFI_PARTITION` with `CONFIG_EFI` (UEFI runtime services, not used here).
