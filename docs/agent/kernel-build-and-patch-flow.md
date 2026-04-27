# docs/agent/kernel-build-and-patch-flow.md

**Scope**: Kernel build, config, and patch workflow. Always `ARCH=arm64`, `CROSS_COMPILE=aarch64-linux-gnu-`.
**Pitfalls**: `.config` is local to `workspace/`. Edits lost on `./sdk.sh clean`. Copy back to `patches/kernel/emb3531_headless_defconfig` to persist. Patches must survive a clean rebuild cycle.

## First Step

**Read `sdk.sh` before running any build command.** It defines all paths, toolchains, and sequences.

## Kernel Tree

- Path: `workspace/linux-6.18.24/`
- Version: Linux 6.18.24 (vanilla tarball, confirmed via `Makefile` line 2)
- Patch path: `patches/kernel/`
- New files: `patches/kernel/rk3399-emb3531.dts`, `patches/kernel/emb3531_headless_defconfig`

## Build Commands

All commands must include `ARCH=arm64` and `CROSS_COMPILE=aarch64-linux-gnu-`.

```bash
# Configure (uses emb3531_headless_defconfig)
make -C workspace/linux-6.18.24 CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 emb3531_headless_defconfig

# Build
make -C workspace/linux-6.18.24 CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$(nproc)

# Or use sdk.sh
./sdk.sh kernel
```

### Build Outputs

- `workspace/linux-6.18.24/arch/arm64/boot/Image` — kernel image
- `workspace/linux-6.18.24/arch/arm64/boot/dts/rockchip/rk3399-emb3531.dtb` — DTB
- `*.ko` files — kernel modules

### Warning: `.config`

The `.config` in the kernel tree is generated from `emb3531_headless_defconfig` during build. If you run `make menuconfig` or `make olddefconfig`, the resulting `.config` is local to `workspace/` and will be lost on re-fetch. To persist config changes, update `patches/kernel/emb3531_headless_defconfig`:

```bash
# After modifying .config via menuconfig:
cp workspace/linux-6.18.24/.config patches/kernel/emb3531_headless_defconfig
```

## Patch Workflow

### Applying Patches

Handled by `./sdk.sh patch`. It:
1. Applies `patches/kernel/*.patch` via `git apply`.
2. Copies `patches/kernel/rk3399-emb3531.dts` → `arch/arm64/boot/dts/rockchip/`.
3. Copies `patches/kernel/emb3531_headless_defconfig` → `arch/arm64/configs/`.

### Generating a New Patch

```bash
cd workspace/linux-6.18.24
# Make your changes, then:
git add -A
git diff --cached > ../../patches/kernel/NNNN-description.patch
# Or for unstaged:
git diff > ../../patches/kernel/NNNN-description.patch
```

### Updating an Existing Patch

```bash
cd workspace/linux-6.18.24
# Make changes on top of already-patched tree
git diff > ../../patches/kernel/0001-add-emb3531-dtb-to-makefile.patch
```

### Adding New Files

New DTS files, defconfigs, or headers can be:
1. Placed directly in `patches/kernel/` (sdk.sh copies them during patch phase).
2. Or included as part of a `.patch` file.

## Non-Persistence Warning

`workspace/` is git-ignored and regenerated from upstream sources by `./sdk.sh fetch`. Any edits not exported to `patches/` will be lost. Always verify your patches survive a clean rebuild:

```bash
./sdk.sh clean   # removes workspace/
./sdk.sh fetch   # re-fetches sources
./sdk.sh patch   # applies patches
./sdk.sh kernel  # rebuilds
```
