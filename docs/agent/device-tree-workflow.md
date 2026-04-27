# docs/agent/device-tree-workflow.md

**Scope**: DTS/DTSI modification workflow for the EMB3531 board.
**Local grounding**: Board DTS at `patches/kernel/rk3399-emb3531.dts`. SoC DTSI at `workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/rk3399.dtsi`. Bindings at `Documentation/devicetree/bindings/`.
**Pitfalls**: Never invent properties not in the YAML binding. Clock IDs from `include/dt-bindings/clock/rk3399-cru.h`. DTS edits must be in `patches/`, not just `workspace/`.

## Board DTS

- Path: `patches/kernel/rk3399-emb3531.dts`
- Includes: `rk3399.dtsi` (which includes `rk3399-base.dtsi`)
- Compatible: `"rockchip,emb3531", "rockchip,rk3399"`
- Installed to: `workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/` by `./sdk.sh patch`

## DTS Modification Checklist

### 1. Find YAML Binding

```bash
find workspace/linux-6.18.24/Documentation/devicetree/bindings/ -name '*.yaml' | xargs rg '<compatible-string>'
```

Key Rockchip binding paths:
- Clock: `Documentation/devicetree/bindings/clock/rockchip,rk3399-cru.yaml`
- PHY: `Documentation/devicetree/bindings/phy/rockchip,rk3399-*`
- MMC: `Documentation/devicetree/bindings/mmc/rockchip-dw-mshc.yaml`
- Net: `Documentation/devicetree/bindings/net/rockchip-dwmac.yaml`
- Pinctrl: `Documentation/devicetree/bindings/pinctrl/rockchip,pinctrl.yaml`
- Thermal: `Documentation/devicetree/bindings/thermal/rockchip-thermal.yaml`
- USB: `Documentation/devicetree/bindings/phy/rockchip,inno-usb2phy.yaml`

### 2. Find Existing DTS Examples

```bash
# Check other RK3399 boards for the same node
rg '&<node_label>' workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/rk3399-*.dts
```

### 3. Find Matched Driver

```bash
# Find the driver that handles the compatible string
rg '"<compatible>"' workspace/linux-6.18.24/drivers/ --include='*.c'
```

### 4. Validate Properties

For every property you add:
- Confirm it is listed in the YAML binding `properties:` section.
- Confirm the value type matches (bool, string, u32, array, phandle).
- If the property is not in the binding, stop and report.

### 5. Clock/Reset/Regulator/GPIO/Pinctrl/Interrupt Conventions

| Resource | DTS Property | Example in rk3399-emb3531.dts |
|----------|-------------|-------------------------------|
| Clocks | `clocks = <&cru ...>` | `assigned-clocks = <&cru SCLK_RMII_SRC>` |
| Resets | `resets = <&cru ...>` | (none in current DTS, but defined in rk3399.dtsi nodes) |
| Regulators | `<name>-supply = <&reg_label>` | `phy-supply = <&vcc_phy>`, `vqmmc-supply = <&vcc_sd>` |
| GPIOs | `<name>-gpios = <&gpioX PIN FLAG>` | `snps,reset-gpio = <&gpio3 RK_PB7 GPIO_ACTIVE_HIGH>` |
| Pinctrl | `pinctrl-names`, `pinctrl-0` | `pinctrl-0 = <&rgmii_pins>` |
| Interrupts | `interrupts = <...>`, `interrupt-parent` | `interrupts = <RK_PC5 IRQ_TYPE_LEVEL_LOW>` |

### 6. RK3399 DTS Include Hierarchy

```
rk3399-emb3531.dts
  └── rk3399.dtsi
        └── rk3399-base.dtsi
              └── <arm64 includes>
```

- `rk3399-base.dtsi`: SoC nodes (CPU, GIC, cru, etc.)
- `rk3399.dtsi`: Peripheral nodes (UART, I2C, SPI, USB, etc.)
- `rk3399-emb3531.dts`: Board-level overrides and enablement

### DTS Review Checklist

- [ ] `compatible` matches binding and driver `of_match_table`
- [ ] `reg` address matches hardware (for MMIO devices)
- [ ] `interrupts` / `interrupt-parent` correct
- [ ] `clocks` phandles valid, clock IDs from `include/dt-bindings/clock/rk3399-cru.h`
- [ ] `resets` phandles valid
- [ ] `pinctrl-names` / `pinctrl-0` reference valid pinctrl nodes
- [ ] Supply properties (`*-supply`) point to valid regulator nodes
- [ ] GPIO references use correct bank/pin/flags
- [ ] `status = "okay"` or `status = "disabled"` explicitly set
- [ ] No invented properties not found in the YAML binding
