Install Corretto on Amazon Linux 2:

```bash
yum install -y java-11-amazon-corretto-headless
```

Create partitions on no `sda` and format with `xfs` disks:

```bash
disks="$(ls -1 /dev/sd* | grep -v sda)"

for disk in $disks
do
echo 'type=83' | sudo sfdisk $disk
done

parts="$(ls -1 /dev/sd* | egrep '1$' | grep -v 'sda')"

for part in $parts
do
mkfs.xfs $part
done
```

Create swap:

```bash
uuids=$(blkid | grep xfs | grep -v Linux | cut -d" " -f2 | tr -d '"')

mkdir {/swap,/usr/local/apiactius}

### TO DO
for uuid in $uuids;
do
echo "$uuid     /swap           xfs    defaults,noatime  1   1" >> /etc/fstab
done
###

swapfile="/swap/swapfile"
dd if=/dev/zero of=$swapfile bs=128M count=32
chmod 600 $swapfile
mkswap $swapfile
swapon $swapfile
swapon -s
echo "$swapfile swap swap defaults 0 0" >> /etc/fstab

mount -a
```
