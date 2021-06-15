# pi-topOS Recovery

Based on [PINN](https://github.com/procount/pinn), which itself is based on [NOOBS](https://github.com/raspberrypi/noobs), this is both a recovery operating system and integrated recovery application designed to run on startup. The recovery OS is a minified Linux environment (provided by buildroot). The recovery application is a shell script configured to run on recovery OS startup which can install pi-topOS from a USB memory device (actually anything that shows up in Linux via `/dev/sd*`.

At present, all files in `recovery` are taken from [pinn-lite.zip](http://sourceforge.net/projects/pinn/files/pinn-lite.zip). However, `recovery.rfs` is a special file that contains a squashed file system in it (An [initramfs](https://wiki.debian.org/initramfs) image containing various scripts and the PINN GUI application).

This is modified during packaging to instead provide an out-of-the-box automatic installer of pi-topOS via USB device.

## USB-based pi-topOS installer

Inside the `initramfs`, `init` will set up the environment and wait 5 seconds for the user to press Enter to return to their OS's main partition. If no input is detected, then `pt-os-installer` will start.

`pt-os-installer` will wait a few seconds to give external devices a chance to initialise before trying to search for external storage devices. Any that are found will be probed for all zip files. Zip files are checked to see if a `.img` file is found within it, as well as pi-topOS's metadata file that contains the partition data for the image. This is what allows the installer to be able to reinstall the OS.

Installing pi-topOS can take a little while, but is usually comparable in write speed to using an SD card writer on another computer.

Once it has been installed, partitions are configured - e.g. modifying the filesystem table.

The OS install script will reboot into the newly installed pi-topOS partitions upon completion.


## More Information

The recovery OS is triggered when it is unable to detect a partition to boot into, or when the Shift key is held down on boot, as with PINN and NOOBS.

For more information, check the [pi-topOS documentation](https://pi-top.github.io/docs/)

<!-- ### Partitions

The files in this package make up the files in the first partition on a modern pi-topOS SD card (Buster onwards).

### How files are managed

Partition 5 is main partition - partition 1 is mounted as /recovery in the filesystem table and `pt-recovery` handles updating the files.

`dpkg-divert` is used as FAT is not handled well.
 -->


## TODO
* Replace PINN files (`recovery`) with copied `buildroot` config to build directly
