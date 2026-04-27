#!/bin/bash
# ============================================================
# EMB3531 RK3399 SDK Build Script
# 一体化构建: 源码获取 → 补丁 → 编译 → rootfs → 打包镜像
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/workspace"
DOWNLOAD_DIR="${WORK_DIR}/downloads"
OUTPUT_DIR="${WORK_DIR}/output"
IMAGES_DIR="${OUTPUT_DIR}/images"
PATCHES_DIR="${SCRIPT_DIR}/patches"
ROOTFS_DIR="${SCRIPT_DIR}/rootfs"
BOOT_DIR="${SCRIPT_DIR}/boot"

# --- Toolchain ---
CROSS="aarch64-linux-gnu-"
JOBS="$(nproc)"
ARCH="arm64"

# --- Source versions / hashes ---
TF_A_REMOTE="https://github.com/TrustedFirmware-A/trusted-firmware-a.git"
TF_A_HASH="de387341ee73d99446fbbf6a7053d7b759b8b3a6"

UBOOT_REMOTE="https://source.denx.de/u-boot/u-boot.git"
UBOOT_HASH="9f61fd5b80a43ae20ba115e3a2933d47d720ab82"

KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.24.tar.xz"
KERNEL_TAR="linux-6.18.24.tar.xz"
KERNEL_DIR_NAME="linux-6.18.24"

# --- Debian rootfs ---
DEBIAN_SUITE="trixie"
DEBIAN_MIRROR="http://mirrors.tuna.tsinghua.edu.cn/debian"
ROOTFS_SIZE_MB="1200"
BOOT_SIZE_MB="64"

# --- Image layout ---
IMG_SIZE_MB="auto"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

