# docs/agent/driver-development/misc-char-device.md

**Scope**: miscdevice/char-device development for this kernel tree.
**Local examples**: `drivers/char/hpet.c`, `drivers/misc/pci_endpoint_test.c`. Note: these are x86/PCI-centric; search for ARM64 miscdevice examples in-tree if needed.
**Pitfalls**: `copy_to_user()`/`copy_from_user()` may sleep — never inside spinlock. `misc_deregister()` blocks until all fds close.

## When to Prefer miscdevice

- Simple character device with a single minor number.
- No complex device number management needed.
- Minor number is either `MISC_DYNAMIC_MINOR` or a static assignment.
- For multi-device or complex char drivers, use `alloc_chrdev_region()` + `cdev_add()` instead.

## APIs

| API | Header | Notes |
|-----|--------|-------|
| `misc_register()` | `include/linux/miscdevice.h` | Register misc device |
| `misc_deregister()` | `include/linux/miscdevice.h` | Unregister misc device |
| `struct miscdevice` | `include/linux/miscdevice.h` | Device descriptor |
| `struct file_operations` | `include/linux/fs.h` | VFS operations |
| `copy_to_user()` | `include/linux/uaccess.h` | Kernel → user |
| `copy_from_user()` | `include/linux/uaccess.h` | User → kernel |
| `.unlocked_ioctl` | `include/linux/fs.h` | ioctl handler |
| `.poll` | `include/linux/poll.h` | poll/wait support |
| `.mmap` | `include/linux/mm.h` | Memory mapping |

## Local Examples

### HPET (`drivers/char/hpet.c`)
- Uses `struct miscdevice` with `HPET_MINOR`.
- Provides `hpet_fops` with open, read, ioctl, poll, mmap.
- Good reference for: full-featured misc device with multiple file_operations.

### PCI Endpoint Test (`drivers/misc/pci_endpoint_test.c`)
- Uses `miscdevice` with `MISC_DYNAMIC_MINOR`.
- Provides ioctl-based testing interface.
- Good reference for: test/dev character device pattern.

## Kconfig/Makefile Integration

### Kconfig snippet:
```kconfig
config MY_MISC_DEV
    tristate "My misc device driver"
    depends on ARCH_ROCKCHIP
    help
      Say Y here to enable my misc device.
```

### Makefile snippet:
```makefile
obj-$(CONFIG_MY_MISC_DEV)   += my_misc.o
```

## `/dev` Node Expectations

- `misc_register()` auto-creates `/dev/<name>` via devtmpfs.
- No `mknod` needed.
- Device node name is set by `struct miscdevice .name` field.
- Default permissions: 0600 (can be changed via `device_create` or udev rules).

## Basic Skeleton

```c
#include <linux/module.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/uaccess.h>

static int my_misc_open(struct inode *inode, struct file *file)
{
    return 0;
}

static int my_misc_release(struct inode *inode, struct file *file)
{
    return 0;
}

static ssize_t my_misc_read(struct file *file, char __user *buf,
                            size_t count, loff_t *ppos)
{
    char data[] = "hello\n";
    size_t len = sizeof(data);
    if (*ppos >= len)
        return 0;
    if (copy_to_user(buf, data, len))
        return -EFAULT;
    *ppos = len;
    return len;
}

static long my_misc_ioctl(struct file *file, unsigned int cmd,
                          unsigned long arg)
{
    return -ENOTTY;
}

static const struct file_operations my_misc_fops = {
    .owner          = THIS_MODULE,
    .open           = my_misc_open,
    .release        = my_misc_release,
    .read           = my_misc_read,
    .unlocked_ioctl = my_misc_ioctl,
};

static struct miscdevice my_misc_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name  = "my-misc",
    .fops  = &my_misc_fops,
};

static int __init my_misc_init(void)
{
    return misc_register(&my_misc_device);
}
module_init(my_misc_init);

static void __exit my_misc_exit(void)
{
    misc_deregister(&my_misc_device);
}
module_exit(my_misc_exit);

MODULE_LICENSE("GPL");
```

## Locking/Lifetime Pitfalls

- `file->private_data` is per-fd. Use it to store per-open state.
- If the device has global state, protect it with a `mutex` or `spinlock`.
- `misc_deregister()` blocks until all open fds are closed (via `file_operations.release`).
- Do not free device-private data in `release` if `misc_deregister` is still running. Use `kref` if needed.
- `copy_to_user()` / `copy_from_user()` may sleep. Do not call them inside spinlocks.
