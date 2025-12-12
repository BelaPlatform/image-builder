#!/bin/bash
set -ex

bakdir="$(realpath "$1")"
if [ x = x"${bakdir}" -o ! -d "${bakdir}" ]; then
	echo "Specifiy the bakdir as the first argument"
	exit 1
fi
newdir="$(realpath "$2")"
if [ x = x"${newdir}" ]; then
	echo "Specifiy the newdir as the second argument"
	exit 1
fi
script="$3"
if [ x = x"${script}" -o ! -f "${script}" ]; then
	echo "Specifiy the script as the second argument"
	exit 1
fi

mkdir -p "${newdir}"

chroot_mount_run () {
	if [ ! -d "${tempdir}/run" ] ; then
		sudo mkdir -p ${tempdir}/run || true
		sudo chmod -R 755 ${tempdir}/run
	fi

	if [ "$(mount | grep ${tempdir}/run | awk '{print $3}')" != "${tempdir}/run" ] ; then
		sudo mount -t tmpfs run "${tempdir}/run"
	fi
}

chroot_mount () {
	mkdir -p "${tempdir}"/{sys,proc,dev}
	if [ "$(mount | grep ${tempdir}/sys | awk '{print $3}')" != "${tempdir}/sys" ] ; then
		sudo mount -t sysfs sysfs "${tempdir}/sys"
	fi

	if [ "$(mount | grep ${tempdir}/proc | awk '{print $3}')" != "${tempdir}/proc" ] ; then
		sudo mount -t proc proc "${tempdir}/proc"
	fi

	if [ "$(mount | grep ${tempdir}/dev | awk '{print $3}')" != "${tempdir}/dev" ] ; then
		sudo mount --bind /dev "${tempdir}/dev"
	fi

	if [ "$(mount | grep ${tempdir}/dev/pts | awk '{print $3}')" != "${tempdir}/dev/pts" ] ; then
		sudo mount -t devpts devpts "${tempdir}/dev/pts"
	fi

}

chroot_umount () {
	if [ "$(mount | grep ${tempdir}/dev/pts | awk '{print $3}')" = "${tempdir}/dev/pts" ] ; then
		echo "Log: umount: [${tempdir}/dev/pts]"
		sync
		sudo umount -fl "${tempdir}/dev/pts"

		if [ "$(mount | grep ${tempdir}/dev/pts | awk '{print $3}')" = "${tempdir}/dev/pts" ] ; then
			echo "Log: ERROR: umount [${tempdir}/dev/pts] failed..."
			exit 1
		fi
	fi

	if [ "$(mount | grep ${tempdir}/dev | awk '{print $3}')" = "${tempdir}/dev" ] ; then
		echo "Log: umount: [${tempdir}/dev]"
		sync
		sudo umount -fl "${tempdir}/dev"

		if [ "$(mount | grep ${tempdir}/dev| awk '{print $3}')" = "${tempdir}/dev" ] ; then
			echo "Log: ERROR: umount [${tempdir}/dev] failed..."
			exit 1
		fi
	fi

	if [ "$(mount | grep ${tempdir}/proc | awk '{print $3}')" = "${tempdir}/proc" ] ; then
		echo "Log: umount: [${tempdir}/proc]"
		sync
		sudo umount -fl "${tempdir}/proc"

		if [ "$(mount | grep ${tempdir}/proc | awk '{print $3}')" = "${tempdir}/proc" ] ; then
			echo "Log: ERROR: umount [${tempdir}/proc] failed..."
			exit 1
		fi
	fi

	if [ "$(mount | grep ${tempdir}/sys | awk '{print $3}')" = "${tempdir}/sys" ] ; then
		echo "Log: umount: [${tempdir}/sys]"
		sync
		sudo umount -fl "${tempdir}/sys"

		if [ "$(mount | grep ${tempdir}/sys | awk '{print $3}')" = "${tempdir}/sys" ] ; then
			echo "Log: ERROR: umount [${tempdir}/sys] failed..."
			exit 1
		fi
	fi

	if [ "$(mount | grep ${tempdir}/run | awk '{print $3}')" = "${tempdir}/run" ] ; then
		echo "Log: umount: [${tempdir}/run]"
		sync
		sudo umount -fl "${tempdir}/run"

		if [ "$(mount | grep ${tempdir}/run | awk '{print $3}')" = "${tempdir}/run" ] ; then
			echo "Log: ERROR: umount [${tempdir}/run] failed..."
			exit 1
		fi
	fi
}

tempdir="${bakdir}"
chroot_umount
tempdir="${newdir}"
chroot_umount

rsync -a --delete-before "${bakdir}"/ "${newdir}"

tempdir="${newdir}"
chroot_mount_run
chroot_mount

cp "${script}" "${newdir}"/final.sh

chroot "${newdir}" bash -ex final.sh 

