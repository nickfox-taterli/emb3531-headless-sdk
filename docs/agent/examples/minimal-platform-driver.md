# docs/agent/examples/minimal-platform-driver.md

Minimal platform driver skeleton for Linux 6.18.24 on RK3399.

## Kconfig Snippet

Add to the appropriate `Kconfig` file (e.g., `drivers/platform/Kconfig` or subsystem Kconfig):

```kconfig
config PLAT_EMB3531_DEMO
    tristate "EMB3531 demo platform driver"
    depends on ARCH_ROCKCHIP && OF
    help
      Demo platform driver for EMB3531 board.
      Say M to build as module, Y to build in.
```

## Makefile Snippet

Add to the matching `Makefile`:

```makefile
obj-$(CONFIG_PLAT_EMB3531_DEMO) += emb3531_demo.o
```

## C Skeleton

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/mod_devicetable.h>

struct emb3531_demo_priv {
    struct device *dev;
    /* Add per-device state here */
};

static int emb3531_demo_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    struct emb3531_demo_priv *priv;

    priv = devm_kzalloc(dev, sizeof(*priv), GFP_KERNEL);
    if (!priv)
        return -ENOMEM;

    priv->dev = dev;
    platform_set_drvdata(pdev, priv);

    /* TODO: devm_platform_ioremap_resource(), devm_clk_get(),
     *       devm_request_irq(), etc. */

    dev_info(dev, "probed\n");
    return 0;
}

static void emb3531_demo_remove(struct platform_device *pdev)
{
    /* devm_ resources are auto-cleaned */
    dev_info(&pdev->dev, "removed\n");
}

static const struct of_device_id emb3531_demo_of_match[] = {
    { .compatible = "norco,emb3531-demo" },  /* ← PLACEHOLDER: pick a real compatible */
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, emb3531_demo_of_match);

static struct platform_driver emb3531_demo_driver = {
    .probe  = emb3531_demo_probe,
    .remove = emb3531_demo_remove,
    .driver = {
        .name = "emb3531-demo",
        .of_match_table = emb3531_demo_of_match,
    },
};
module_platform_driver(emb3531_demo_driver);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("EMB3531 demo platform driver");
MODULE_AUTHOR("Author <email>");
```

## DTS Node Skeleton

Add to `patches/kernel/rk3399-emb3531.dts`:

```dts
/* PLACEHOLDER: verify compatible string against driver and binding */
emb3531_demo: demo@ff000000 {
    compatible = "norco,emb3531-demo";
    reg = <0x0 0xff000000 0x0 0x1000>;  /* ← PLACEHOLDER: real MMIO address */
    interrupts = <GIC_SPI 64 IRQ_TYPE_LEVEL_HIGH>;  /* ← PLACEHOLDER */
    clocks = <&cru SCLK_xxx>;  /* ← PLACEHOLDER: use rk3399-cru.h */
    status = "okay";
};
```

## Verification Checklist

- [ ] Compatible string matches between DTS and `of_match_table`.
- [ ] `MODULE_DEVICE_TABLE(of, ...)` is present.
- [ ] Kconfig symbol is set in `patches/kernel/emb3531_headless_defconfig`.
- [ ] Makefile `obj-$(CONFIG_...)` line is added.
- [ ] Build succeeds: `./sdk.sh kernel`
- [ ] Module loads on target: `insmod emb3531_demo.ko` + `dmesg | tail`
- [ ] Module unloads cleanly: `rmmod emb3531_demo` + `dmesg | tail`
- [ ] DTS `reg` address does not conflict with existing nodes.
- [ ] No resources are leaked on probe failure paths.
