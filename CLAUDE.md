# CLAUDE.md — EMB3531 RK3399 SDK Agent Instructions

## Hard Rules

1. **Target platform**: Rockchip RK3399, ARM64. Always `ARCH=arm64` for kernel work.
2. **Cross-compiler**: `CROSS_COMPILE=aarch64-linux-gnu-` unless `sdk.sh` or project scripts override.
3. **`workspace/` is local and non-persistent**. It is git-ignored. Changes in `workspace/` trees are lost if not exported.
4. **Persistent source changes must be exported to `patches/`**. See `docs/agent/kernel-build-and-patch-flow.md`.
5. **Do not guess unsupported topics**. If the local tree lacks the symbol, API, binding, or example, stop and report. See `docs/agent/stop-rules.md`.
6. **Read `sdk.sh` before inventing build, patch, or image commands**. It is the authoritative build orchestrator.
7. **Do not commit `.agent/`**. It contains lab-only access details.
8. **Read `.agent/local-target.md`** if present, for target board SSH access.

## Quick Reference

- Build all: `./sdk.sh all`
- Build kernel only: `./sdk.sh kernel`
- Apply patches: `./sdk.sh patch`
- Status: `./sdk.sh status`
- See `sdk.sh help` for full usage.

## Documentation Router

| Task | Read |
|------|------|
| Repository layout, workspace vs patches | `docs/agent/repo-map.md` |
| Patch workflow | `docs/agent/kernel-build-and-patch-flow.md` |
| Kernel build/config | `docs/agent/kernel-build-and-patch-flow.md` |
| Kernel search recipes | `docs/agent/kernel-search-recipes.md` |
| Kconfig workflow | `docs/agent/kconfig-workflow.md` |
| RK3399 platform index | `docs/agent/rk3399-platform.md` |
| Device tree workflow | `docs/agent/device-tree-workflow.md` |
| Target board testing | `docs/agent/target-test-workflow.md` |
| Platform driver dev | `docs/agent/driver-development/platform-driver.md` |
| Misc/char device dev | `docs/agent/driver-development/misc-char-device.md` |
| USB driver dev | `docs/agent/driver-development/usb-driver.md` |
| GPIO/pinctrl/regulator/clock/reset | `docs/agent/driver-development/gpio-pinctrl-regulator-clock-reset.md` |
| IRQ/DMA/MMIO | `docs/agent/driver-development/irq-dma-iomem.md` |
| Debug and tracing | `docs/agent/driver-development/debug-and-tracing.md` |
| Example skeletons | `docs/agent/examples/` |
| When to stop | `docs/agent/stop-rules.md` |
