DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. "$DIR/vars.sh"

echo "nvme0n1p1_luks UUID=NVME_UUID none luks,discard" >> /tmp/root/etc/crypttab
echo "" >> /tmp/root/etc/crypttab

sed -i "s/NVME_UUID/${NVME_UUID}/" /tmp/root/etc/crypttab

cat /tmp/root/etc/crypttab

