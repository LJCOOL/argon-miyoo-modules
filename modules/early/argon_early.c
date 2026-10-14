#include <linux/init.h>
#include <linux/kmod.h>
#include <linux/module.h>

static char *helper_argv[] = {
    "/bin/sh", "/mnt/SDCARD/boot/argon-early-start", NULL
};
static char *helper_env[] = {
    "HOME=/", "PATH=/usr/bin:/bin:/usr/sbin:/sbin",
    "LD_LIBRARY_PATH=/lib:/config/lib:/customer/lib", NULL
};

static int __init argon_early_init(void)
{
    int result;

    /* Retain module-owned helper arguments until reboot. */
    __module_get(THIS_MODULE);
    result = call_usermodehelper(helper_argv[0], helper_argv, helper_env,
                                UMH_NO_WAIT);
    if (result) {
        module_put(THIS_MODULE);
        pr_err("argon-early: helper dispatch failed: %d\n", result);
        return result;
    }
    pr_info("argon-early: asynchronous helper queued\n");
    return 0;
}

module_init(argon_early_init);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Asynchronous Argon early boot handoff");
MODULE_AUTHOR("Argon");
