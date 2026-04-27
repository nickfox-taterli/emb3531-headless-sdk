# EMB3531 RK3399 Headless Server SDK (主线)

[![Build EMB3531 Image](https://github.com/nickfox-taterli/emb3531_headless-sdk/actions/workflows/build.yml/badge.svg)](https://github.com/nickfox-taterli/emb3531_headless-sdk/actions/workflows/build.yml)

华北工控 EMB-3531(RK3399)嵌入式主板的 **Headless 服务器** 板级支持包.仅包含补丁和构建脚本,不含上游源码.构建时自动从官方仓库获取源码,应用补丁,交叉编译并打包为可烧录的磁盘镜像.

本 SDK 定位为无头(headless)服务器用途--禁用了 GPU,VPU,显示,音频等多媒体子系统,专注于网络,存储,虚拟化(KVM)和容器(Podman)能力.PCIe x4 因实测不稳定已禁用.

## 硬件规格

| 项目 | 规格 |
|------|------|
| SoC | Rockchip RK3399 (2x Cortex-A72 @ 2GHz + 4x Cortex-A53 @ 1.5GHz) |
| GPU | Mali-T864(已禁用) |
| RAM | DDR3,最高 4GB |
| 以太网 | 10/100/1000M (RTL8211F, RGMII) |
| 存储 | eMMC(最高 64GB)+ MicroSD |
| USB | 4x USB 3.0 + 3x USB 2.0 + 1x USB OTG |
| 串口 | 6x COM (RS232/485/TTL) + 1x DB9 调试口 (ttyS2, 115200) |
| PCIe | 1x PCIe x4(已禁用,实测不稳定) |
| 扩展 | 3x Camera, 30-pin GPIO (SPI/I2S/MIPI/I2C) |
| 看门狗 | 支持 |
| RTC | 支持 |
| 供电 | DC 12V |
| 工作温度 | -20 ~ 65°C |
| PCB | 146 x 102 mm |

## 软件组成

| 组件 | 版本 | 来源 |
|------|------|------|
| TF-A (BL31) | de38734 (main) | [github.com/TrustedFirmware-A](https://github.com/TrustedFirmware-A/trusted-firmware-a) |
| U-Boot | 9f61fd5b (master) | [source.denx.de/u-boot](https://source.denx.de/u-boot/u-boot.git) |
| Linux 内核 | 6.18.24 (vanilla) | [cdn.kernel.org](https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.24.tar.xz) |
| Rootfs | Debian trixie (arm64) | debootstrap |

## 相对于 vanilla Debian rootfs 的改动

以下为 SDK 构建时对标准 Debian trixie minimal rootfs 所做的全部定制,分为**移除**和**新增**两类:

### 移除

- **ifupdown**:彻底 `apt-get purge`,避免与 systemd-networkd 冲突
- `/etc/network/interfaces` 中的 eth0 配置:随 ifupdown 移除,不再需要
- apt 缓存,dpkg 缓存,日志,临时文件:构建时清理以缩小 rootfs.img

### 新增/替换

| 文件 | 说明 |
|------|------|
| `/etc/fstab` | LABEL 挂载 rootfs + boot(boot 设为 noauto/nofail) |
| `/etc/hostname` | `debian` |
| `/etc/resolv.conf` | `nameserver 8.8.8.8` |
| `/etc/apt/sources.list` | 清华镜像 (trixie + trixie-updates) |
| `/etc/locale.gen` | `zh_CN.UTF-8 UTF-8` |
| `/etc/default/locale` | `LANG=zh_CN.UTF-8, LC_ALL=zh_CN.UTF-8` |
| `/etc/ssh/sshd_config` | PermitRootLogin yes, 空密码登录, X11Forwarding yes |
| `/etc/chrony/chrony.conf` | NTP 池 + rtcsync + rtcautotrim |
| `/etc/nftables.conf` | 空规则集(预装防火墙框架) |
| `/etc/systemd/network/10-ethernet-dhcp.network` | eth0 DHCP + IPv6 RA + DNS 8.8.8.8/1.1.1.1 |
| `/etc/systemd/emb3531-firstboot.service` | 首次启动服务单元 |
| `/usr/local/sbin/emb3531-firstboot.sh` | 首次启动脚本(NTP 同步,RTC 写入,rootfs 扩容,自删除) |
| `/etc/systemd/system/default.target` | → multi-user.target(无图形界面) |
| `/etc/systemd/system/multi-user.target.wants/emb3531-firstboot.service` | 首次启动服务启用 |
| `/etc/systemd/system/multi-user.target.wants/systemd-networkd.service` | 网络管理器启用 |
| root 密码 | 空(passwd -d root,允许无密码 SSH 登录) |
| 时区 | Asia/Shanghai (UTC+8) |
| 额外安装的 52 个软件包 | 见 `rootfs/pkglist.txt`(含 chrony, openssh-server, sudo, vim-tiny, nftables, gdisk 等) |

### 启用的 systemd 服务

| 服务 | 说明 |
|------|------|
| `systemd-networkd` | 网络管理(DHCP) |
| `ssh` | OpenSSH 服务端 |
| `chrony` | NTP 时间同步 |
| `cron` | 定时任务 |
| `emb3531-firstboot` | 首次启动一次性服务(运行后自删除) |

## SDK 目录结构

```
sdk.sh                              # 统一构建脚本
patches/
  tf-a/
    0001-rk3399-emb3531-pmusram-baudrate.patch    # PMUSRAM 16K + 波特率 115200
  u-boot/
    0001-spl-fit-bounce-buffer-for-atf.patch      # ATF 载入 bounce buffer 修复
    0002-emb3531-board-configs.patch               # 串口控制台 + 引导环境变量
    emb3531-rk3399_defconfig                       # U-Boot defconfig
    rk3399-emb3531-u-boot.dtsi                     # U-Boot DTS 覆盖
    rk3399-emb3531.dts                             # U-Boot 上游设备树
  kernel/
    0001-add-emb3531-dtb-to-makefile.patch         # DTB 编译规则
    rk3399-emb3531.dts                             # 内核设备树
    emb3531_headless_defconfig                     # 内核 defconfig
rootfs/
  pkglist.txt                                       # Debian 软件包列表
  etc/                                              # 目标板配置文件(见上方改动表)
  usr/local/sbin/emb3531-firstboot.sh               # 首次启动脚本
boot/
  extlinux.conf                                     # 内核启动参数
```

## 构建要求

- Debian/Ubuntu x86_64 主机
- `aarch64-linux-gnu-` 交叉编译工具链
- `qemu-user-static`(rootfs debootstrap 需要)
- `debootstrap`, `parted`, `dosfstools`, `pv`
- 约 30GB 磁盘空间(源码 + 编译 + 镜像)

## 快速开始

```bash
tar xzf emb3531-sdk.tar.gz
./sdk.sh all          # 完整一键构建
```

## 分步构建

```bash
./sdk.sh fetch        # 克隆 TF-A/U-Boot,下载并解压内核
./sdk.sh patch        # 应用所有补丁和新文件
./sdk.sh build        # 编译 TF-A + U-Boot + 内核
./sdk.sh boot         # 打包 boot.img
./sdk.sh rootfs       # debootstrap 构建 rootfs
./sdk.sh image        # 打包最终磁盘镜像
./sdk.sh status       # 查看当前构建状态
```

## 镜像分区布局

| 分区 | 起始扇区 | 内容 |
|------|----------|------|
| idbloader | 64 | TPL/SPL (DDR 初始化 + miniloader) |
| uboot | 16384 | U-Boot FIT (含 ATF BL31) |
| boot | 动态 | 内核 Image + DTB + extlinux.conf |
| rootfs | 动态 | Debian trixie rootfs(首次启动自动扩容) |

## 首次启动行为

镜像烧录后首次上电时,`emb3531-firstboot.service` 自动执行:

1. NTP 时间同步(chrony)
2. RTC 时钟写入
3. rootfs 分区在线扩容至 eMMC 全容量
4. 自禁用并删除(仅运行一次)

## TTL 调试

```
波特率:115200
数据位:8
停止位:1
校验:无
流控:无
节点:/dev/ttyS2(COM2 调试口)
```

## Maskrom 刷机

短接板载 maskrom 焊盘后上电,使用 `rkdeveloptool` 或 `upgrade_tool` 烧录:

```bash
rkdeveloptool db rk3399_loader.bin
rkdeveloptool wl 0 emb3531.img
rkdeveloptool rd
```

## 已验证功能

| 功能 | 状态 | 备注 |
|------|------|------|
| eMMC 启动 | OK | HS400 |
| Ethernet (GMAC) | OK | RGMII, DHCP |
| KVM 虚拟化 | OK | `qemu-system-aarch64 --cpu host -enable-kvm` |
| Podman 容器 | OK | pull + run arm64 镜像 |
| USB (8 控制器) | OK | |
| RTC | OK | hwclock 正确 |
| Watchdog | OK | /dev/watchdog |
| CPU DVFS | OK | schedutil, 816-1200 MHz |
| 温度监控 | OK | CPU/GPU thermal zone |
| eMMC I/O | OK | ~450 MB/s seq write |
| PCIe x4 | 禁用 | 实测不稳定,DTS 中已 status = "disabled" |
| GPU/VPU/显示/音频 | 禁用 | Headless 用途,DTS + defconfig 中已关闭 |

## 相关资源

- [华北工控官网](http://www.norco.com.cn/product_detail_359.html)
- [官方 WIKI](http://norcord.com:8070/d/34131f775091442d9fdc/)
- [垃圾佬论坛固件下载](https://files.kos.org.cn/rockchip/EMB3531/)
- [ophub for EMB3531](https://github.com/ophub/amlogic-s9xxx-armbian/issues/1549)
- [B站拆机视频](https://www.bilibili.com/video/BV1Ve2fYmEqd)
- [社区 DTS 补丁](https://github.com/bk3a12/emb3531/tree/main)
- [恩山论坛讨论](https://www.right.com.cn/forum/thread-8251255-1-1.html)

## 补丁说明

### TF-A

- **PMUSRAM_RSIZE**: 8K → 16K,确保 ATF PMU SRAM 有足够空间
- **BAUDRATE**: 1500000 → 115200,匹配板载调试串口

### U-Boot

- **SPL FIT bounce buffer**: ATF 载入时通过 DDR bounce buffer 中转,解决部分存储控制器无法直接 DMA 到 PMU/SRAM 地址的问题,并在读取后 invalidate dcache
- **Board configs**: 串口 only 控制台(无 vidconsole),自定义 bootcmd/bootenv,extlinux 引导

### 内核设备树 (rk3399-emb3531.dts)

- PMIC (RK808) 全部 regulator 定义
- eMMC HS400 + SD 卡
- GMAC RGMII (RTL8211F)
- USB Type-C + OHCI/EHCI + DWC3 (host mode)
- UART2 调试串口
- PWM 风扇 + 热管理(CPU/GPU trip points)
- LED (heartbeat), GPIO 按键
- **禁用**: GPU, VPU, VDEC, RGA, DFI/DMC devfreq, PCIe

### 内核 defconfig (emb3531_headless_defconfig)

- 基于 arm64 defconfig,精简为 headless 服务器场景
- 启用: KVM, virtio, wireguard, ext4, eMMC/SD, GMAC (stmmac), USB, thermal, watchdog, nftables
- 禁用: DRM/GPU, V4L2/媒体, 音频 (ALSA/SOC), 蓝牙, WiFi, 触摸屏, 传感器
