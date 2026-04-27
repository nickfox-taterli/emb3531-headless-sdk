# docs/agent/driver-development/irq-dma-iomem.md

**Scope**: IRQ, DMA, and MMIO patterns for driver development in this kernel tree.
**Local grounding**: IRQ+MMIO examples from `drivers/thermal/rockchip_thermal.c`. DMA patterns — search `drivers/usb/dwc3/` and `drivers/net/ethernet/stmicro/stmmac/` for local consumers.
**Pitfalls**: Use `devm_*` variants. DMA section is TBD for RK3399-specific examples — verify locally before using.

## IRQ

### APIs

| API | Header | Notes |
|-----|--------|-------|
| `platform_get_irq()` | `include/linux/platform_device.h` | Get IRQ from DT (index-based) |
| `platform_get_irq_byname()` | `include/linux/platform_device.h` | Get IRQ by DT name |
| `devm_request_irq()` | `include/linux/interrupt.h` | Managed IRQ registration |
| `devm_request_threaded_irq()` | `include/linux/interrupt.h` | Managed threaded IRQ |
| `disable_irq()` / `enable_irq()` | `include/linux/interrupt.h` | Runtime IRQ control |
| `IRQF_SHARED`, `IRQF_TRIGGER_*` | `include/linux/interrupt.h` | Flags |

### Patterns

```c
/* Get IRQ */
int irq = platform_get_irq(pdev, 0);
if (irq < 0)
    return dev_err_probe(dev, irq, "failed to get IRQ\n");

/* Register ISR */
ret = devm_request_irq(dev, irq, my_isr, 0, "my-driver", priv);
if (ret)
    return ret;

/* Threaded IRQ (for handlers that may sleep) */
ret = devm_request_threaded_irq(dev, irq, NULL, my_thread_fn,
                                IRQF_ONESHOT, "my-driver", priv);
```

### Local Example

`drivers/thermal/rockchip_thermal.c`:
- `platform_get_irq(pdev, 0)` for thermal interrupt.
- `devm_request_irq()` for ISR registration.

### DTS Convention

```dts
interrupt-parent = <&gpio1>;
interrupts = <RK_PC5 IRQ_TYPE_LEVEL_LOW>;
```

IRQ type defines: `include/dt-bindings/interrupt-controller/irq.h`.

## MMIO (Memory-Mapped I/O)

### APIs

| API | Header | Notes |
|-----|--------|-------|
| `devm_platform_ioremap_resource()` | `include/linux/platform_device.h` | Single MMIO region |
| `devm_ioremap_resource()` | `include/linux/io.h` | From `struct resource *` |
| `readl()` / `writel()` | `include/linux/io.h` | 32-bit MMIO access |
| `readl_relaxed()` / `writel_relaxed()` | `include/linux/io.h` | No memory barrier |
| `readb()` / `writeb()` | `include/linux/io.h` | 8-bit access |
| `readw()` / `writew()` | `include/linux/io.h` | 16-bit access |
| `readq()` / `writeq()` | `include/linux/io.h` | 64-bit access |

### Pattern

```c
void __iomem *base;

/* Single resource */
base = devm_platform_ioremap_resource(pdev, 0);
if (IS_ERR(base))
    return PTR_ERR(base);

/* Register access */
writel(value, base + REG_OFFSET);
val = readl(base + REG_OFFSET);
```

### Local Example

`drivers/thermal/rockchip_thermal.c`:
- Uses `devm_platform_ioremap_resource()` for TSADC MMIO.
- Uses `writel_relaxed()` and `readl_relaxed()` for register access.

### Memory Barriers

- `readl()` / `writel()` include memory barriers. Use these by default.
- `readl_relaxed()` / `writel_relaxed()` skip barriers. Use only when you explicitly manage ordering (e.g., inside a spinlock or with explicit `wmb()`/`rmb()`).

## DMA

### APIs

| API | Header | Notes |
|-----|--------|-------|
| `dma_alloc_coherent()` | `include/linux/dma-mapping.h` | Coherent (consistent) DMA buffer |
| `dma_free_coherent()` | `include/linux/dma-mapping.h` | Free coherent buffer |
| `dmam_alloc_coherent()` | `include/linux/dma-mapping.h` | Managed coherent alloc |
| `dma_map_single()` | `include/linux/dma-mapping.h` | Map buffer for DMA |
| `dma_unmap_single()` | `include/linux/dma-mapping.h` | Unmap buffer |
| `dma_map_page()` | `include/linux/dma-mapping.h` | Map page for DMA |

### Coherent DMA Pattern

```c
dma_addr_t dma_handle;
void *virt_addr;

virt_addr = dmam_alloc_coherent(dev, size, &dma_handle, GFP_KERNEL);
if (!virt_addr)
    return -ENOMEM;

/* dma_handle → pass to hardware */
/* virt_addr → CPU access */
```

### Streaming DMA Pattern

```c
dma_addr_t dma_handle = dma_map_single(dev, buf, len, DMA_TO_DEVICE);
if (dma_mapping_error(dev, dma_handle))
    return -ENOMEM;

/* Submit to hardware */

dma_unmap_single(dev, dma_handle, len, DMA_TO_DEVICE);
```

### Local Relevance

DMA is used in this tree by drivers like DWC3 (USB), stmmac (Ethernet), and MMC controllers. Search:
```bash
rg 'dma_alloc_coherent\|dmam_alloc' workspace/linux-6.18.24/drivers/usb/dwc3/ --include='*.c' -l
```

TBD: This board may need DMA-related patches for custom drivers. Verify DMA mask setup in your probe function:
```c
ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(64));
```
