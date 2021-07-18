 
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. "$DIR/vars.sh"


cryptsetup open "/dev/${NVME_PARTITION_DEVICE}" "$NVME_PARTITION_NAME"

mkdir -p /tmp/root

sleep 3

mount "/dev/${NVME_VOLUMEGROUP_NAME}/${ROOT_VOLUME_NAME}" /tmp/root

