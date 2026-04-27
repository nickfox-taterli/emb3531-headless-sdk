# docs/agent/examples/minimal-usb-driver.md

Minimal USB client driver skeleton for Linux 6.18.24.

## Kconfig Snippet

```kconfig
config USB_EMB3531_DEMO
    tristate "EMB3531 demo USB driver"
    depends on USB
    help
      Demo USB client driver.
```

## Makefile Snippet

```makefile
obj-$(CONFIG_USB_EMB3531_DEMO) += emb3531_usb.o
```

## C Skeleton

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/usb.h>

#define VENDOR_ID  0xXXXX  /* PLACEHOLDER */
#define PRODUCT_ID 0xXXXX  /* PLACEHOLDER */

static struct usb_device_id emb3531_usb_table[] = {
    { USB_DEVICE(VENDOR_ID, PRODUCT_ID) },
    { } /* terminating entry */
};
MODULE_DEVICE_TABLE(usb, emb3531_usb_table);

static int emb3531_usb_probe(struct usb_interface *intf,
                             const struct usb_device_id *id)
{
    struct usb_device *udev = interface_to_usbdev(intf);
    struct usb_host_interface *alt = intf->cur_altsetting;
    int i;

    dev_info(&intf->dev, "probe: %04x:%04x\n",
             id->idVendor, id->idProduct);

    /* Discover endpoints */
    for (i = 0; i < alt->desc.bNumEndpoints; i++) {
        struct usb_endpoint_descriptor *ep = &alt->endpoint[i].desc;
        if (usb_endpoint_is_bulk_in(ep))
            dev_dbg(&intf->dev, "bulk IN endpoint %d\n", i);
        else if (usb_endpoint_is_bulk_out(ep))
            dev_dbg(&intf->dev, "bulk OUT endpoint %d\n", i);
        else if (usb_endpoint_is_int_in(ep))
            dev_dbg(&intf->dev, "interrupt IN endpoint %d\n", i);
    }

    /* TODO: Allocate URBs, buffer, set up data path */

    return 0;
}

static void emb3531_usb_disconnect(struct usb_interface *intf)
{
    dev_info(&intf->dev, "disconnect\n");
    /* TODO: Cancel URBs, free resources */
}

static struct usb_driver emb3531_usb_driver = {
    .name       = "emb3531-usb",
    .id_table   = emb3531_usb_table,
    .probe      = emb3531_usb_probe,
    .disconnect = emb3531_usb_disconnect,
};

module_usb_driver(emb3531_usb_driver);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("EMB3531 demo USB driver");
MODULE_AUTHOR("Author <email>");
```

## Endpoint Discovery Outline

```c
struct usb_host_interface *alt = intf->cur_altsetting;
struct usb_endpoint_descriptor *ep;
int i;

for (i = 0; i < alt->desc.bNumEndpoints; i++) {
    ep = &alt->endpoint[i].desc;
    unsigned int ep_num = usb_endpoint_num(ep);
    unsigned int maxp = usb_endpoint_maxp(ep);

    if (usb_endpoint_is_bulk_in(ep)) {
        /* Bulk IN: device → host */
    } else if (usb_endpoint_is_bulk_out(ep)) {
        /* Bulk OUT: host → device */
    } else if (usb_endpoint_is_int_in(ep)) {
        /* Interrupt IN: periodic device → host */
    }
}
```

## Basic Control Transfer

```c
int ret = usb_control_msg(udev,
                          usb_rcvctrlpipe(udev, 0),  /* IN */
                          0x01,       /* bRequest */
                          0x40,       /* bmRequestType: vendor, IN */
                          0x0000,     /* wValue */
                          0x0000,     /* wIndex */
                          buf,        /* data buffer */
                          buf_len,    /* wLength */
                          5000);      /* timeout ms */
```

## Basic Bulk Transfer (Synchronous)

```c
int ret = usb_bulk_msg(udev,
                       usb_sndbulkpipe(udev, ep_out),
                       buf, len, &actual_len, 5000);
```

## URB-Based Transfer (Asynchronous)

```c
struct urb *urb;
void *buf;

buf = usb_alloc_coherent(udev, size, GFP_KERNEL, &dma_handle);
urb = usb_alloc_urb(0, GFP_KERNEL);

usb_fill_bulk_urb(urb, udev, usb_rcvbulkpipe(udev, ep_in),
                  buf, size, my_completion_cb, priv);

urb->transfer_dma = dma_handle;
urb->transfer_flags |= URB_NO_TRANSFER_DMA_MAP;

usb_submit_urb(urb, GFP_KERNEL);
```

## Verification Checklist

- [ ] `VENDOR_ID` / `PRODUCT_ID` are correct for the target device.
- [ ] `MODULE_DEVICE_TABLE(usb, ...)` is present.
- [ ] Endpoint discovery finds expected endpoints.
- [ ] URBs are cancelled in `disconnect()` before freeing.
- [ ] `usb_free_urb()` called for all allocated URBs.
- [ ] `usb_free_coherent()` called for all DMA buffers.
- [ ] Driver builds: `./sdk.sh kernel`
- [ ] Test: plug device → check `dmesg` for probe message.
- [ ] Test: unplug device → check `dmesg` for disconnect message.
