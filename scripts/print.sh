
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. "$DIR/vars.sh"


BOOT_UUID=$(blkid -s UUID -o value "/dev/${EMMC_PARTITION_DEVICE}")
ROOT_UUID=$(blkid -s UUID -o value "/dev/${NVME_VOLUMEGROUP_NAME}/${ROOT_VOLUME_NAME}")
SWAP_UUID=$(blkid -s UUID -o value "/dev/${NVME_VOLUMEGROUP_NAME}/${SWAP_VOLUME_NAME}")
NVME_UUID=$(blkid -s UUID -o value "/dev/${NVME_PARTITION_DEVICE}")

echo "NVME_PARTITION_NAME: $NVME_PARTITION_NAME"
echo "BOOT_UUID: $BOOT_UUID"
echo "ROOT_UUID: $ROOT_UUID"
echo "SWAP_UUID: $SWAP_UUID"
echo "NVME_UUID: $NVME_UUID"

