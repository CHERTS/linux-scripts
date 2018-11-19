#!/usr/bin/env bash

#
# Program: Automatic installer Oracle VM VirtualBox Extension Pack <install_dbs_zbx_mon.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
# 
# Current Version: 1.0.0
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

TMP_DIR=/tmp

_command_exists() {
	type "$1" &> /dev/null
}

if _command_exists vboxmanage ; then
	VBOXMANAGER_BIN=$(which vboxmanage)
else
	echo "ERROR: Oracle VM VirtualBox not found."
	exit 1
fi

if _command_exists wget ; then
        WGET_BIN=$(which wget)
else
        echo "ERROR: wget not found."
        exit 1
fi

_installing_pack() {
	local VBOX_PACK_NAME=$1
	if [ -f "${VBOX_PACK_NAME}" ]; then
		echo -n "Installing Oracle VM VirtualBox Extension Pack... "
		#${VBOXMANAGER_BIN} extpack uninstall "Oracle VM VirtualBox Extension Pack"
		${VBOXMANAGER_BIN} extpack install "${VBOX_PACK_NAME}" --replace >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "OK"
		else
			echo "Error"
		fi
		rm -f "${VBOX_PACK_NAME}" >/dev/null 2>&1
	else
		echo "Error: File ${VBOX_PACK_NAME} not found."
	fi
}

VBOX_VERSION=$(${VBOXMANAGER_BIN} -v)
echo "Oracle VM VirtualBox version: ${VBOX_VERSION}"
VBOX_VERSION_1=$(echo ${VBOX_VERSION} | cut -d 'r' -f 1)
VBOX_VERSION_2=$(echo ${VBOX_VERSION} | cut -d 'r' -f 2)

VBOX_EXT_FILE="Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION_1}-${VBOX_VERSION_2}.vbox-extpack"
echo "Oracle VM VirtualBox Extension Pack file: ${VBOX_EXT_FILE}"
echo -n "Try 1: Downloading Oracle VM VirtualBox Extension Pack... "
${WGET_BIN} "http://download.virtualbox.org/virtualbox/${VBOX_VERSION_1}/${VBOX_EXT_FILE}" -O "${TMP_DIR}/${VBOX_EXT_FILE}" >/dev/null 2>&1
EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 0 ]; then
	echo "OK"
	_installing_pack "${TMP_DIR}/${VBOX_EXT_FILE}"
else
	echo "NotFound"
	if [ -f "${TMP_DIR}/${VBOX_EXT_FILE}" ]; then
		rm -f "${TMP_DIR}/${VBOX_EXT_FILE}" >/dev/null 2>&1
	fi
	VBOX_VERSION_2="${VBOX_VERSION_2}a"
	VBOX_EXT_FILE="Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION_1}-${VBOX_VERSION_2}.vbox-extpack"
	echo "Oracle VM VirtualBox Extension Pack file: ${VBOX_EXT_FILE}"
	echo -n "Try 2: Downloading Oracle VM VirtualBox Extension Pack... "
	${WGET_BIN} "http://download.virtualbox.org/virtualbox/${VBOX_VERSION_1}/${VBOX_EXT_FILE}" -O "${TMP_DIR}/${VBOX_EXT_FILE}" >/dev/null 2>&1
	EXIT_CODE=$?
	if [ ${EXIT_CODE} -eq 0 ]; then
		echo "OK"
		_installing_pack "${TMP_DIR}/${VBOX_EXT_FILE}"
	else
		echo "Error, download manual from URL: http://download.virtualbox.org/virtualbox/${VBOX_VERSION_1}/"
	fi
fi
