#!/bin/sh

####################################################
# pi-topOS bootloader reflashing script
####################################################

# pi-topOS bootloader common constants and functions

export SD_CARD_DEVICE_P1="/dev/mmcblk0p1"
export SD_CARD_DEVICE_P5="/dev/mmcblk0p5"
export SD_CARD_DEVICE_P6="/dev/mmcblk0p6"

export SD_CARD_MOUNT_POINT_P1="/tmp/mmcblk0p1"
export SD_CARD_MOUNT_POINT_P5="/tmp/mmcblk0p5"
export SD_CARD_MOUNT_POINT_P6="/tmp/mmcblk0p6"

export PT_BOOT_PARTITION_ID="5"

export IMAGE_METADATA_FILENAME="metadata.txt"
export OS_UPGRADE_INFO_FILENAME="pt-os-upgrader.info"

# Global variables to be detected

ZIP_FILE_PATH=""

# Minimum version that current OS to install requires
LOADER_MINIMUM_VERSION=""

# The partition boundary data used for flashing, in 512kb sectors
BOOT_PARTITION_START_SECTOR=""
BOOT_PARTITION_SIZE_SECTORS=""
ROOTFS_PARTITION_START_SECTOR=""
ROOTFS_PARTITION_SIZE_SECTORS=""


print_title()
{
    echo -e "\033[1;33m[ ${1} ]\033[0m"
}

print_error()
{
    echo -e "\033[0;31m${1}\033[0m"
}

reboot_system()
{
    echo "Rebooting..."

    /sbin/reboot -f
}

delete_dir()
{
    # Remove directory

    rm -rf "${1}"
}

create_empty_dir()
{
    # Create a directory - ensure it is available and empty by removing it first

    delete_dir "${1}"
    mkdir -p "${1}"
}

mount_device()
{
    # Mount a device to a new directory and log

    echo "Mounting ${1} to ${2}..."

    create_empty_dir "${2}"
    mount "${1}" "${2}" 2>/dev/null

    local mount_point=$(findmnt -nr -o target -S "${1}")

    if [ -z "${mount_point}" ]; then

        print_error "Failed to mount device"
        delete_dir "${2}"
    else

        echo "Device mounted"
    fi
}

unmount_device()
{
    local mount_point=$(findmnt -nr -o target -S "${1}")

    if [ -d "${mount_point}" ]; then

        umount -f "${1}"
        delete_dir "${mount_point}"

        echo "Device unmounted"
    else

        print_error "Warning: Device was not mounted"
    fi
}

restore_autoboot_file()
{
    # Write the autoboot file to the first partition of the SD card. If that
    # partition is not currently mounted, then mount it first. This file tells
    # the bootloader which partition to automatically boot into, so we set
    # this to 6 which is the boot partition of pi-topOS

    echo "Restoring autoboot"

    local mount_point=$(findmnt -nr -o target -S "${SD_CARD_DEVICE_P1}")

    if [ -z "${mount_point}" ]; then

        mount_device "${SD_CARD_DEVICE_P1}" "${SD_CARD_MOUNT_POINT_P1}"
    fi

    echo "boot_partition=${PT_BOOT_PARTITION_ID}" > ${SD_CARD_MOUNT_POINT_P1}/autoboot.txt
}

error_return_to_os()
{
    # Something went wrong - reboot back into pi-topOS

    echo "An error occurred. Press any key to attempt to reboot into pi-topOS, or r to retry"

    read -r -n1 key_press

    if [ "${key_press}" != "r" ]; then

        restore_autoboot_file

    fi

    reboot_system
}

find_image()
{
    # Mount external drives (/dev/sd*) until we find a zip file containing an image. If we
    # find that file, capture its path in a variable and leave the drive mounted

    local number_of_storage_devices=$(ls -1 /dev/sd* 2>/dev/null | wc -l)

    if [ "${number_of_storage_devices}" -eq 0 ]; then

        print_error "No external storage devices found"

        error_return_to_os
    fi

    for external_device in $(find /dev/sd*); do

        local device_name=$(basename "${external_device}")
        local external_device_mount_point="/tmp/dev/${device_name}"

        mount_device "${external_device}" "${external_device_mount_point}"

        if [ -d "${external_device_mount_point}" ]; then

            echo "Mounted storage device ${external_device_mount_point}. Checking for zipped image..."

            for temp_zip_file_path in $(find "${external_device_mount_point}"/ -maxdepth 1 -type f -name '*.zip'); do

                if [ -f "${temp_zip_file_path}" ]; then

                    echo "Found zip file on storage device: ${temp_zip_file_path}"

                    echo "Checking for image file in zip..."

                    if [ $(7z l -ba -slt "${temp_zip_file_path}" | grep 'Path =' | grep -c '.img') -ne 1 ]; then

                        echo "No image found in zip file"
                        continue
                    fi

                    echo "Checking for partition data in zip..."

                    if [ $(7z l -ba -slt "${temp_zip_file_path}" | grep 'Path =' | grep -c "${IMAGE_METADATA_FILENAME}") -ne 1 ]; then

                        echo "No partition data found in zip file"
                        continue
                    fi

                    ZIP_FILE_PATH="${temp_zip_file_path}"
                fi

            done

            if [ -z "${ZIP_FILE_PATH}" ]; then

                unmount_device "${external_device}"
            fi
        fi
    done

    if [ ! -f "${ZIP_FILE_PATH}" ]; then

        print_error "No zipped image file was found"

        error_return_to_os
    fi
}

