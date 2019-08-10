#!/bin/bash -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

squashfs_dir="$(dirname ${script_dir})/squashfs"
recovery_dir="$(dirname ${script_dir})/recovery"

recovery_rfs="${recovery_dir}/recovery.rfs"

if [[ ! -e "${recovery_rfs}" ]]; then
	echo "No recovery filesystem found."
	exit 1
fi

if [ "$(id -u)" != "0" ]; then
	echo "Sorry, you are not root."
	exit 1
fi

rm -rf /tmp/squashfs/ 2>/dev/null
mkdir -p /tmp/squashfs/ 2>/dev/null

unsquashfs -f -d /tmp/squashfs/ "${recovery_rfs}"

cp "${squashfs_dir}/init" /tmp/squashfs/init
cp "${squashfs_dir}/pt-os-installer" /tmp/squashfs/pt-os-installer

rm "${recovery_rfs}"
mksquashfs /tmp/squashfs/ "${recovery_rfs}"

echo "OK"
