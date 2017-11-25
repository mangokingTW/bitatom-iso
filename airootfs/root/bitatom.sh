#!/usr/bin/bash -eu

echo "Type the NFS server IP address: "
read nfsip
echo "Type target path on the NFS server: "
read nfspath
mount -t nfs ${nfsip}:${nfspath} /mnt

echo "Type target disk e.g. sda : "
read disk
echo "Type the image name : "
read imgname
mkdir -p "/mnt/${imgname}"

sfdisk -d /dev/${disk} > /mnt/${imgname}/partition_table
dd if=/dev/${disk} of=/mnt/${imgname}/mbr.img bs=512 count=1
partitions=$(sfdisk -d /dev/${disk} | grep -e '^/dev/' | cut -d' ' -f1)
for part in ${partitions}; do
	partclonecmd=""
	fs=$( lsblk -n -f ${part} | cut -d' ' -f2 )
	echo "partition: ${part}. file system: ${fs}."
	if [ "${fs:0:3}" == "ext" ] ; then
		partclonecmd="partclone.extfs -c -a0" 
	elif [ "${fs:0:4}" == "ntfs" ] ; then
		partclonecmd="partclone.ntfs -c -a0" 
	elif [ "${fs:0:3}" == "fat" ] ; then
		partclonecmd="partclone.fat -c -a0" 
	elif [ "${fs:0:5}" == "exfat" ] ; then
		partclonecmd="partclone.exfat -c -a0" 
	elif [ "${fs:0:5}" == "btrfs" ] ; then
		partclonecmd="partclone.btrfs -c -a0" 
	else
		partclonecmd="partclone.dd"
	fi
	mksquashfs /tmp "/mnt/${imgname}/$( printf ${part} | cut -d'/' -f3 ).img" -comp lz4 -p "image.img f 444 root root /root/${partclonecmd} -q -s ${part} -O /dev/stdout | dd bs=4M"
	cat torrent.info | ./partclone_create_torrent.py
	mv /root/a.torrent "/mnt/${imgname}/$( printf ${part} | cut -d'/' -f3 ).torrent"
done
