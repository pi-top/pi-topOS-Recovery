# pi-topOS bootloader/recovery files

Based on [PINN](https://github.com/procount/pinn), which itself is based on [NOOBS](https://github.com/raspberrypi/noobs), this package provides the files for starting up a minified Linux environment and starting a custom init script which is designed to allow users to install pi-topOS from a USB.

Almost all files are taken from [pinn-lite.zip](http://sourceforge.net/projects/pinn/files/pinn-lite.zip).

The functionality is modified to provide an out-of-the-box automatic installer of pi-topOS via USB device.

## USB-based pi-topOS installer

Here is an outline of what happens if there is no `autoboot.txt`.
Inside the squashfs, `init` will set up the environment and wait 5 seconds for the user to press Enter to return to their OS's main partition. If no input is detected, then `pt-os-installer` will start.

`pt-os-installer` will wait a few seconds to give external devices a chance to initialise before trying to search for external storage devices. Any that are found will be probed for all zip files. Zip files are checked to see if a `.img` file is found within it, as well as pi-topOS's metadata file that contains the partition data for the image. This is what allows the installer to be able to reinstall the OS.

Installing pi-topOS can take a little while, but is usually comparable in write speed to using an SD card writer on another computer.

Once it has been installed, partitions are configured - e.g. modifying the filesystem table.

The OS install script will reboot into the newly installed pi-topOS partitions upon completion.


## More Information

For more information, check the [pi-topOS documentation](https://pi-top.github.io/docs/)

<!-- ### Partitions

The files in this package make up the files in the first partition on a modern pi-topOS SD card (Buster onwards).

### How files are managed

Partition 5 is main partition - partition 1 is mounted as /recovery in the filesystem table and `pt-recovery` handles updating the files.

`dpkg-divert` is used as FAT is not handled well.
 -->


## TODO
* First pass: `wget https://downloads.sourceforge.net/project/pinn/pinn-lite.zip` to get latest PINN source?
* Better: Generate [`buildroot`](https://buildroot.org/) embedded Linux dynamically as part of package
    * This potentially will allow us to modify the kernel to include additional functionality
    * This would replace the 'hard-coded' `recovery` directory in source