get_metadata()
{
    # Extract the partition data

    7z e -y -o/tmp/ "${ZIP_FILE_PATH}" "${IMAGE_METADATA_FILENAME}" &>/dev/null

    local metadata_file="/tmp/${IMAGE_METADATA_FILENAME}"

    local boot_start_sector=$(cat "${metadata_file}" | grep 'BOOT_START=' | awk -F '=' '{ print $2 }')
    local boot_size_sectors=$(cat "${metadata_file}" | grep 'BOOT_SIZE=' | awk -F '=' '{ print $2 }')
    local rootfs_start_sector=$(cat "${metadata_file}" | grep 'ROOTFS_START=' | awk -F '=' '{ print $2 }')
    local rootfs_size_sectors=$(cat "${metadata_file}" | grep 'ROOTFS_SIZE=' | awk -F '=' '{ print $2 }')

    local new_os_minimum_loader_version=$(cat "${metadata_file}" | grep 'LOADER_MINIMUM_VERSION=' | awk -F '=' '{ print $2 }')

    if [ -z "${boot_start_sector}" ] || \
        [ -z "${boot_size_sectors}" ] || \
        [ -z "${rootfs_start_sector}" ] || \
        [ -z "${rootfs_size_sectors}" ] || \
        [ -z "${new_os_minimum_loader_version}" ]
    then

        print_error "The required metadata could not be extracted from the discoverred OS image. Is this a valid pi-topOS image?"

        error_return_to_os
    fi

    # We have what we need - store in global variables

    BOOT_PARTITION_START_SECTOR="${boot_start_sector}"
    BOOT_PARTITION_SIZE_SECTORS="${boot_size_sectors}"
    ROOTFS_PARTITION_START_SECTOR="${rootfs_start_sector}"
    ROOTFS_PARTITION_SIZE_SECTORS="${rootfs_size_sectors}"
    LOADER_MINIMUM_VERSION="${new_os_minimum_loader_version}"
}

validate_os_compatibility()
{
    if [ "${LOADER_VERSION}" -lt "${LOADER_MINIMUM_VERSION}" ]; then

        print_error "Current OS upgrader is not capable of installing this OS. Please run a software update on the OS, or contact support@pi-top.com"

        error_return_to_os

    fi
}

flash_partitions_from_image()
{
    # Flash sd card from image

    local image_filename=$(7z l -ba -slt "${ZIP_FILE_PATH}" | grep 'Path =' | grep '.img' | awk '{ print $3 }')

    echo "Flashing boot partition..."
    7z e -y -so "${ZIP_FILE_PATH}" "${image_filename}" 2>/dev/null | dd bs=512 skip="${BOOT_PARTITION_START_SECTOR}" count="${BOOT_PARTITION_SIZE_SECTORS}" of="${SD_CARD_DEVICE_P5}"

    if [ "$?" -ne 0 ]; then
        print_error "There was an error flashing the boot partition of your SD card. Your OS partitions may no longer boot. If this is the case, please re-flash your SD card using a desktop computer"
        sh
    fi

    echo "Flashing rootfs partition. This may take up to 30 minutes..."
    7z e -y -so "${ZIP_FILE_PATH}" "${image_filename}" 2>/dev/null | dd bs=512 skip="${ROOTFS_PARTITION_START_SECTOR}" count="${ROOTFS_PARTITION_SIZE_SECTORS}" of="${SD_CARD_DEVICE_P6}"

    if [ "$?" -ne 0 ]; then
        print_error "There was an error flashing the rootfs partition of your SD card. Your OS partitions may no longer boot. If this is the case, please re-flash your SD card using a desktop computer"
        sh
    fi
}

