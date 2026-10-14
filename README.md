# Argon Miyoo modules

Kernel modules for the Miyoo Mini Flip used by Argon. Each first-party module lives under `modules/<name>/`.

## Modules

- `modules/early/` builds `argon-early.ko`. It asynchronously starts `/bin/sh /mnt/SDCARD/boot/argon-early-start` and retains its helper arguments until reboot.
- The shared build also produces the vendor kernel loop driver as `rebuilt-loop.ko`.

## Build

The root Dockerfile and build script share the pinned kernel and toolchain in `inputs.json`. The container targets Linux AMD64.

```sh
podman build --platform linux/amd64 -t localhost/argon-miyoo-modules .
mkdir -p artifacts
podman run --rm --platform linux/amd64 \
  -v "$(pwd)/artifacts:/out" localhost/argon-miyoo-modules
```

Docker can replace Podman. To reuse downloaded archives, mount them under `/inputs` and set `ARGON_KERNEL_ARCHIVE` and `ARGON_TOOLCHAIN_ARCHIVE`. The build verifies their checksums.

Output contains `argon-early.ko`, `rebuilt-loop.ko`, `kernel.config`, and `build-manifest.json`. The manifest records the compiler, kernel configuration, imported symbols, and digests.

## Test

```sh
python3 modules/early/test.py
```

This host test compiles against kernel API stubs and checks asynchronous dispatch, argument lifetime, and queue failure.

## Use with Argon

Argon retains verified deployment artifacts in `bootstrap/early-module/artifacts`. To use a new build, pass its output directory:

```sh
zig build early-boot-overlay -Dearly-module-dir=/absolute/path/to/argon-miyoo-modules/artifacts
zig build package -Ddeployment-module-dir=/absolute/path/to/argon-miyoo-modules/artifacts
```

Run these commands from the Argon repository. Argon validates the artifacts before packaging. Test boot behavior on the device before updating checked-in artifacts.
