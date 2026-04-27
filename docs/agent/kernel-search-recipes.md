# docs/agent/kernel-search-recipes.md

**Scope**: Reusable search recipes for the kernel tree at `workspace/linux-6.18.24/`. Use `rg` or `grep -rn`.
**Pitfalls**: All paths assume patches have been applied (`./sdk.sh patch`). If the tree is clean, board-specific files won't exist yet.

## Kconfig Symbols

```bash
# Find symbol definition
rg 'config SYM_NAME' workspace/linux-6.18.24/ --include='Kconfig*'

# Find symbol users (selects/depends on)
rg 'SYM_NAME' workspace/linux-6.18.24/ --include='Kconfig*' --include='Makefile*'

# Check if symbol is set in defconfig
rg 'SYM_NAME' patches/kernel/emb3531_headless_defconfig
```

## Compatible Strings

```bash
# Find compatible string in DTS files
rg '"rockchip,rk3399' workspace/linux-6.18.24/arch/arm64/boot/dts/

# Find compatible in driver of_match_table
rg '"rockchip,rk3399' workspace/linux-6.18.24/drivers/ --include='*.c'

# Find binding YAML for a compatible
rg 'rockchip,rk3399' workspace/linux-6.18.24/Documentation/devicetree/bindings/ --include='*.yaml'
```

## DTS Examples

```bash
# Find how a node is used across all RK3399 boards
rg '&gmac' workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/rk3399-*.dts*

# Find a specific property usage
rg 'mmc-hs400' workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/

# Find our board DTS
cat patches/kernel/rk3399-emb3531.dts
```

## YAML Bindings

```bash
# List all Rockchip bindings
find workspace/linux-6.18.24/Documentation/devicetree/bindings/ -name '*rockchip*' -name '*.yaml'

# Search for a specific binding
rg 'rockchip,rk3399-tsadc' workspace/linux-6.18.24/Documentation/devicetree/bindings/
```

## Makefile/Kconfig Integration

```bash
# How is a driver compiled?
rg 'rockchip_thermal' workspace/linux-6.18.24/drivers/thermal/Makefile
rg 'ROCKCHIP_THERMAL' workspace/linux-6.18.24/drivers/thermal/Kconfig

# Find obj-$(CONFIG_...) lines
rg 'obj-.*CONFIG_' workspace/linux-6.18.24/drivers/<subsystem>/Makefile
```

## Platform Driver Probe Paths

```bash
# Find of_match_table definitions
rg 'of_device_id.*\[\]' workspace/linux-6.18.24/drivers/thermal/rockchip_thermal.c

# Find module_platform_driver or builtin_platform_driver
rg 'module_platform_driver\|builtin_platform_driver' workspace/linux-6.18.24/drivers/clk/rockchip/

# Find probe function signature
rg 'static.*probe.*struct platform_device' workspace/linux-6.18.24/drivers/thermal/rockchip_thermal.c
```

## USB Driver Match Tables

```bash
# Find usb_device_id tables
rg 'usb_device_id' workspace/linux-6.18.24/drivers/usb/storage/ --include='*.c' -l

# Find struct usb_driver
rg 'struct usb_driver' workspace/linux-6.18.24/drivers/usb/class/usblp.c
```

## Misc/Char Device Examples

```bash
# Find miscdevice registration
rg 'misc_register\|misc_deregister' workspace/linux-6.18.24/drivers/char/ --include='*.c' -l

# Find file_operations structures
rg 'file_operations\s+\w+\s*=' workspace/linux-6.18.24/drivers/char/hpet.c
```

## GPIO/Regulator/Clock/Reset Usage

```bash
# gpiod_get patterns
rg 'devm_gpiod_get\|gpiod_get' workspace/linux-6.18.24/drivers/net/ethernet/stmicro/stmmac/ --include='*.c'

# regulator_get patterns
rg 'devm_regulator_get' workspace/linux-6.18.24/drivers/ --include='*.c' -l | head -10

# clk_get patterns
rg 'devm_clk_get' workspace/linux-6.18.24/drivers/thermal/rockchip_thermal.c

# reset_control patterns
rg 'devm_reset_control' workspace/linux-6.18.24/drivers/ --include='*.c' -l | head -10
```

## IRQ/MMIO/DMA Patterns

```bash
# platform_get_irq
rg 'platform_get_irq' workspace/linux-6.18.24/drivers/thermal/rockchip_thermal.c

# devm_request_irq
rg 'devm_request_irq\|devm_request_threaded_irq' workspace/linux-6.18.24/drivers/ --include='*.c' -l | head -10

# devm_ioremap_resource
rg 'devm_platform_ioremap_resource\|devm_ioremap_resource' workspace/linux-6.18.24/drivers/ --include='*.c' -l | head -10

# readl/writel
rg 'writel_relaxed\|readl_relaxed' workspace/linux-6.18.24/drivers/thermal/rockchip_thermal.c

# DMA coherent
rg 'dma_alloc_coherent\|dmam_alloc_coherent' workspace/linux-6.18.24/drivers/ --include='*.c' -l | head -5
```

## Exact Error Log Searches

```bash
# Search for a specific error message in source
rg '"probe failed"' workspace/linux-6.18.24/drivers/ --include='*.c'

# Search for EPROBE_DEFER returns
rg 'EPROBE_DEFER' workspace/linux-6.18.24/drivers/ --include='*.c' -l | head -10
```
