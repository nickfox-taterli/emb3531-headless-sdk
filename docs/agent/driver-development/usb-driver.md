# docs/agent/driver-development/usb-driver.md

**Scope**: USB driver development index — host controller bring-up and USB client driver patterns.
**Local grounding**: Board DTS enables DWC3 + EHCI/OHCI in host mode. PHY drivers in `drivers/phy/rockchip/`. Client examples in `drivers/usb/storage/isd200.c`, `drivers/usb/class/usblp.c`.
**Pitfalls**: All controllers are `dr_mode = "host"`. Changing to gadget/peripheral requires DTS edit. URBs must be cancelled in `disconnect()` before freeing.

## Important Distinction

This SDK targets USB **host** mode on all controllers (`dr_mode = "host"`). The board has:

- 2x DWC3 controllers (`usbdrd_dwc3_0`, `usbdrd_dwc3_1`) in host mode
- 2x EHCI + 2x OHCI host controllers
- 2x Type-C PHYs, 2x USB2 PHYs

USB **client/device/gadget** development is possible but not the primary use case. The DTS can be changed to `dr_mode = "otg"` or `dr_mode = "peripheral"` if needed.

## USB Host/Controller/PHY Bring-Up

The board already has USB host working. For bring-up of new hardware:

- PHY drivers: `drivers/phy/rockchip/phy-rockchip-inno-usb2.c`, `drivers/phy/rockchip/phy-rockchip-typec.c`
- DWC3 core: `drivers/usb/dwc3/`
- EHCI/OHCI: `drivers/usb/host/ehci-hcd.c`, `drivers/usb/host/ohci-hcd.c`
- Binding: `Documentation/devicetree/bindings/phy/rockchip,inno-usb2phy.yaml`

## USB Client/Device/Class Driver Development

### Key Structures

| Structure | Header | Notes |
|-----------|--------|-------|
| `struct usb_driver` | `include/linux/usb.h` | Host-side client driver |
| `struct usb_device_id` | `include/linux/usb.h` | Device match table |
| `struct usb_interface` | `include/linux/usb.h` | Represented interface |
| `struct urb` | `include/linux/usb.h` | USB Request Block |
| `struct usb_host_endpoint` | `include/linux/usb.h` | Endpoint wrapper |

### Local Examples

#### USB Storage ISD200 (`drivers/usb/storage/isd200.c`)
- `struct usb_driver isd200_driver`
- `struct usb_device_id isd200_usb_ids`
- probe/disconnect pattern
- Good reference for: USB storage subclass driver.

#### USB Printer (`drivers/usb/class/usblp.c`)
- `struct usb_driver usblp_driver`
- `struct usb_device_id usblp_ids`
- Full char device interface via `register_chrdev()`
- Good reference for: USB class driver with char device interface.

## id_table

```c
static struct usb_device_id my_usb_ids[] = {
    { USB_DEVICE(VENDOR_ID, PRODUCT_ID) },
    { } /* terminating entry */
};
MODULE_DEVICE_TABLE(usb, my_usb_ids);
```

Macro reference: `include/linux/usb.h` — `USB_DEVICE()`, `USB_DEVICE_VER()`, `USB_INTERFACE_INFO()`.

## probe/disconnect

```c
static int my_usb_probe(struct usb_interface *intf,
                        const struct usb_device_id *id)
{
    struct usb_device *udev = interface_to_usbdev(intf);
    /* Discover endpoints, allocate URBs */
    return 0;
}

static void my_usb_disconnect(struct usb_interface *intf)
{
    /* Cancel URBs, free resources */
}
```

## Endpoint Discovery

```c
struct usb_host_interface *alt = intf->cur_altsetting;
int i;
for (i = 0; i < alt->desc.bNumEndpoints; i++) {
    struct usb_endpoint_descriptor *ep = &alt->endpoint[i].desc;
    if (usb_endpoint_is_bulk_in(ep)) { /* ... */ }
    if (usb_endpoint_is_bulk_out(ep)) { /* ... */ }
    if (usb_endpoint_is_int_in(ep)) { /* ... */ }
}
```

Helper macros: `include/linux/usb/ch9.h` — `usb_endpoint_is_bulk_in()`, etc.

## Transfer Types

| Type | API | Notes |
|------|-----|-------|
| Control | `usb_control_msg()` | Synchronous, for setup commands |
| Bulk | `usb_bulk_msg()` or URBs | Large data, reliable |
| Interrupt | URBs | Small, periodic |
| Isochronous | URBs | Streaming, no retry |

## URBs (USB Request Blocks)

```c
struct urb *urb = usb_alloc_urb(0, GFP_KERNEL);
/* Fill urb: usb_fill_bulk_urb(), usb_fill_int_urb(), etc. */
usb_submit_urb(urb, GFP_KERNEL);
/* Callback: urb->complete */
usb_free_urb(urb);  /* After completion */
```

Headers: `include/linux/usb.h`, `include/linux/usb/hcd.h`.

## Kconfig/Makefile Integration

```kconfig
config USB_MY_DRIVER
    tristate "My USB driver"
    depends on USB
    help
      Say Y here to enable my USB driver.
```

```makefile
obj-$(CONFIG_USB_MY_DRIVER)  += my_usb.o
```

## Debug Commands

```bash
# On target:
lsusb                      # List USB devices
lsusb -v -d <vid:pid>      # Verbose device descriptor
cat /sys/kernel/debug/usb/devices
dmesg | grep -i usb
```

## Debug Logging

USB core uses `dev_dbg()` extensively. Enable with:
```bash
echo 'module usbcore +p' > /sys/kernel/debug/dynamic_debug/control
echo 'file drivers/usb/* +p' > /sys/kernel/debug/dynamic_debug/control
```
