"""Check the module's dispatch and reference-lifetime contract at its kernel boundary."""
import pathlib
import subprocess
import tempfile
import unittest

SOURCE = pathlib.Path(__file__).parent / 'argon_early.c'

class DispatchTests(unittest.TestCase):
    def test_async_dispatch_lifetime_and_queue_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / 'linux').mkdir()
            declarations = r'''
#include <assert.h>
#include <stddef.h>
#include <string.h>
#define __init
#define THIS_MODULE ((void *)1)
#define UMH_NO_WAIT 0
#define MODULE_LICENSE(x)
#define MODULE_DESCRIPTION(x)
#define MODULE_AUTHOR(x)
#define pr_err(...) ((void)0)
#define pr_info(...) ((void)0)
static int references;
static char **saved_argv;
static void __module_get(void *module) { (void)module; references++; }
static void module_put(void *module) { (void)module; references--; }
static int call_usermodehelper(char *path, char **argv, char **env, int wait) {
    assert(references == 1);
    assert(wait == UMH_NO_WAIT);
    assert(strcmp(path, "/bin/sh") == 0);
    assert(strcmp(argv[1], "/mnt/SDCARD/boot/argon-early-start") == 0);
    assert(argv[2] == NULL);
    assert(strcmp(env[0], "HOME=/") == 0);
    saved_argv = argv;
    return DISPATCH_RESULT;
}
#define module_init(fn) int main(void) { \
    int result = fn(); \
    assert(result == DISPATCH_RESULT); \
    assert(references == (DISPATCH_RESULT == 0 ? 1 : 0)); \
    if (!result) assert(strcmp(saved_argv[1], "/mnt/SDCARD/boot/argon-early-start") == 0); \
    return 0; \
}
'''
            (root / 'linux/init.h').write_text(declarations)
            (root / 'linux/kmod.h').touch()
            (root / 'linux/module.h').touch()
            for result in (0, -12):
                subprocess.run(['cc', '-Wall', '-Wextra', '-Werror', '-I', str(root),
                                '-DDISPATCH_RESULT=' + str(result), str(SOURCE),
                                '-o', str(root / 'module-test')], check=True)
                subprocess.run([str(root / 'module-test')], check=True)

if __name__ == '__main__':
    unittest.main()
