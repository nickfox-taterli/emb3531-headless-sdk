# docs/agent/rk3399-platform.md — RK3399 Platform Index

**Scope**: RK3399-specific facts for the EMB3531 headless server — DTS nodes, enabled/disabled subsystems, boot flow, clock/reset/pinctrl drivers.
**Local grounding**: DTS from `patches/kernel/rk3399-emb3531.dts`. Drivers from `workspace/linux-6.18.24/drivers/`.
**Pitfalls**: GPU, VPU, PCIe are disabled. Do not enable without explicit request. `CONFIG_EFI_PARTITION` is for GPT parsing, not UEFI boot.

## Not x86 Desktop Linux

This is an ARM64 embedded platform. Do not assume:
- UEFI firmware boot (this uses U-Boot + extlinux)
- ACPI (this uses Device Tree)
- PC-style peripherals (ISA, PCI BIOS, etc.)
- Standard PC boot flow (GRUB, systemd-boot, etc.)

## SoC Overview

- Rockchip RK3399: 2x Cortex-A72 @ 2GHz + 4x Cortex-A53 @ 1.5GHz
- Mali-T864 GPU (disabled in this SDK — headless use case)
- DDR3, up to 4GB
- This SDK is configured for **headless server** operation.

## DTS Paths

- Board DTS: `patches/kernel/rk3399-emb3531.dts`
- SoC DTSI: `workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/rk3399.dtsi`
- Base DTSI: `workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/rk3399-base.dtsi`
- Other RK3399 boards for reference: `workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/rk3399-*.dts`
- Clock IDs header: `workspace/linux-6.18.24/include/dt-bindings/clock/rk3399-cru.h`

## Clock/Reset/Pinctrl

- Clock driver: `workspace/linux-6.18.24/drivers/clk/rockchip/clk-rk3399.c`
- Clock IDs: `workspace/linux-6.18.24/include/dt-bindings/clock/rk3399-cru.h`
- Reset: handled by `drivers/clk/rockchip/softrst.c` (soft reset via CRU)
- Pinctrl driver: `workspace/linux-6.18.24/drivers/pinctrl/pinctrl-rockchip.c`
- Pinctrl header: `workspace/linux-6.18.24/drivers/pinctrl/pinctrl-rockchip.h`
- Pinctrl compatible: `"rockchip,rk3399-pinctrl"`
- Pinctrl binding: `Documentation/devicetree/bindings/pinctrl/rockchip,pinctrl.yaml`

## PCIe

- PCIe x4 is **disabled** in the board DTS (`status = "disabled"` on `&pcie0` and `&pcie_phy`).
- Hardware is present but deemed unstable during testing.
- Do not enable PCIe unless explicitly asked.

## USB

Board DTS enables:
- `&tcphy0`, `&tcphy1` — Type-C PHYs
- `&u2phy0`, `&u2phy1` — USB2 PHYs (with otg-port and host-port sub-nodes)
- `&usb_host0_ehci`, `&usb_host0_ohci` — EHCI/OHCI host controllers
- `&usb_host1_ehci`, `&usb_host1_ohci` — EHCI/OHCI host controllers
- `&usbdrd3_0`, `&usbdrd_dwc3_0` — DWC3 controller 0 (dr_mode = "host")
- `&usbdrd3_1`, `&usbdrd_dwc3_1` — DWC3 controller 1 (dr_mode = "host")
- `vcc5v0_host` regulator — always-on 5V for USB host ports
- PHY bindings: `rockchip,inno-usb2phy.yaml`, `rockchip,rk3399-typec-phy.yaml`

## MMC/eMMC

- `&sdhci` — eMMC (HS400, 8-bit, non-removable). Alias: `mmc2`.
- `&sdmmc` — MicroSD card (4-bit, high-speed). Alias: `mmc1`.
- eMMC PHY: `&emmc_phy` enabled.
- MMC binding: `Documentation/devicetree/bindings/mmc/rockchip-dw-mshc.yaml`
- eMMC PHY binding: `Documentation/devicetree/bindings/phy/rockchip,rk3399-emmc-phy.yaml`

## Ethernet (GMAC)

- `&gmac` — RGMII mode, connected to RTL8211F PHY.
- Clock: external 125MHz `clkin_gmac` fixed-clock.
- PHY reset: `snps,reset-gpio = <&gpio3 RK_PB7 GPIO_ACTIVE_HIGH>`.
- PHY supply: `vcc_phy` fixed regulator.
- Driver: `drivers/net/ethernet/stmicro/stmmac/` (dwmac-rockchip).
- Binding: `Documentation/devicetree/bindings/net/rockchip-dwmac.yaml`.

## Regulators

- PMIC: RK808 on I2C0 (`&i2c0`), address 0x1b.
  - Compatible: `"rockchip,rk808"`
  - Regulators: DCDC_REG1-4, LDO_REG1-8, SWITCH_REG1-2 (all defined in board DTS).
- CPU B regulator: Silergy SYR827 on I2C0, address 0x40 (`vdd_cpu_b`).
- GPU regulator: Silergy SYR828 on I2C0, address 0x41 (`vdd_gpu`).
- Fixed regulators: `dc_12v`, `vcc1v8_s3`, `vcc3v3_sys`, `vcc_sys`, `vcc_phy`, `vdd_log` (PWM), `vcca_0v9`, `vcc5v0_host`, `vcc12v_pcie`.

## Extlinux Boot Context

- Boot config: `boot/extlinux.conf`
- Boot flow: U-Boot SPL → U-Boot proper → extlinux boot → Linux Image + DTB
- Root device: `/dev/mmcblk2p4` (eMMC partition 4)
- Console: `ttyS2` at 115200 baud
- No UEFI, no GRUB, no initramfs (root on eMMC directly).

## Disabled Subsystems

These are explicitly disabled in DTS and/or defconfig. Do not enable without explicit request:

| Subsystem | DTS Node | Status |
|-----------|----------|--------|
| GPU (Mali-T864) | `&gpu` | disabled |
| VPU (video) | `&vpu` | disabled |
| VDEC (video decode) | `&vdec` | disabled |
| RGA (2D accel) | `&rga` | disabled |
| DFI/DMC devfreq | `&dfi` | disabled |
| PCIe x4 | `&pcie0`, `&pcie_phy` | disabled |

## GPT Partition Parsing

- `CONFIG_EFI_PARTITION=y` in defconfig — needed for GPT table parsing.
- This is **not** UEFI firmware boot. The boot path is U-Boot → extlinux → Linux.
- `block/partitions/Kconfig` defines this symbol.
