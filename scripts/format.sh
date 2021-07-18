 
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. "$DIR/vars.sh"

## unmount all partitions

ls -1 /dev/* | grep "/dev/${EMMC_DEVICE}" | xargs umount
ls -1 /dev/* | grep "/dev/${NVME_DEVICE}" | xargs umount

## reduce NVMe power consumption

nvme set-feature "/dev/${NVME_NAME}" -f 2 -v 2

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

## mount boot and root partition

mkdir -p /tmp/root
mount "/dev/${NVME_VOLUMEGROUP_NAME}/${ROOT_VOLUME_NAME}" /tmp/root

