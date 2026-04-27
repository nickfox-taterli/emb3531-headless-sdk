# docs/agent/driver-development/gpio-pinctrl-regulator-clock-reset.md

**Scope**: Common embedded driver resources — GPIO, pinctrl, regulator, clock, reset — in this kernel tree.
**Local grounding**: All DTS examples from `patches/kernel/rk3399-emb3531.dts`. Driver examples from `workspace/linux-6.18.24/drivers/`.
**Pitfalls**: `-EPROBE_DEFER` is normal, not fatal. Target IP from `.agent/local-target.md`.

## GPIO (gpiod API)

### APIs

| API | Header | Notes |
|-----|--------|-------|
| `devm_gpiod_get()` | `include/linux/gpio/consumer.h` | Managed get by DT property name |
| `devm_gpiod_get_optional()` | `include/linux/gpio/consumer.h` | Returns NULL if missing, not error |
| `gpiod_set_value()` | `include/linux/gpio/consumer.h` | Set logical value (0/1) |
| `gpiod_get_value()` | `include/linux/gpio/consumer.h` | Read logical value |
| `gpiod_direction_output()` | `include/linux/gpio/consumer.h` | Set as output with initial value |
| `gpiod_direction_input()` | `include/linux/gpio/consumer.h` | Set as input |

### DTS Property Naming

DT properties for GPIOs use the pattern `<name>-gpios`:
```dts
reset-gpios = <&gpio3 RK_PB7 GPIO_ACTIVE_HIGH>;
```

The driver gets it by name (without the `-gpios` suffix):
```c
struct gpio_desc *reset = devm_gpiod_get(dev, "reset", GPIOD_OUT_LOW);
```

### Local Example

In `patches/kernel/rk3399-emb3531.dts`:
```dts
snps,reset-gpio = <&gpio3 RK_PB7 GPIO_ACTIVE_HIGH>;
```
Driver side: `drivers/net/ethernet/stmicro/stmmac/stmmac_main.c` uses `devm_gpiod_get_optional()`.

## Pinctrl

### States

Drivers typically define pinctrl states in DTS:
```dts
pinctrl-names = "default";
pinctrl-0 = <&rgmii_pins>;
```

Multiple states: `"default"`, `"sleep"`, etc.

### DTS Convention

Pinctrl nodes for custom pins go under `&pinctrl`:
```dts
&pinctrl {
    my-driver {
        my_pins: my-pins {
            rockchip,pins = <1 RK_PC2 RK_FUNC_GPIO &pcfg_pull_up>;
        };
    };
};
```

### Local Example

`patches/kernel/rk3399-emb3531.dts` — PMIC pinctrl:
```dts
&pinctrl {
    pmic {
        pmic_int_l: pmic-int-l {
            rockchip,pins = <1 RK_PC5 RK_FUNC_GPIO &pcfg_pull_up>;
        };
    };
};
```

Driver: `drivers/pinctrl/pinctrl-rockchip.c` (compatible: `"rockchip,rk3399-pinctrl"`).

## Regulators

### APIs

| API | Header | Notes |
|-----|--------|-------|
| `devm_regulator_get()` | `include/linux/regulator/consumer.h` | Managed get (required) |
| `devm_regulator_get_optional()` | `include/linux/regulator/consumer.h` | Returns NULL if missing |
| `regulator_enable()` | `include/linux/regulator/consumer.h` | Enable supply |
| `regulator_disable()` | `include/linux/regulator/consumer.h` | Disable supply |
| `regulator_set_voltage()` | `include/linux/regulator/consumer.h` | Set voltage range |

### DTS Convention

Supply properties use the pattern `<name>-supply`:
```dts
phy-supply = <&vcc_phy>;
```

### Local Example

`patches/kernel/rk3399-emb3531.dts`:
```dts
&gmac {
    phy-supply = <&vcc_phy>;
};
&sdmmc {
    vqmmc-supply = <&vcc_sd>;
};
```

PMIC regulators defined in `&i2c0` node (RK808).

## Clocks

### APIs

| API | Header | Notes |
|-----|--------|-------|
| `devm_clk_get()` | `include/linux/clk.h` | Managed get |
| `devm_clk_get_enabled()` | `include/linux/clk.h` | Get + enable (auto-disable on remove) |
| `devm_clk_get_optional()` | `include/linux/clk.h` | Returns NULL if missing |
| `clk_prepare_enable()` | `include/linux/clk.h` | Enable clock |
| `clk_disable_unprepare()` | `include/linux/clk.h` | Disable clock |
| `clk_set_rate()` | `include/linux/clk.h` | Set clock rate |

### Local Example

`drivers/thermal/rockchip_thermal.c`:
```c
clk = devm_clk_get_enabled(&pdev->dev, "tsadc");
```

DTS clock IDs: `include/dt-bindings/clock/rk3399-cru.h`.

### Clock Driver

`drivers/clk/rockchip/clk-rk3399.c` — defines all RK3399 clock tree.

## Reset Control

### APIs

| API | Header | Notes |
|-----|--------|-------|
| `devm_reset_control_get()` | `include/linux/reset.h` | Managed get |
| `reset_control_assert()` | `include/linux/reset.h` | Assert reset |
| `reset_control_deassert()` | `include/linux/reset.h` | Deassert reset |
| `reset_control_reset()` | `include/linux/reset.h` | Pulse reset |

### Reset Driver

RK3399 resets are managed by `drivers/clk/rockchip/softrst.c` as part of the CRU driver.

## Common Failure: `-EPROBE_DEFER`

When a driver calls `devm_clk_get()`, `devm_regulator_get()`, or `devm_gpiod_get()` and the resource is provided by another driver that hasn't probed yet, the API returns `-EPROBE_DEFER`. The driver must propagate this error from probe — the core will retry later.

**Do not** treat `-EPROBE_DEFER` as a fatal error. Just return it from probe.

Search for providers not yet probed (read `.agent/local-target.md` for IP):
```bash
ssh root@<TARGET_IP> 'dmesg | grep -i "probe.*defer\|EPROBE_DEFER"'
```