mount_and_check_new_partitions()
{
    mount_device "${SD_CARD_DEVICE_P5}" "${SD_CARD_MOUNT_POINT_P5}"

    if [ ! -d "${SD_CARD_MOUNT_POINT_P5}" ]; then
        print_error "The boot partition of your SD card could not be mounted, which suggests a problem during flashing the image. Your OS partitions may no longer boot. If this is the case, please re-flash your SD card using a desktop computer"
        sh
    fi

    mount_device "${SD_CARD_DEVICE_P6}" "${SD_CARD_MOUNT_POINT_P6}"

    if [ ! -d "${SD_CARD_MOUNT_POINT_P6}" ]; then
        print_error "The rootfs partition of your SD card could not be mounted, which suggests a problem during flashing the image. Your OS partitions may no longer boot. If this is the case, please re-flash your SD card using a desktop computer"
        sh
    fi
}

fix_partuuid_in_cmdline()
{
    # The partition ID written into the pi-topOS cmdline will be wrong, so it needs
    # to be updated the new ID in the mbr.

    echo "Updating cmdline.txt"

    # Back-up
    cp "${SD_CARD_MOUNT_POINT_P5}/cmdline.txt" "${SD_CARD_MOUNT_POINT_P5}/cmdline.txt.old"

    local rootfs_partition_id=$(blkid -o export "${SD_CARD_DEVICE_P6}" | grep PARTUUID | cut -d'=' -f 2)

    echo "New rootfs partition ID: ${rootfs_partition_id}"

    sed -i -E 's/root\=PARTUUID\=[^ ]+/root=PARTUUID='"${rootfs_partition_id}"'/g' "${SD_CARD_MOUNT_POINT_P5}/cmdline.txt"

    echo "New cmdline:"
    cat "${SD_CARD_MOUNT_POINT_P5}/cmdline.txt"
}

update_file_system_table()
{
    # Update the fstab on the newly flashed pi-topOS with the appropriate devices

    echo "Updating fstab"

    # Back-up
    cp "${SD_CARD_MOUNT_POINT_P6}/etc/fstab" "${SD_CARD_MOUNT_POINT_P6}/etc/fstab.old"

    # Replace the drives for root (/) and boot (/boot)

    sed -i 's|^[^#].* /boot |'"${SD_CARD_DEVICE_P5}"'  /boot |' "${SD_CARD_MOUNT_POINT_P6}/etc/fstab"
    sed -i 's|^[^#].* / |'"${SD_CARD_DEVICE_P6}"'  / |' "${SD_CARD_MOUNT_POINT_P6}/etc/fstab"

    # We also add an entries for p1, which is then mounted readonly to /mnt instead of /media.
    # This prevents it being seen as a removable drive (and shown on the desktop)

    sed -i '\|'"${SD_CARD_DEVICE_P1}"'|d' "${SD_CARD_MOUNT_POINT_P6}/etc/fstab"

    mkdir ${SD_CARD_MOUNT_POINT_P6}/mnt/p1 2>/dev/null
    echo "${SD_CARD_DEVICE_P1}  /mnt/p1  vfat  noauto  0  0" >> "${SD_CARD_MOUNT_POINT_P6}/etc/fstab"

    echo "New fstab:"
    cat "${SD_CARD_MOUNT_POINT_P6}/etc/fstab"
}

# Main

print_title "Determine loader version"

# Source information about the current upgrader

if [ -e "${SD_CARD_MOUNT_POINT_P1}/${OS_UPGRADE_INFO_FILENAME}" ]; then

    . "${SD_CARD_MOUNT_POINT_P1}/${OS_UPGRADE_INFO_FILENAME}"

else

    print_error "Unable to find current upgrader information - ${OS_UPGRADE_INFO_FILENAME} is missing. Contact support@pi-top.com"

    error_return_to_os
fi

# Check for loader version
if [ -z "${LOADER_VERSION}" ]; then

    print_error "Unable to determine current upgrader version - LOADER_VERSION is missing. Contact support@pi-top.com"

    error_return_to_os
fi

print_title "Waiting a few seconds to give external devices a chance to initialise..."
sleep 20

print_title "Searching external storage devices for image..."
find_image

print_title "Validating and extracting image metadata..."
get_metadata

print_title "Verifying OS image compatibility..."
validate_os_compatibility

print_title "Flashing OS partitions..."
flash_partitions_from_image

print_title "Mounting SD reflashed partitions..."
mount_and_check_new_partitions

print_title "Reconfiguring partition identifiers..."
fix_partuuid_in_cmdline
update_file_system_table

print_title "Restoring standard boot sequence..."
restore_autoboot_file
