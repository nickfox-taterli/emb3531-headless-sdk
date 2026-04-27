# docs/agent/examples/dts-node-checklist.md

Checklist for adding or modifying a device tree node in this project.

## Pre-Flight

- [ ] Read `docs/agent/device-tree-workflow.md`.
- [ ] Identify which DTS file to modify (`patches/kernel/rk3399-emb3531.dts` for board-level changes).

## Per-Node Checklist

### Required

- [ ] **compatible** — Must match both the YAML binding and the driver `of_match_table`.
  - Search: `rg '"your-compatible"' workspace/linux-6.18.24/Documentation/devicetree/bindings/`
  - Search: `rg '"your-compatible"' workspace/linux-6.18.24/drivers/ --include='*.c'`

- [ ] **status** — `"okay"` to enable, `"disabled"` to disable. Explicit is better than implicit.

### Common Properties (include only if the binding requires them)

- [ ] **reg** — MMIO base address + size. Use `<0x0 addr 0x0 size>` for ARM64.
  - Must not conflict with existing nodes in `rk3399.dtsi` or `rk3399-base.dtsi`.

- [ ] **interrupts** / **interrupt-parent** — Check the binding for required interrupt specifiers.
  - GIC SPI: `<GIC_SPI N IRQ_TYPE_LEVEL_HIGH>` (include `dt-bindings/interrupt-controller/arm-gic.h`).
  - GPIO: `<&gpioX PIN FLAG>` + `interrupt-parent = <&gpioX>`.

- [ ] **clocks** / **clock-names** — Phandles to `&cru` or other clock providers.
  - Use clock IDs from `include/dt-bindings/clock/rk3399-cru.h`.

- [ ] **resets** / **reset-names** — Phandles to `&cru` reset lines.

- [ ] **pinctrl-names** / **pinctrl-0** — Pin configuration states.
  - Define pin groups under `&pinctrl { ... }` in the board DTS.
  - Use `rockchip,pins = <bank pin func &pcfg_bias>;` format.

- [ ] **Supply properties** (`*-supply`) — Phandles to regulator nodes.
  - Common patterns: `phy-supply`, `vqmmc-supply`, `<name>-supply`.

- [ ] **GPIO properties** (`*-gpios` or `*-gpio`) — Phandles to GPIO banks.
  - Use `<&gpioN PIN FLAG>` format.
  - Check `include/dt-bindings/gpio/gpio.h` for flags.

### Validation

- [ ] **YAML binding checked** — Every property exists in the binding's `properties:` section.
  - If no binding exists, stop and report per `docs/agent/stop-rules.md`.

- [ ] **Existing examples checked** — At least one other RK3399 board uses this node similarly.
  - Search: `rg '&<node>' workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/rk3399-*.dts`

- [ ] **Driver match checked** — The compatible string matches a driver's `of_match_table`.
  - Search: `rg '"your-compatible"' workspace/linux-6.18.24/drivers/ --include='*.c'`

### Post-Edit

- [ ] **Patch updated** — Changes are in `patches/kernel/rk3399-emb3531.dts` (not just workspace).
- [ ] **DTB builds** — `./sdk.sh kernel` produces `rk3399-emb3531.dtb` without errors.
- [ ] **Boot test** — Flash and verify `dmesg` on target shows expected probe messages.

## Quick Reference: Property → DTS Pattern

| Property Type | DTS Pattern | Example |
|---------------|-------------|---------|
| compatible | `compatible = "vendor,device";` | `"rockchip,rk3399-tsadc"` |
| reg | `reg = <0x0 addr 0x0 size>;` | `reg = <0x0 0xff260000 0x0 0x100>;` |
| interrupts (GIC) | `interrupts = <GIC_SPI N IRQ_TYPE_LEVEL_HIGH>;` | `<GIC_SPI 43 IRQ_TYPE_LEVEL_HIGH>` |
| interrupts (GPIO) | `interrupts = <PIN FLAG>; interrupt-parent = <&gpioX>;` | `<RK_PC5 IRQ_TYPE_LEVEL_LOW>` |
| clocks | `clocks = <&cru CLK_ID>; clock-names = "name";` | `<&cru SCLK_TSADC>, <&cru PCLK_TSADC>` |
| resets | `resets = <&cru SRST_*>; reset-names = "name";` | Search: `rg 'SRST_' workspace/linux-6.18.24/include/dt-bindings/clock/rk3399-cru.h` |
| pinctrl | `pinctrl-names = "default"; pinctrl-0 = <&my_pins>;` | See board DTS pinctrl section |
| supplies | `<name>-supply = <&regulator>;` | `phy-supply = <&vcc_phy>` |
| GPIOs | `<name>-gpios = <&gpioX PIN FLAG>;` | `reset-gpios = <&gpio3 RK_PB7 GPIO_ACTIVE_HIGH>` |
| status | `status = "okay";` or `status = "disabled";` | Most nodes default to disabled |
