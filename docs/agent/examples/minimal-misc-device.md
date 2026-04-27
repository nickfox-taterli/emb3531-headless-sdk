# docs/agent/examples/minimal-misc-device.md

Minimal miscdevice/char-device skeleton for Linux 6.18.24 on RK3399.

## Kconfig Snippet

```kconfig
config MISC_EMB3531_DEMO
    tristate "EMB3531 demo misc device"
    depends on ARCH_ROCKCHIP
    help
      Demo misc character device for EMB3531 board.
```

## Makefile Snippet

```makefile
obj-$(CONFIG_MISC_EMB3531_DEMO) += emb3531_misc.o
```

## C Skeleton

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/mutex.h>

#define DEVICE_NAME "emb3531-demo"

struct emb3531_misc_priv {
    struct mutex lock;
    /* Add per-device state here */
};

static struct emb3531_misc_priv g_priv;

static int emb3531_misc_open(struct inode *inode, struct file *file)
{
    file->private_data = &g_priv;
    return 0;
}

static int emb3531_misc_release(struct inode *inode, struct file *file)
{
    return 0;
}

static ssize_t emb3531_misc_read(struct file *file, char __user *buf,
                                 size_t count, loff_t *ppos)
{
    struct emb3531_misc_priv *priv = file->private_data;
    char msg[] = "emb3531 demo\n";
    size_t len = sizeof(msg);

    mutex_lock(&priv->lock);
    if (*ppos >= len) {
        mutex_unlock(&priv->lock);
        return 0;
    }
    if (copy_to_user(buf, msg, len)) {
        mutex_unlock(&priv->lock);
        return -EFAULT;
    }
    *ppos = len;
    mutex_unlock(&priv->lock);
    return len;
}

static ssize_t emb3531_misc_write(struct file *file, const char __user *buf,
                                  size_t count, loff_t *ppos)
{
    /* PLACEHOLDER: implement write handling */
    return count;
}

static long emb3531_misc_ioctl(struct file *file, unsigned int cmd,
                               unsigned long arg)
{
    /* PLACEHOLDER: implement ioctl commands */
    return -ENOTTY;
}

static const struct file_operations emb3531_misc_fops = {
    .owner          = THIS_MODULE,
    .open           = emb3531_misc_open,
    .release        = emb3531_misc_release,
    .read           = emb3531_misc_read,
    .write          = emb3531_misc_write,
    .unlocked_ioctl = emb3531_misc_ioctl,
};

static struct miscdevice emb3531_misc_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name  = DEVICE_NAME,
    .fops  = &emb3531_misc_fops,
};

static int __init emb3531_misc_init(void)
{
    mutex_init(&g_priv.lock);
    return misc_register(&emb3531_misc_device);
}
module_init(emb3531_misc_init);

static void __exit emb3531_misc_exit(void)
{
    misc_deregister(&emb3531_misc_device);
}
module_exit(emb3531_misc_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("EMB3531 demo misc device");
MODULE_AUTHOR("Author <email>");
```

## Userspace Test Idea

```bash
# Load module
insmod emb3531_misc.ko

# Check device node
ls -la /dev/emb3531-demo

# Read
cat /dev/emb3531-demo

# Write
echo "test" > /dev/emb3531-demo

# IOCTL test (C program)
# PLACEHOLDER: write a small C tool that calls ioctl()
```

## Locking/Lifetime Notes

- `misc_register()` auto-creates `/dev/<name>` via devtmpfs.
- Global state (like `g_priv`) must be protected if the device supports concurrent opens.
- Use `file->private_data` for per-fd state.
- `copy_to_user()` / `copy_from_user()` may sleep — never call inside spinlock.
- `misc_deregister()` waits for all releases to complete before returning.
- For per-device state allocation, use `kmalloc` in `open()` and `kfree` in `release()`.
