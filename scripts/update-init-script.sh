#!/bin/bash -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

src_dir="$(dirname ${script_dir})/src"

rm -rf /tmp/squashfs/ 2>/dev/null
mkdir -p /tmp/squashfs/ 2>/dev/null

unsquashfs -f -d /tmp/squashfs/ "${1}"

cp "${src_dir}/init" /tmp/squashfs/init
cp "${src_dir}/pt-os-upgrader" /tmp/squashfs/pt-os-upgrader

rm "${1}"
mksquashfs /tmp/squashfs/ "${1}"

echo "OK"