die()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
step()  { echo -e "${YELLOW}[STEP]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║       EMB3531 RK3399 SDK Builder             ║"
    echo "║       ARM64 Headless Embedded Linux          ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

usage() {
    echo -e "${BOLD}用法:${NC} $0 [命令] [选项]"
    echo ""
    echo -e "${BOLD}命令:${NC}"
    echo "  all           完整构建 (fetch -> patch -> build -> rootfs -> image)"
    echo "  fetch         仅下载/克隆源码"
    echo "  patch         仅应用补丁"
    echo "  build         仅编译 (tf-a + u-boot + kernel)"
    echo "  tf-a          仅编译 TF-A"
    echo "  u-boot        仅编译 U-Boot"
    echo "  kernel        仅编译内核"
    echo "  rootfs        仅构建 rootfs (需要 qemu-aarch64-static)"
    echo "  image         仅打包最终磁盘镜像"
    echo "  clean         清理 workspace"
    echo "  status        显示当前构建状态"
    echo "  help          显示此帮助"
    echo ""
    echo -e "${BOLD}选项:${NC}"
    echo "  -j N          并行编译数 (默认: $(nproc))"
    echo "  -s SIZE       镜像大小 MB (默认: auto)"
    echo "  -h, --help    显示此帮助"
    echo ""
    echo -e "${BOLD}示例:${NC}"
    echo "  $0 all                    # 完整一键构建"
    echo "  $0 fetch && $0 patch      # 分步执行"
    echo "  $0 build -j 4             # 4 线程编译"
    echo "  $0 rootfs                 # 仅构建 rootfs"
    echo "  $0 image -s 8192          # 打包 8GB 镜像"
}

# ============================================================
# Source Acquisition
# ============================================================

fetch_tf_a() {
    step "获取 TF-A 源码..."
    local dir="${WORK_DIR}/trusted-firmware-a"
    if [ -d "$dir/.git" ]; then
        info "TF-A 已存在, 检查版本..."
        cd "$dir"
        local current
        current=$(git rev-parse HEAD)
        if [ "$current" = "$TF_A_HASH" ]; then
            info "TF-A 版本匹配: ${TF_A_HASH:0:12}"
            return
        fi
        warn "版本不匹配, 重新checkout..."
    else
        info "克隆 TF-A: ${TF_A_REMOTE}"
        git clone --no-tags "${TF_A_REMOTE}" "$dir"
        cd "$dir"
    fi
    git fetch origin
    git checkout "${TF_A_HASH}"
    info "TF-A 就绪: $(git log --oneline -1)"
}

fetch_u_boot() {
    step "获取 U-Boot 源码..."
    local dir="${WORK_DIR}/u-boot"
    if [ -d "$dir/.git" ]; then
        info "U-Boot 已存在, 检查版本..."
        cd "$dir"
        local current
        current=$(git rev-parse HEAD)
        if [ "$current" = "$UBOOT_HASH" ]; then
            info "U-Boot 版本匹配: ${UBOOT_HASH:0:12}"
            return
        fi
        warn "版本不匹配, 重新checkout..."
    else
        info "克隆 U-Boot: ${UBOOT_REMOTE}"
        git clone --no-tags "${UBOOT_REMOTE}" "$dir"
        cd "$dir"
    fi
    git fetch origin
    git checkout "${UBOOT_HASH}"
    info "U-Boot 就绪: $(git log --oneline -1)"
}

fetch_kernel() {
    step "获取内核源码..."
    local tar="${DOWNLOAD_DIR}/${KERNEL_TAR}"
    local dir="${WORK_DIR}/${KERNEL_DIR_NAME}"

    mkdir -p "${DOWNLOAD_DIR}"

    if [ -d "$dir" ] && [ -f "$dir/Makefile" ]; then
        info "内核源码已存在: $dir"
        return
    fi

    if [ ! -f "$tar" ]; then
        info "下载内核: ${KERNEL_URL}"
        wget -O "$tar" "${KERNEL_URL}"
    fi

    info "验证下载完整性..."
    local tar_size
    tar_size=$(stat -Lc%s "$tar" 2>/dev/null || stat -c%s "$tar" 2>/dev/null || echo 0)
    if [ "$tar_size" -lt 100000000 ]; then
        die "内核 tarball 似乎不完整 (${tar_size} bytes)"
    fi

    info "解压内核..."
    tar xf "$tar" -C "${WORK_DIR}"
    cd "$dir"
    git init
    git add -A
    git commit -m "Vanilla linux-${KERNEL_DIR_NAME#linux-}" --quiet
    info "内核就绪: ${KERNEL_DIR_NAME}"
}

do_fetch() {
    mkdir -p "${WORK_DIR}" "${DOWNLOAD_DIR}"
    fetch_tf_a
    fetch_u_boot
    fetch_kernel
    info "所有源码获取完成"
}

# ============================================================
# Patching
# ============================================================

patch_tf_a() {
    step "补丁 TF-A..."
    local dir="${WORK_DIR}/trusted-firmware-a"
    cd "$dir"

    # Check if already patched
    if git diff --stat HEAD | grep -q "addressmap_shared\|rk3399_def"; then
        info "TF-A 补丁已应用"
        return
    fi

    for p in "${PATCHES_DIR}"/tf-a/*.patch; do
        [ -f "$p" ] || continue
        info "应用: $(basename "$p")"
        git apply --check "$p" && git apply "$p" || die "补丁失败: $p"
    done
    info "TF-A 补丁完成"
}

patch_u_boot() {
    step "补丁 U-Boot..."
    local dir="${WORK_DIR}/u-boot"
    cd "$dir"

    # Apply git patches
    for p in "${PATCHES_DIR}"/u-boot/*.patch; do
        [ -f "$p" ] || continue
        # Check if already applied
        if git apply --check "$p" 2>/dev/null; then
            info "应用: $(basename "$p")"
            git apply "$p" || die "补丁失败: $p"
        else
            info "跳过(已应用): $(basename "$p")"
        fi
    done

    # Copy new files
    local pd="${PATCHES_DIR}/u-boot"
    [ -f "${pd}/emb3531-rk3399_defconfig" ] && cp "${pd}/emb3531-rk3399_defconfig" configs/
    [ -f "${pd}/rk3399-emb3531-u-boot.dtsi" ] && cp "${pd}/rk3399-emb3531-u-boot.dtsi" arch/arm/dts/
    [ -f "${pd}/rk3399-emb3531.dts" ] && {
        mkdir -p dts/upstream/src/arm64/rockchip/
        cp "${pd}/rk3399-emb3531.dts" dts/upstream/src/arm64/rockchip/
    }
    info "U-Boot 补丁完成"
}

patch_kernel() {
    step "补丁内核..."
    local dir="${WORK_DIR}/${KERNEL_DIR_NAME}"
    cd "$dir"

    # Apply patches
    for p in "${PATCHES_DIR}"/kernel/*.patch; do
        [ -f "$p" ] || continue
        if git apply --check "$p" 2>/dev/null; then
            info "应用: $(basename "$p")"
            git apply "$p" || die "补丁失败: $p"
        else
            info "跳过(已应用): $(basename "$p")"
        fi
    done

    # Copy new files
    local pd="${PATCHES_DIR}/kernel"
    [ -f "${pd}/rk3399-emb3531.dts" ] && {
        cp "${pd}/rk3399-emb3531.dts" arch/arm64/boot/dts/rockchip/
    }
    [ -f "${pd}/emb3531_headless_defconfig" ] && {
        cp "${pd}/emb3531_headless_defconfig" arch/arm64/configs/
    }
    info "内核补丁完成"
}

do_patch() {
    patch_tf_a
    patch_u_boot
    patch_kernel
    info "所有补丁应用完成"
}

# ============================================================
# Building
# ============================================================

build_tf_a() {
    step "编译 TF-A (bl31.elf)..."
    local dir="${WORK_DIR}/trusted-firmware-a"
    local bl31="${dir}/build/rk3399/release/bl31/bl31.elf"

    make -C "$dir" CROSS_COMPILE="$CROSS" PLAT=rk3399 -j"$JOBS"
    [ -f "$bl31" ] || die "TF-A 编译失败: bl31.elf 缺失"
    info "TF-A 完成: $bl31"
}

build_u_boot() {
    step "编译 U-Boot..."
    local dir="${WORK_DIR}/u-boot"
    local bl31="${WORK_DIR}/trusted-firmware-a/build/rk3399/release/bl31/bl31.elf"

    [ -f "$bl31" ] || { info "bl31.elf 不存在, 先编译 TF-A..."; build_tf_a; }

    make -C "$dir" CROSS_COMPILE="$CROSS" emb3531-rk3399_defconfig
    make -C "$dir" CROSS_COMPILE="$CROSS" BL31="$bl31" -j"$JOBS"

    [ -f "${dir}/idbloader.img" ] || die "U-Boot 编译失败: idbloader.img 缺失"
    [ -f "${dir}/u-boot.itb" ] || die "U-Boot 编译失败: u-boot.itb 缺失"
    info "U-Boot 完成"
}

build_kernel() {
    step "编译内核..."
    local dir="${WORK_DIR}/${KERNEL_DIR_NAME}"

    if [ ! -f "${dir}/.config" ]; then
        info "使用 emb3531_headless_defconfig..."
        make -C "$dir" CROSS_COMPILE="$CROSS" ARCH="$ARCH" emb3531_headless_defconfig
    fi

    make -C "$dir" CROSS_COMPILE="$CROSS" ARCH="$ARCH" -j"$JOBS"

    [ -f "${dir}/arch/arm64/boot/Image" ] || die "内核编译失败: Image 缺失"
    [ -f "${dir}/arch/arm64/boot/dts/rockchip/rk3399-emb3531.dtb" ] || die "DTB 缺失"
    info "内核完成: Image + DTB + $(find "${dir}" -name '*.ko' | wc -l) 个模块"
}

do_build() {
    mkdir -p "${IMAGES_DIR}"
    build_tf_a
    build_u_boot
    build_kernel

    # Copy outputs
    cp "${WORK_DIR}/u-boot/idbloader.img" "${IMAGES_DIR}/"
    cp "${WORK_DIR}/u-boot/u-boot.itb" "${IMAGES_DIR}/"
    info "所有编译产物已同步到 ${IMAGES_DIR}/"
}

# ============================================================
# Rootfs
# ============================================================

build_rootfs() {
    step "构建 Debian ${DEBIAN_SUITE} rootfs..."

    # Check prerequisites
    command -v qemu-aarch64-static >/dev/null 2>&1 || command -v qemu-aarch64 >/dev/null 2>&1 || {
        die "需要 qemu-user-static: apt install qemu-user-static"
    }
    command -v debootstrap >/dev/null 2>&1 || die "需要 debootstrap: apt install debootstrap"
    command -v dpkg >/dev/null 2>&1 || die "需要 dpkg (在 Debian/Ubuntu 主机上构建)"

    local rootfs_img="${IMAGES_DIR}/rootfs.img"
    local rootfs_mnt="/tmp/emb-reborn-rootfs"

    # Read package list
    local pkglist
    pkglist=$(grep -v '^#' "${ROOTFS_DIR}/pkglist.txt" | grep -v '^$' | tr '\n' ' ')

    # Stage 1: debootstrap — always start fresh
    local stage_dir="${WORK_DIR}/rootfs.staging"
    if [ -d "${stage_dir}" ]; then
        info "清除旧 staging 目录..."
        rm -rf "${stage_dir}"
    fi
    info "Stage 1: debootstrap --foreign..."
    debootstrap --no-check-gpg --arch=arm64 --foreign \
        "${DEBIAN_SUITE}" "${stage_dir}" "${DEBIAN_MIRROR}"

    # Copy qemu for chroot
    local qemu_bin
    qemu_bin=$(which qemu-aarch64-static 2>/dev/null || which qemu-aarch64 2>/dev/null || true)
    if [ -n "$qemu_bin" ]; then
        cp "$qemu_bin" "${stage_dir}/usr/bin/qemu-aarch64-static"
    fi

    # Configure apt sources inside chroot
    cp "${ROOTFS_DIR}/etc/apt/sources.list" "${stage_dir}/etc/apt/sources.list"

    # Stage 2: second stage
    info "Stage 2: debootstrap second-stage..."
    chroot "${stage_dir}" /debootstrap/debootstrap --second-stage

    # Mount proc/dev/sys for chroot
    mount -t proc proc "${stage_dir}/proc" 2>/dev/null || true
    mount -t sysfs sysfs "${stage_dir}/sys" 2>/dev/null || true
    mount -o bind /dev "${stage_dir}/dev" 2>/dev/null || true

    # Install packages
    info "安装软件包..."
    chroot "${stage_dir}" bash -c "
        apt-get update &&
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${pkglist}
    " || warn "部分包安装可能失败"

    # Apply configurations
    info "应用自定义配置..."
    cp "${ROOTFS_DIR}/etc/fstab" "${stage_dir}/etc/fstab"
    cp "${ROOTFS_DIR}/etc/hostname" "${stage_dir}/etc/hostname"
    cp "${ROOTFS_DIR}/etc/resolv.conf" "${stage_dir}/etc/resolv.conf"
    cp "${ROOTFS_DIR}/etc/locale.gen" "${stage_dir}/etc/locale.gen"
    cp "${ROOTFS_DIR}/etc/chrony/chrony.conf" "${stage_dir}/etc/chrony/chrony.conf"
    cp "${ROOTFS_DIR}/etc/ssh/sshd_config" "${stage_dir}/etc/ssh/sshd_config"
    cp "${ROOTFS_DIR}/etc/nftables.conf" "${stage_dir}/etc/nftables.conf"
    cp "${ROOTFS_DIR}/usr/local/sbin/emb3531-firstboot.sh" "${stage_dir}/usr/local/sbin/"
    chmod 755 "${stage_dir}/usr/local/sbin/emb3531-firstboot.sh"
    cp "${ROOTFS_DIR}/etc/systemd/emb3531-firstboot.service" "${stage_dir}/etc/systemd/system/"
    ln -sf /usr/lib/systemd/system/multi-user.target "${stage_dir}/etc/systemd/system/default.target"
    mkdir -p "${stage_dir}/etc/systemd/system/multi-user.target.wants"
    ln -sf ../emb3531-firstboot.service "${stage_dir}/etc/systemd/system/multi-user.target.wants/emb3531-firstboot.service"

    # systemd-networkd: DHCP on eth0
    mkdir -p "${stage_dir}/etc/systemd/network"
    cp "${ROOTFS_DIR}/etc/systemd/network/10-ethernet-dhcp.network" "${stage_dir}/etc/systemd/network/"
    chroot "${stage_dir}" systemctl enable systemd-networkd || true

    # Locale and timezone (Asia/Shanghai = UTC+8, 北京时间)
    cp "${ROOTFS_DIR}/etc/default/locale" "${stage_dir}/etc/default/locale"
    chroot "${stage_dir}" locale-gen || true
    chroot "${stage_dir}" bash -c "echo 'Asia/Shanghai' > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata" || true

    # Enable services
    chroot "${stage_dir}" systemctl enable ssh || true
    chroot "${stage_dir}" systemctl enable chrony || true
    chroot "${stage_dir}" systemctl enable cron || true
    # Remove ifupdown entirely (systemd-networkd is the sole network manager)
    chroot "${stage_dir}" apt-get purge -y ifupdown 2>/dev/null || true
    rm -f "${stage_dir}/etc/systemd/system/multi-user.target.wants/networking.service" 2>/dev/null || true

    # Set root password to empty (no password, direct login)
    chroot "${stage_dir}" bash -c "passwd -d root" || true

    # Cleanup
    info "清理 rootfs..."
    umount "${stage_dir}/proc" 2>/dev/null || true
    umount "${stage_dir}/sys" 2>/dev/null || true
    umount "${stage_dir}/dev" 2>/dev/null || true
    rm -rf "${stage_dir}/var/cache/apt"/*
    rm -rf "${stage_dir}/var/lib/apt/lists"/*
    rm -rf "${stage_dir}/var/log"/*
    rm -rf "${stage_dir}/var/tmp"/*
    rm -rf "${stage_dir}/tmp"/*
    rm -f "${stage_dir}/usr/bin/qemu-aarch64-static"

    # Create rootfs.img
    info "生成 rootfs.img (${ROOTFS_SIZE_MB}MB)..."
    dd if=/dev/zero of="$rootfs_img" bs=1M count=0 seek="$ROOTFS_SIZE_MB" 2>&1 | tail -1
    mkfs.ext4 -F -L rootfs "$rootfs_img" >/dev/null 2>&1

    mkdir -p "$rootfs_mnt"
    mount -o loop,rw "$rootfs_img" "$rootfs_mnt"
    info "复制 rootfs..."
    cd "${stage_dir}" && tar cf - . | tar -C "$rootfs_mnt" -xf -
    cd "$SCRIPT_DIR"
    sync
    umount "$rootfs_mnt"
    rmdir "$rootfs_mnt" 2>/dev/null || true

    # Clean up staging directory
    info "清理 staging 目录..."
    rm -rf "${stage_dir}"

    info "rootfs 完成: $rootfs_img ($(ls -lh "$rootfs_img" | awk '{print $5}'))"
}

# ============================================================
# Boot image
# ============================================================

build_boot_img() {
    step "构建 boot.img..."
    local kernel_dir="${WORK_DIR}/${KERNEL_DIR_NAME}"
    local boot_img="${IMAGES_DIR}/boot.img"
    local boot_mnt="/tmp/emb-reborn-boot"

    [ -f "${kernel_dir}/arch/arm64/boot/Image" ] || die "内核 Image 缺失"
    [ -f "${kernel_dir}/arch/arm64/boot/dts/rockchip/rk3399-emb3531.dtb" ] || die "DTB 缺失"

    dd if=/dev/zero of="$boot_img" bs=1M count=0 seek="$BOOT_SIZE_MB" 2>&1 | tail -1
    mkfs.ext4 -F -L boot "$boot_img" >/dev/null 2>&1

    mkdir -p "$boot_mnt"
    mount -o loop,rw "$boot_img" "$boot_mnt"

    cp "${kernel_dir}/arch/arm64/boot/Image" "${boot_mnt}/Image"
    mkdir -p "${boot_mnt}/dtb"
    cp "${kernel_dir}/arch/arm64/boot/dts/rockchip/rk3399-emb3531.dtb" "${boot_mnt}/dtb/"
    mkdir -p "${boot_mnt}/extlinux"
    cp "${BOOT_DIR}/extlinux.conf" "${boot_mnt}/extlinux/"

    sync
    umount "$boot_mnt"
    rmdir "$boot_mnt" 2>/dev/null || true

    info "boot.img 完成: $boot_img"
}

# ============================================================
# Final Image (flash.sh logic)
# ============================================================

build_image() {
    step "打包最终磁盘镜像..."
    local output_img="${OUTPUT_DIR}/emb3531.img"
    local kernel_dir="${WORK_DIR}/${KERNEL_DIR_NAME}"

    # Check all inputs
    for f in idbloader.img u-boot.itb boot.img rootfs.img; do
        [ -f "${IMAGES_DIR}/$f" ] || die "缺少: ${IMAGES_DIR}/$f (先运行 build/rootfs)"
    done

    # Install kernel modules into rootfs
    info "安装内核模块到 rootfs..."
    local mod_mnt="/tmp/emb-reborn-mod"
    mkdir -p "$mod_mnt"
    mount -o loop,rw "${IMAGES_DIR}/rootfs.img" "$mod_mnt" || die "挂载 rootfs 失败"

    rm -rf "${mod_mnt}/lib/modules"/*
    make -C "$kernel_dir" CROSS_COMPILE="$CROSS" ARCH="$ARCH" \
        INSTALL_MOD_PATH="$mod_mnt" INSTALL_MOD_STRIP=1 modules_install
    find "${mod_mnt}/lib/modules" -maxdepth 2 \( -name 'build' -o -name 'source' \) -delete

    # Cleanup rootfs
    rm -rf "${mod_mnt}/var/cache/apt"/* "${mod_mnt}/var/lib/apt/lists"/*
    rm -rf "${mod_mnt}/var/log"/* "${mod_mnt}/var/tmp"/* "${mod_mnt}/tmp"/*

    sync
    umount "$mod_mnt"
    rmdir "$mod_mnt" 2>/dev/null || true

    # Shrink rootfs
    local rootfs_size
    rootfs_size=$(stat -c%s "${IMAGES_DIR}/rootfs.img")
    local rootfs_mb=$(( rootfs_size / 1024 / 1024 ))

    mkdir -p "$mod_mnt"
    mount -o loop,ro "${IMAGES_DIR}/rootfs.img" "$mod_mnt"
    local used_kb
    used_kb=$(df -P "$mod_mnt" | tail -1 | awk '{print $3}')
    umount "$mod_mnt"
    rmdir "$mod_mnt" 2>/dev/null || true

    local used_mb=$(( (used_kb + 1023) / 1024 ))
    local compact_mb=$(( used_mb + 50 ))

    if [ "$compact_mb" -lt "$rootfs_mb" ]; then
        info "收缩 rootfs: ${rootfs_mb}MB → ${compact_mb}MB"
        local compact="${IMAGES_DIR}/rootfs.compact.img"
        dd if=/dev/zero of="$compact" bs=1M count="$compact_mb" 2>&1 | tail -1
        mkfs.ext4 -F -L rootfs "$compact" >/dev/null 2>&1

        mkdir -p /tmp/emb-shrink-src /tmp/emb-shrink-dst
        mount -o loop,ro "${IMAGES_DIR}/rootfs.img" /tmp/emb-shrink-src
        mount -o loop,rw "$compact" /tmp/emb-shrink-dst
        cd /tmp/emb-shrink-src && tar cf - . | tar -C /tmp/emb-shrink-dst -xf -
        cd "$SCRIPT_DIR"
        sync
        umount /tmp/emb-shrink-src /tmp/emb-shrink-dst
        rmdir /tmp/emb-shrink-src /tmp/emb-shrink-dst 2>/dev/null || true
        mv "$compact" "${IMAGES_DIR}/rootfs.img"
        rootfs_mb=$compact_mb
    fi

    rootfs_size=$(stat -c%s "${IMAGES_DIR}/rootfs.img")
    rootfs_mb=$(( rootfs_size / 1024 / 1024 ))

    # Calculate partition layout
    local IDBLOADER_START=64
    local IDBLOADER_END=16383
    local UBOOT_START=16384

    local uboot_size
    uboot_size=$(stat -c%s "${IMAGES_DIR}/u-boot.itb")
    local uboot_sectors=$(( (uboot_size + 511) / 512 ))
    local uboot_end=$(( UBOOT_START + uboot_sectors - 1 ))

    local boot_mnt2="/tmp/emb-boot-size"
    mkdir -p "$boot_mnt2"
    mount -o loop,ro "${IMAGES_DIR}/boot.img" "$boot_mnt2"
    local boot_content_kb
    boot_content_kb=$(df -P "$boot_mnt2" | tail -1 | awk '{print $3}')
    umount "$boot_mnt2"
    rmdir "$boot_mnt2" 2>/dev/null || true

    local boot_content_mb=$(( (boot_content_kb + 1023) / 1024 ))
    local boot_part_mb=$(( boot_content_mb + 4 ))
    local boot_sectors=$(( boot_part_mb * 1024 * 1024 / 512 ))
    local boot_start=$(( uboot_end + 1 ))
    local boot_end=$(( boot_start + boot_sectors - 1 ))

    local rootfs_start=$(( boot_end + 1 ))

    local min_needed=$(( rootfs_start * 512 / 1024 / 1024 + rootfs_mb + 1 ))
    local img_size_mb="${IMG_SIZE_MB}"
    if [ "$img_size_mb" = "auto" ] || [ "$img_size_mb" -lt "$min_needed" ] 2>/dev/null; then
        img_size_mb=$min_needed
    fi

    info "========================================"
    info "  镜像大小: ${img_size_mb}MB"
    info "  idbloader: ${IDBLOADER_START} - ${IDBLOADER_END}"
    info "  uboot:     ${UBOOT_START} - ${uboot_end}"
    info "  boot:      ${boot_start} - ${boot_end} (~${boot_part_mb}MB)"
    info "  rootfs:    ${rootfs_start} - end (${rootfs_mb}MB)"
    info "========================================"

    # Create image
    info "创建 ${img_size_mb}MB 空白镜像..."
    dd if=/dev/zero of="$output_img" bs=1M count=0 seek="$img_size_mb" 2>&1 | tail -1

    local total_sectors=$(( img_size_mb * 1024 * 1024 / 512 ))
    local rootfs_end=$(( total_sectors - 34 ))

    info "设置 loop 设备..."
    local loop_dev
    loop_dev=$(losetup --find --show --partscan "$output_img")

    cleanup_loop() {
        info "清理 loop..."
        umount "${loop_dev}p3" 2>/dev/null || true
        umount "${loop_dev}p4" 2>/dev/null || true
        umount /tmp/emb-final-boot-src 2>/dev/null || true
        umount /tmp/emb-final-boot-dst 2>/dev/null || true
        umount /tmp/emb-final-rootfs-src 2>/dev/null || true
        umount /tmp/emb-final-rootfs-dst 2>/dev/null || true
        losetup -d "$loop_dev" 2>/dev/null || true
        rmdir /tmp/emb-final-boot-src /tmp/emb-final-boot-dst 2>/dev/null || true
        rmdir /tmp/emb-final-rootfs-src /tmp/emb-final-rootfs-dst 2>/dev/null || true
    }
    trap cleanup_loop EXIT

    info "创建 GPT 分区表..."
    parted -s --align none "$loop_dev" mklabel gpt \
        mkpart idbloader "${IDBLOADER_START}s" "${IDBLOADER_END}s" \
        mkpart uboot "${UBOOT_START}s" "${uboot_end}s" \
        mkpart boot "${boot_start}s" "${boot_end}s" \
        mkpart rootfs "${rootfs_start}s" "${rootfs_end}s" \
        set 3 boot on \
        print

    partprobe "$loop_dev" 2>/dev/null || true
    sleep 1

    # Write idbloader
    info "写入 idbloader..."
    dd if="${IMAGES_DIR}/idbloader.img" of="$loop_dev" bs=512 seek=64 conv=fsync status=none

    # Write u-boot.itb
    info "写入 u-boot.itb..."
    dd if="${IMAGES_DIR}/u-boot.itb" of="$loop_dev" bs=512 seek=16384 conv=fsync status=none

    # Find partition devices
    local boot_part="" rootfs_part=""
    for p in "${loop_dev}p3" "${loop_dev}3"; do
        [ -b "$p" ] && boot_part="$p" && break
    done
    for p in "${loop_dev}p4" "${loop_dev}4"; do
        [ -b "$p" ] && rootfs_part="$p" && break
    done
    [ -n "$boot_part" ] || die "找不到 boot 分区"
    [ -n "$rootfs_part" ] || die "找不到 rootfs 分区"

    # Write boot
    info "写入 boot..."
    mkfs.ext4 -F -L boot "$boot_part" >/dev/null 2>&1
    mkdir -p /tmp/emb-final-boot-dst /tmp/emb-final-boot-src
    mount "$boot_part" /tmp/emb-final-boot-dst
    mount -o loop,ro "${IMAGES_DIR}/boot.img" /tmp/emb-final-boot-src
    cp -a /tmp/emb-final-boot-src/* /tmp/emb-final-boot-dst/
    umount /tmp/emb-final-boot-src /tmp/emb-final-boot-dst

    # Write rootfs
    info "写入 rootfs..."
    mkfs.ext4 -F -L rootfs "$rootfs_part" >/dev/null 2>&1
    mkdir -p /tmp/emb-final-rootfs-dst /tmp/emb-final-rootfs-src
    mount "$rootfs_part" /tmp/emb-final-rootfs-dst
    mount -o loop,ro "${IMAGES_DIR}/rootfs.img" /tmp/emb-final-rootfs-src
    info "复制 rootfs (${rootfs_mb}MB)..."
    cd /tmp/emb-final-rootfs-src && tar cf - . | tar -C /tmp/emb-final-rootfs-dst -xf -
    cd "$SCRIPT_DIR"
    umount /tmp/emb-final-rootfs-src /tmp/emb-final-rootfs-dst
    rmdir /tmp/emb-final-boot-dst /tmp/emb-final-boot-src 2>/dev/null || true
    rmdir /tmp/emb-final-rootfs-dst /tmp/emb-final-rootfs-src 2>/dev/null || true

    sync

    # Finalize
    trap - EXIT
    losetup -d "$loop_dev" 2>/dev/null || true

    info ""
    info "========================================"
    info "  镜像生成完成!"
    info "  文件: ${output_img}"
    info "  大小: $(ls -lh "$output_img" | awk '{print $5}')"
    info "========================================"
}

# ============================================================
# Status
# ============================================================

show_status() {
    echo -e "\033[1mEMB3531 SDK 构建状态\033[0m"
    echo "----------------------------------------"

    # TF-A
    local tfa="${WORK_DIR}/trusted-firmware-a"
    if [ -d "$tfa/.git" ]; then
        local h
        h=$(cd "$tfa" && git rev-parse --short HEAD)
        echo -e "  TF-A:      \033[0;32mOK\033[0m ${h}"
    else
        echo -e "  TF-A:      \033[0;31mMISSING\033[0m"
    fi

    # U-Boot
    local uboot="${WORK_DIR}/u-boot"
    if [ -d "$uboot/.git" ]; then
        local h
        h=$(cd "$uboot" && git rev-parse --short HEAD)
        echo -e "  U-Boot:    \033[0;32mOK\033[0m ${h}"
    else
        echo -e "  U-Boot:    \033[0;31mMISSING\033[0m"
    fi

    # Kernel
    local kernel="${WORK_DIR}/${KERNEL_DIR_NAME}"
    if [ -d "$kernel" ]; then
        echo -e "  Kernel:    \033[0;32mOK\033[0m ${KERNEL_DIR_NAME}"
    else
        echo -e "  Kernel:    \033[0;31mMISSING\033[0m"
    fi

    # Images
    echo ""
    for f in idbloader.img u-boot.itb boot.img rootfs.img emb3531.img; do
        if [ -f "${IMAGES_DIR}/$f" ] || [ -f "${OUTPUT_DIR}/$f" ]; then
            local sz
            sz=$(ls -lh "${IMAGES_DIR}/$f" 2>/dev/null || ls -lh "${OUTPUT_DIR}/$f" 2>/dev/null | awk '{print $5}')
            echo -e "  ${f}: \033[0;32mOK\033[0m ${sz}"
        else
            echo -e "  ${f}: \033[0;31mMISSING\033[0m"
        fi
    done
}

# ============================================================
# Clean
# ============================================================

do_clean() {
    warn "将删除: ${WORK_DIR}/"
    read -rp "确认? [y/N] " ans
    [ "$ans" = "y" ] || [ "$ans" = "Y" ] || { info "已取消"; return; }
    # Unmount anything first
    for mnt in /tmp/emb-reborn-* /tmp/emb-shrink-* /tmp/emb-final-*; do
        umount "$mnt" 2>/dev/null || true
        rmdir "$mnt" 2>/dev/null || true
    done
    rm -rf "${WORK_DIR}"
    info "清理完成"
}

# ============================================================
# Main
# ============================================================

main() {
    banner

    local cmd="${1:-help}"
    shift 2>/dev/null || true

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            -j) JOBS="$2"; shift 2 ;;
            -s) IMG_SIZE_MB="$2"; shift 2 ;;
            -h|--help) cmd="help"; shift ;;
            *) die "未知选项: $1" ;;
        esac
    done

    case "$cmd" in
        all)
            do_fetch
            do_patch
            do_build
            build_boot_img
            build_rootfs
            build_image
            ;;
        fetch)  do_fetch ;;
        patch)  do_patch ;;
        build)
            do_build
            build_boot_img
            ;;
        tf-a)   build_tf_a ;;
        u-boot) build_u_boot ;;
        kernel) build_kernel ;;
        rootfs) build_rootfs ;;
        image)  build_image ;;
        boot)   build_boot_img ;;
        status) show_status ;;
        clean)  do_clean ;;
        help|*) usage ;;
    esac
}

main "$@"
