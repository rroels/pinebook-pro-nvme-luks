# Pinebook Pro: Root Partition on Encrypted NVME LUKS Partition

The goal of this guide is to have the Pinebook Pro boot from an encrypted NVME drive. While it is not rocket science, there is no installer or tool that will set everything up for you. This page will describe the steps needed to do it manually. At the time of writing, the pinebook pro can not boot from NVME directly. As a workaround, we leave the boot partition on the eMMC and move everything else (everything except uboot and the "/boot" dir) to an encrypted NMVE partition. 

A lot of this guide is based on the script found [here](https://gitlab.manjaro.org/manjaro-arm/applications/manjaro-arm-installer/-/issues/22), by Yahe. However, this doesn't work for newer versions of Manjaro (e.g. with plymouth), so this procedure is slightly more up-to-date (but more manual work). 

In summary, this is what we're going to do:
1) install Manjaro onto eMMC
2) create encrypted root and swap partition on NVME
3) move content of the eMMC root partition to the encrypted NVME root partition
4) make changes to mkinitcpio.conf, fstab, crypttab and extlinux.conf, so that the boot partition on the eMMC uses the root partition from the NVME.

This guide focusses on creating a fresh install, and will erase any existing data on your eMMC or NVME!

This method has been tested with Manjaro 21.06, but it should work for other versions and even distributions, with some tweaks. Some example scripts to do these steps can be found in the scripts directory, but please only seem them as examples (they probably need tweaking for your specific system).

## Step 1: Create bootable SD card

Download the [Manjaro image of your choice for the Pinebook Pro](https://manjaro.org/download/#pinebook-pro). Create a bootable SD card using dd or etcher. Boot from the SD card and go through the config menu to complete the installation, and reboot. 

## Step 2: Install Manjaro on eMMC

Once you're able to boot into a working Manjaro environment from the SD card, we will use it to install Manjaro on the eMMC. Use the included manjaro-arm-flasher tool to write the Manjaro image to the eMMC (mmcblk2).

## Step 3: Set up eMMC install

Next take the SD card out and boot from eMMC. Again, go through the config menu and reboot untill you have a working Manjaro environment on the eMMC. 

We will eventually move this install to our encrypted NVME partition, but before we do that we need to make some changes. 

Edit the file `/etc/mkinitcpio.conf`, because we want to recreate the kernel's initial ramdisk with the following additions:
1) inclusion of hooks for plymouth-encrypt and lvm2
2) disable compression (use "cat" compression)
	
Mine looks something like this:

	...
	HOOKS=(base udev keyboard plymouth autodetect keymap modconf block plymouth-encrypt lvm2 filesystems fsck)
	...
	COMPRESSION="cat"
	...

***Warning***: the order of the hooks matters! 

