# docs/agent/index.md — Documentation Router

Read this file to find the right document for your task.

| Task | Document |
|------|----------|
| Repository layout, what lives where | [repo-map.md](repo-map.md) |
| When to stop instead of guessing | [stop-rules.md](stop-rules.md) |
| Kernel build, config, patch workflow | [kernel-build-and-patch-flow.md](kernel-build-and-patch-flow.md) |
| Search recipes (rg, grep) for kernel symbols | [kernel-search-recipes.md](kernel-search-recipes.md) |
| Kconfig symbol inspection | [kconfig-workflow.md](kconfig-workflow.md) |
| RK3399 platform specifics (DTS, clocks, USB, etc.) | [rk3399-platform.md](rk3399-platform.md) |
| DTS/DTSI modification workflow | [device-tree-workflow.md](device-tree-workflow.md) |
| Target board SSH testing | [target-test-workflow.md](target-test-workflow.md) |
| Platform driver development | [driver-development/platform-driver.md](driver-development/platform-driver.md) |
| Misc/char device development | [driver-development/misc-char-device.md](driver-development/misc-char-device.md) |
| USB driver development | [driver-development/usb-driver.md](driver-development/usb-driver.md) |
| GPIO/pinctrl/regulator/clock/reset APIs | [driver-development/gpio-pinctrl-regulator-clock-reset.md](driver-development/gpio-pinctrl-regulator-clock-reset.md) |
| IRQ/DMA/MMIO patterns | [driver-development/irq-dma-iomem.md](driver-development/irq-dma-iomem.md) |
| Debug and tracing | [driver-development/debug-and-tracing.md](driver-development/debug-and-tracing.md) |
| Minimal platform driver skeleton | [examples/minimal-platform-driver.md](examples/minimal-platform-driver.md) |
| Minimal misc device skeleton | [examples/minimal-misc-device.md](examples/minimal-misc-device.md) |
| Minimal USB driver skeleton | [examples/minimal-usb-driver.md](examples/minimal-usb-driver.md) |
| DTS node checklist | [examples/dts-node-checklist.md](examples/dts-node-checklist.md) |

## Reading Order for New Agents

1. `CLAUDE.md` — hard rules
2. `repo-map.md` — where things live
3. `stop-rules.md` — when to stop
4. Task-specific document from the table above
