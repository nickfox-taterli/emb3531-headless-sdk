# docs/agent/driver-development/platform-driver.md

**Scope**: Platform driver development index for this kernel tree (Linux 6.18.24 on RK3399).
**Local grounding**: All driver paths relative to `workspace/linux-6.18.24/`. Examples from local tree.
**Pitfalls**: Kconfig changes must also update `patches/kernel/emb3531_headless_defconfig`. New DTS nodes must have a matching YAML binding.

## Relevant APIs

| API | Header | Notes |
|-----|--------|-------|
| `platform_driver_register()` | `include/linux/platform_device.h` | Manual registration |
| `module_platform_driver()` | `include/linux/platform_device.h` | Module boilerplate |
| `builtin_platform_driver()` | `include/linux/platform_device.h` | Built-in only |
| `builtin_platform_driver_probe()` | `include/linux/platform_device.h` | Built-in, no remove |
| `of_match_table` | `include/linux/mod_devicetable.h` | DT compatible matching |
| `platform_get_resource()` | `include/linux/platform_device.h` | Get IOMEM resource |
| `platform_get_irq()` | `include/linux/platform_device.h` | Get IRQ number |
| `devm_platform_ioremap_resource()` | `include/linux/platform_device.h` | Managed MMIO mapping |
| `devm_clk_get()`, `devm_clk_get_enabled()` | `include/linux/clk.h` | Managed clock |
| `devm_regulator_get()` | `include/linux/regulator/consumer.h` | Managed regulator |
| `devm_gpiod_get()` | `include/linux/gpio/consumer.h` | Managed GPIO descriptor |
| `devm_reset_control_get()` | `include/linux/reset.h` | Managed reset control |
| `devm_request_irq()` | `include/linux/interrupt.h` | Managed IRQ |

## Local Example Drivers

### Rockchip Thermal (`drivers/thermal/rockchip_thermal.c`)
- Compatible: `"rockchip,rk3399-tsadc"`
- Pattern: `builtin_platform_driver_probe()`
- Uses: `devm_clk_get_enabled()`, `platform_get_irq()`, `devm_request_irq()`, `writel_relaxed()`
- Good example for: MMIO, IRQ, clocks, thermal subsystem integration.

### Rockchip Pinctrl (`drivers/pinctrl/pinctrl-rockchip.c`)
- Compatible: `"rockchip,rk3399-pinctrl"`
- Pattern: `platform_driver` with probe/remove
- Uses: `devm_pinctrl_register()`, MMIO
- Good example for: pinctrl subsystem, complex probe.

### Rockchip Clock (`drivers/clk/rockchip/clk-rk3399.c`)
- Pattern: `builtin_platform_driver_probe()`
- Uses: CRU MMIO mapping, clock tree registration
- Good example for: clock framework integration.

### DW MMC Rockchip (`drivers/mmc/host/dw_mmc-rockchip.c`)
- Compatible: `"rockchip,rk2928-dw-mshc"`, `"rockchip,rk3288-dw-mshc"`
- Pattern: `platform_driver` with probe/remove
- Uses: `devm_clk_get()`, clock rate setting
- Good example for: MMC subsystem, clock handling.

## Kconfig/Makefile Integration

### Adding a new driver

1. Add Kconfig symbol in the subsystem's `Kconfig`:
   ```kconfig
   config MY_DRIVER
       tristate "My driver"
       depends on ARCH_ROCKCHIP && OF
       help
         Say Y here to enable my driver.
   ```

2. Add to subsystem `Makefile`:
   ```makefile
   obj-$(CONFIG_MY_DRIVER)   += my_driver.o
   ```

3. Enable in defconfig:
   ```
   CONFIG_MY_DRIVER=y
   ```

## of_match_table and Compatible Workflow

1. Define in driver:
   ```c
   static const struct of_device_id my_driver_of_match[] = {
       { .compatible = "vendor,my-device", },
       { /* sentinel */ }
   };
   MODULE_DEVICE_TABLE(of, my_driver_of_match);
   ```

2. Add to `of_match_table` in `platform_driver` struct.

3. Add DTS node with matching `compatible`.

4. Verify binding YAML exists in `Documentation/devicetree/bindings/`.

## MMIO Resource Mapping

```c
void __iomem *base;
base = devm_platform_ioremap_resource(pdev, 0);
if (IS_ERR(base))
    return PTR_ERR(base);
```

## IRQ Handling

```c
int irq = platform_get_irq(pdev, 0);
if (irq < 0)
    return irq;

ret = devm_request_irq(dev, irq, my_isr, 0, "my-driver", priv);
if (ret)
    return ret;
```

## devm Resource Management

All `devm_*` functions automatically clean up on probe failure or device removal. Prefer them over manual `clk_put()`, `iounmap()`, `free_irq()`, etc.

## Probe/Remove Patterns

```c
static int my_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    /* devm allocations, ioremap, clk, irq */
    return 0;
}

static void my_remove(struct platform_device *pdev)
{
    /* Only needed for non-devm resources */
}

static struct platform_driver my_driver = {
    .probe  = my_probe,
    .remove = my_remove,
    .driver = {
        .name = "my-driver",
        .of_match_table = my_driver_of_match,
    },
};
module_platform_driver(my_driver);
```

## DTS Integration

See `docs/agent/device-tree-workflow.md` for the full checklist.