***Warning 2***: a lot of guides/tutorials will tell you to add the hook "encrypt" instead of "plymouth-encrypt". It took me a lot of trial and error to find out you have to use "plymouth-encrypt" if you already use plymouth, which Manjaro does. See [documentation](https://wiki.archlinux.org/title/plymouth#The_plymouth_hook).

Next, rebuild the ramdisk, which will automatically be written to /boot/initramfs-linux.img:

	sudo mkinitcpio -p linux

To make sure the ramdisk is fine, simply reboot the eMMC install. This should work fine, even if we're not using any encryption yet. 

## Step 4: Boot from SD card again

Shut down the eMMC-based OS, and boot from the SD card again. This is so we can copy the root partition of the eMMC without it being used. ALL the next steps are performed from the SD-based OS.

## Step 5: Create encrypted partition on NVME

Run the following commands to erase the NVME and create encrypted root and swap partitions. 

	NVME_NAME="nvme0"
	NVME_DEVICE="${NVME_NAME}n1"
	NVME_PARTITION_DEVICE="${NVME_DEVICE}p1"
	NVME_PARTITION_NAME="${NVME_PARTITION_DEVICE}_luks"
	NVME_PARTITION_START="0%"
	NVME_PARTITION_END="100%"
	NVME_VOLUMEGROUP_NAME="${NVME_PARTITION_NAME}_lvm"

	ROOT_VOLUME_NAME="${NVME_VOLUMEGROUP_NAME}_root"
	ROOT_VOLUME_SIZE="100%FREE"

	SWAP_VOLUME_LABEL="SWAP"
	SWAP_VOLUME_NAME="${NVME_VOLUMEGROUP_NAME}_swap"
	SWAP_VOLUME_SIZE="8GiB"

	## unmount all partitions

	ls -1 /dev/* | grep "/dev/${EMMC_DEVICE}" | xargs umount
	ls -1 /dev/* | grep "/dev/${NVME_DEVICE}" | xargs umount

	## create LUKS partition on NVMe

	parted -s "/dev/${NVME_DEVICE}" mklabel msdos
	parted -s "/dev/${NVME_DEVICE}" mkpart primary ext4 "$NVME_PARTITION_START" "$NVME_PARTITION_END"
	partprobe "/dev/${NVME_DEVICE}"

	cryptsetup --use-urandom luksFormat "/dev/${NVME_PARTITION_DEVICE}"

	## open the LUKS partition on NVMe

	cryptsetup open "/dev/${NVME_PARTITION_DEVICE}" "$NVME_PARTITION_NAME"

	## create LVM volumes

	pvcreate "/dev/mapper/${NVME_PARTITION_NAME}"

	vgcreate "$NVME_VOLUMEGROUP_NAME" "/dev/mapper/${NVME_PARTITION_NAME}"

	lvcreate -L "$SWAP_VOLUME_SIZE" "$NVME_VOLUMEGROUP_NAME" -n "$SWAP_VOLUME_NAME"
	lvcreate -l "$ROOT_VOLUME_SIZE" "$NVME_VOLUMEGROUP_NAME" -n "$ROOT_VOLUME_NAME"

	mkswap "/dev/${NVME_VOLUMEGROUP_NAME}/${SWAP_VOLUME_NAME}"
	swaplabel -L "$SWAP_VOLUME_LABEL" "/dev/${NVME_VOLUMEGROUP_NAME}/${SWAP_VOLUME_NAME}"

	mkfs.ext4 -O ^metadata_csum,^64bit "/dev/${NVME_VOLUMEGROUP_NAME}/${ROOT_VOLUME_NAME}"

	## mount root partition

	mkdir -p /tmp/root
	mount "/dev/${NVME_VOLUMEGROUP_NAME}/${ROOT_VOLUME_NAME}" /tmp/root



## Step 6: Move root partition files

- mount the NVME root partition (in my case, /tmp/root)
- mount the eMMC root partition (in my case, /run/media/rroels/ROOT_MNJRO)

Then move the content from the eMMC partition to the NVME partition:

	mv /run/media/rroels/ROOT_MNJRO/* /tmp/root/

Now the content is on the correct partition, but we still need to inform the OS that the location has changed. That's what the next steps are for. 

## Step 7: Get partition UUIDs

Get UUID of relevant partitions (run all commands as root):

	NVME_NAME="nvme0"
	NVME_DEVICE="${NVME_NAME}n1"
	NVME_PARTITION_DEVICE="${NVME_DEVICE}p1"
	NVME_PARTITION_NAME="${NVME_PARTITION_DEVICE}_luks"
	NVME_VOLUMEGROUP_NAME="${NVME_PARTITION_NAME}_lvm"

	ROOT_VOLUME_NAME="${NVME_VOLUMEGROUP_NAME}_root"

	SWAP_VOLUME_LABEL="SWAP"
	SWAP_VOLUME_NAME="${NVME_VOLUMEGROUP_NAME}_swap"

	ROOT_UUID=$(blkid -s UUID -o value "/dev/${NVME_VOLUMEGROUP_NAME}/${ROOT_VOLUME_NAME}")
	SWAP_UUID=$(blkid -s UUID -o value "/dev/${NVME_VOLUMEGROUP_NAME}/${SWAP_VOLUME_NAME}")
	NVME_UUID=$(blkid -s UUID -o value "/dev/${NVME_PARTITION_DEVICE}")

	echo "NVME_PARTITION_NAME: $NVME_PARTITION_NAME"
	echo "ROOT_UUID: $ROOT_UUID"
	echo "SWAP_UUID: $SWAP_UUID"
	echo "NVME_UUID: $NVME_UUID"

This will just print a bunch of UUID that you will need in the following steps. Take note of them. 

## Step 8: Update fstab 

Assuming the NVME root partition is mounted as /tmp/root/, edit `/tmp/root/etc/fstab`. Add the following two lines, but replace <ROOT_UUID> and <SWAP_UUID> with their actual UUID (see previous step).

	UUID=<ROOT_UUID> /     ext4 defaults 0 1
	UUID=<SWAP_UUID> none  swap sw       0 0

## Step 9: Update crypttab

Assuming the NVME partition is mounted as /tmp/root/, edit `/tmp/root/etc/crypttab`. Add the following line, but replace <NVME_PARTITION_NAME> and <NVME_UUID> with their actual UUID.

	<NVME_PARTITION_NAME> UUID=<NVME_UUID> none luks,discard

In my case it looks like this:

	nvme0n1p1_luks UUID=76225145-4743-4500-9e83-34f36564756f none luks,discard

## Step 10: Update extlinux.conf

Next, we update extlinux.conf, ***which is on the boot partition of the eMMC***. Assuming the boot partition is mounted as /run/media/rroels/BOOT_MNJRO/, edit `/run/media/rroels/BOOT_MNJRO/extlinux/extlinux.conf`.

In the line that starts with APPEND, remove the existing part `root=PARTUUID=...` and replace it with:

	cryptdevice=UUID=<NVME_UUID>:<NVME_PARTITION_NAME> root=UUID=<ROOT_UUID>

As before, replace <NVME_UUID>, <NVME_PARTITION_NAME> and <ROOT_UUID> with the actual UUID.

## Step 11: Almost Done!

That's it. Remove the SD card and reboot. Thanks to plymouth and the plymouth-encrypt hook you should be greeted with a nice graphical password prompt:

![password prompt](screenshot.jpg?raw=true "Password Prompt")

There is one last thing to do though. We must disable the zram swap so that it starts using the swap partition on the NVME:

	sudo systemctl disable zswap-arm.service

Reboot for it to take effect. 

## Troubleshooting

- If everything randomly freezes, it's possible your NVME is drawing too much power. This is a known issue with the Pinebook Pro. As a workaround, set a higher power saving move for the drive: e.g. `nvme set-feature "/dev/nvme0" -f 2 -v 2`
- If the boot gets stuck on the spinner, and you have no idea why, press F1 to see the TTY output. This should give you a hint about what is wrong. 
- With some versions of uboot (including the one part of 21.06), it would not prioritise SD over eMMC, or it would make weird combinations (like take the boot partition from SD, and load root from eMMC). If you run into similar issues, use the physical eMMC switch on the inside to temporarily disable the eMMC on boot. Once everything is booted, flip the switch again and run these commands as root to activate the eMMC at the software level again:

		echo fe330000.mmc > /sys/bus/platform/drivers/sdhci-arasan/unbind
		echo fe330000.mmc > /sys/bus/platform/drivers/sdhci-arasan/bind

## Future Work

Installing uboot into the SPI flash would eliminate the need for having anything on the eMMC. The eMMC could then be disabled to save battery.

## Sources

- [https://gitlab.manjaro.org/manjaro-arm/applications/manjaro-arm-installer/-/issues/22](https://gitlab.manjaro.org/manjaro-arm/applications/manjaro-arm-installer/-/issues/22)
- [https://ryankozak.com/luks-encrypted-arch-linux-on-pinebook-pro/](https://ryankozak.com/luks-encrypted-arch-linux-on-pinebook-pro/)
- [https://wiki.archlinux.org/title/plymouth#The_plymouth_hook](https://wiki.archlinux.org/title/plymouth#The_plymouth_hook)
