#!/bin/sh
# Build verified vendor inputs and publish complete experimental artifacts.
set -eu
OUTPUT=${1:-/out}
mkdir -p /build/downloads /build/kernel /build/toolchain /build/early-module "$OUTPUT"
python3 - <<'PY'
import hashlib, json, os, pathlib, urllib.request
inputs = json.load(open('/module/inputs.json'))
for name, extension in [('kernel', 'tar.gz'), ('toolchain', 'tar.xz')]:
    supplied = os.environ.get('ARGON_' + name.upper() + '_ARCHIVE')
    destination = pathlib.Path('/build/downloads/' + name + '.' + extension)
    if supplied:
        destination.write_bytes(pathlib.Path(supplied).read_bytes())
    else:
        urllib.request.urlretrieve(inputs[name + '_url'], destination)
    if hashlib.sha256(destination.read_bytes()).hexdigest() != inputs[name + '_sha256']:
        raise SystemExit(name + ' archive checksum mismatch')
PY
tar -xf /build/downloads/kernel.tar.gz -C /build/kernel --strip-components=1
tar -xf /build/downloads/toolchain.tar.xz -C /build/toolchain --strip-components=1
CROSS_COMPILE=/build/toolchain/bin/arm-linux-gnueabihf-
export CROSS_COMPILE ARCH=arm
cp /module/argon_early.c /module/Makefile /build/early-module/
cd /build/kernel
make HOSTCFLAGS="-O2 -fcommon" infinity2m_ssc011a_s01a_defconfig
scripts/config --enable BLK_DEV --module BLK_DEV_LOOP --set-val BLK_DEV_LOOP_MIN_COUNT 8 --enable PM --disable KALLSYMS
make HOSTCFLAGS="-O2 -fcommon" olddefconfig
make HOSTCFLAGS="-O2 -fcommon" modules_prepare
make HOSTCFLAGS="-O2 -fcommon" -j2 M=drivers/block loop.ko
make HOSTCFLAGS="-O2 -fcommon" -j2 M=/build/early-module modules
STAGED=$(mktemp -d /build/output.XXXXXX)
cp /build/early-module/argon_early.ko "$STAGED/argon-early.ko"
cp drivers/block/loop.ko "$STAGED/rebuilt-loop.ko"
cp .config "$STAGED/kernel.config"
python3 - "$STAGED" <<'PY'
import hashlib, json, pathlib, subprocess, sys
out = pathlib.Path(sys.argv[1])
inputs = json.load(open('/module/inputs.json'))
binary = out / 'argon-early.ko'
data = binary.read_bytes()
if data[:6] != b'\x7fELF\x01\x01' or int.from_bytes(data[18:20], 'little') != 40:
    raise SystemExit('module is not ARM little-endian ELF32')
strings = subprocess.check_output(['strings', str(binary)], text=True).splitlines()
vermagic = next(line[len('vermagic='):] for line in strings if line.startswith('vermagic='))
if vermagic != inputs['vermagic']:
    raise SystemExit('module vermagic mismatch: ' + repr(vermagic))
imports = subprocess.check_output(['/build/toolchain/bin/arm-linux-gnueabihf-nm', '-u', str(binary)], text=True)
required = ['call_usermodehelper', '__module_get', 'module_put']
for symbol in required:
    if symbol not in imports.split():
        raise SystemExit('required module API missing: ' + symbol)
loop_hash = hashlib.sha256((out / 'rebuilt-loop.ko').read_bytes()).hexdigest()
manifest = dict(inputs, module_sha256=hashlib.sha256(data).hexdigest(),
                configuration_sha256=hashlib.sha256((out / 'kernel.config').read_bytes()).hexdigest(),
                rebuilt_loop_sha256=loop_hash, loop_bytes_match=loop_hash == inputs['tested_loop_sha256'],
                compiler=subprocess.check_output(['/build/toolchain/bin/arm-linux-gnueabihf-gcc', '--version'], text=True).splitlines()[0],
                imported_symbols=imports.splitlines())
(out / 'build-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('module checksum:', manifest['module_sha256'])
print('loop bytes match:', manifest['loop_bytes_match'])
PY
for item in argon-early.ko rebuilt-loop.ko kernel.config build-manifest.json; do
    mv "$STAGED/$item" "$OUTPUT/$item"
done
rmdir "$STAGED"
