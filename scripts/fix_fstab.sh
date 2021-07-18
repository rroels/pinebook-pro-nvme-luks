
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. "$DIR/vars.sh"

echo "UUID=ROOT_UUID /     ext4 defaults 0 1" >> /tmp/root/etc/fstab
echo "UUID=SWAP_UUID none  swap sw       0 0" >> /tmp/root/etc/fstab
sed -i "s/ROOT_UUID/${ROOT_UUID}/" /tmp/root/etc/fstab
sed -i "s/SWAP_UUID/${SWAP_UUID}/" /tmp/root/etc/fstab

cat /tmp/root/etc/fstab

