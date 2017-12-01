#!/usr/bin/bash -eu

echo "Type the NFS server IP address or hostname: "
read nfsip
echo "Type target path on the NFS server: "
read nfspath
mount -t nfs ${nfsip}:${nfspath} /mnt

echo "Type the image path e.g. image/win10_20170827 : "
read imgpath
mkdir -p "/mnt/${imgpath}"

while [ 1 ] ; do
echo "Type target disk e.g. sda : "
	read disk
	mkdir -p "/mnt/${imgpath}/${disk}"

	#sfdisk -d /dev/${disk} > /mnt/${imgpath}/${disk}/partition_table
	ptype=$(parted /dev/${disk} print | grep "Partition Table:" | cut -d' ' -f 3)
	if [ "${ptype}" == "gpt" ] ; then
		pnum=$(parted -ms /dev/sda print | tail -1| cut -b1)
		gptsize=$(( ${pnum}*128 + 1024 ))
		dd if=/dev/${disk} of=/mnt/${imgpath}/${disk}/partition_table bs=1 count=${gptsize}
	else
		dd if=/dev/${disk} of=/mnt/${imgpath}/${disk}/partition_table bs=1 count=512
	fi

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
		mksquashfs /tmp "/mnt/${imgpath}/${disk}/$( printf ${part} | cut -d'/' -f3 ).img" -no-progress -comp lz4 -p "image.img f 444 root root /root/${partclonecmd} -s ${part} -O /dev/stdout | dd bs=4M"
		cat torrent.info | ./partclone_create_torrent.py
		mv /root/a.torrent "/mnt/${imgpath}/${disk}/$( printf ${part} | cut -d'/' -f3 ).torrent"
		rm torrent.info
	done

	echo "Do you want to clone another disk? (y/N)"
	read yorn
	if [ "${yorn}" != "y" ] && [ "${yorn}" != "Y" ] ; then
		break
	fi
done
