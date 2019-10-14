#!/usr/bin/env bash

#
# Program: Automatic update zabbix-frontend <update_zabbix_frontend.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
#
# Current Version: 1.0.5
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

ZBX_VER="4.4.0"
#ZBX_VER="4.2.7"
ZBX_WEB_DIR="/var/www/zabbix.mysite.ru"
ZBX_WEB_DIR_OWNER=web1
ZBX_WEB_DIR_GROUP=client1
ZBX_URL="https://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/${ZBX_VER}/zabbix-${ZBX_VER}.tar.gz/download"

SCRIPT_DIR=$(dirname $0)

_command_exists() {
	type "$1" &> /dev/null
}

if _command_exists tr ; then
	TR_BIN=$(which tr)
else
	echo "Command 'tr' not found."
	exit 1
fi

# Checking the availability of necessary utilities
COMMAND_EXIST_ARRAY=(DU SED AWK CUT EXPR RM CAT WC GREP DIRNAME HEAD LS MV FIND WGET TAR CHOWN CP RSYNC)
for ((i=0; i<${#COMMAND_EXIST_ARRAY[@]}; i++)); do
	__CMDVAR=${COMMAND_EXIST_ARRAY[$i]}
	CMD_FIND=$(echo "${__CMDVAR}" | ${TR_BIN} '[:upper:]' '[:lower:]')
	if _command_exists ${CMD_FIND} ; then
		eval $__CMDVAR'_BIN'="'$(which ${CMD_FIND})'"
		hash "${CMD_FIND}" >/dev/null 2>&1
	else
		echo "Command '${CMD_FIND}' not found."
		exit 1
	fi
done

_get_origin_zabbix_file_size() {
	local ORIG_ZABBIX_FILE_SIZE=0
	local WGET_CONTENT=""
	local WGET_EXIT_CODE=1
	local IS_NUM_REGEXP='^[0-9]+$'
	local RESULT=0
	WGET_CONTENT=$(${WGET_BIN} -S --spider "${ZBX_URL}" --tries 1 2>&1)
	WGET_EXIT_CODE=$?
	if [ ${WGET_EXIT_CODE} -eq 0 ]; then
		ORIG_ZABBIX_FILE_SIZE=$(echo "${WGET_CONTENT}" | ${GREP_BIN} -i "Content-Length" | ${AWK_BIN} '{print $2}' | ${TR_BIN} -d '\n' | ${TR_BIN} -d '\r')
		if [[ ${ORIG_ZABBIX_FILE_SIZE} =~ ${IS_NUM_REGEXP} ]] ; then
			RESULT=${ORIG_ZABBIX_FILE_SIZE}
		fi
	fi
	echo -n "${RESULT}"
}

_check_file_size() {
	local FULL_FILE_NAME=$1
	local IS_NUM_REGEXP='^[0-9]+$'
	local FILESIZE=0
	local FILE_NAME=$(basename ${FULL_FILE_NAME})
	echo -n "Checking file ${FILE_NAME}... "
	if [ -f "${FULL_FILE_NAME}" ]; then
		FILESIZE=$(${LS_BIN} -l "${FULL_FILE_NAME}" | ${AWK_BIN} -F' ' '{print $5}')
		if [[ ${FILESIZE} =~ ${IS_NUM_REGEXP} ]] ; then
			ORIG_ZABBIX_FILE_SIZE=$(_get_origin_zabbix_file_size)
			if [[ ${ORIG_ZABBIX_FILE_SIZE} =~ ${IS_NUM_REGEXP} ]] ; then
				if [ ${FILESIZE} -eq ${ORIG_ZABBIX_FILE_SIZE} ]; then
					echo "OK (${ORIG_ZABBIX_FILE_SIZE} B)"
					return 0
				else
					echo "ERR_BAD_FILESIZE (${FILESIZE} != ${ORIG_ZABBIX_FILE_SIZE})"
					return 1
				fi
			else
				echo "ERR_GET_ORIG_FILESIZE"
				return 1
			fi
		else
			echo "ERR_FILESIZE"
			return 1
		fi
	else
		echo "ERR_FILE_NOTFOUND"
		return 1
	fi
}

_download_new_version() {
	local EXIT_CODE=1
	echo -n "Downloading new zabbix source v${ZBX_VER}... "
	${WGET_BIN} "${ZBX_URL}" -O "${SCRIPT_DIR}/zabbix-${ZBX_VER}.tar.gz" >/dev/null 2>&1
	EXIT_CODE=$?
	if [ ${EXIT_CODE} -eq 0 ]; then
		echo "OK"
	else
		echo "ERR_DOWNLOADING_NOTFOUND"
		${RM_BIN} -f "${SCRIPT_DIR}/zabbix-${ZBX_VER}.tar.gz" 2>/dev/null
	fi
	return ${EXIT_CODE}
}

_clean_zabbix_dist() {
	if [ -d "${SCRIPT_DIR}/zabbix-${ZBX_VER}" ]; then
		${RM_BIN} -rf "${SCRIPT_DIR}/zabbix-${ZBX_VER}" 2>/dev/null
	fi
	if [ -f "${SCRIPT_DIR}/zabbix-${ZBX_VER}.tar.gz" ]; then
		${RM_BIN} -f "${SCRIPT_DIR}/zabbix-${ZBX_VER}.tar.gz" 2>/dev/null
	fi
}

if [ ! -f "${SCRIPT_DIR}/zabbix-${ZBX_VER}.tar.gz" ]; then
	_download_new_version
	if [ $? -ne 0 ]; then
		exit 1
	fi
fi

if [ -f "${SCRIPT_DIR}/zabbix-${ZBX_VER}.tar.gz" ]; then
	_check_file_size "${SCRIPT_DIR}/zabbix-${ZBX_VER}.tar.gz"
	if [ $? -ne 0 ]; then
		exit 1
	fi
	if [ -d "${SCRIPT_DIR}/zabbix-${ZBX_VER}" ]; then
		${RM_BIN} -rf "${SCRIPT_DIR}/zabbix-${ZBX_VER}" 2>/dev/null
	fi
	echo -n "Extracting file zabbix-${ZBX_VER}.tar.gz... "
	${TAR_BIN} -zxf "${SCRIPT_DIR}/zabbix-${ZBX_VER}.tar.gz" 2>/dev/null
	if [ -d "${SCRIPT_DIR}/zabbix-${ZBX_VER}" ]; then
		echo "OK"
	else
		echo "ERR_EXTRACT"
		exit 1
	fi
	if [ -d "${ZBX_WEB_DIR}" ]; then
		if [ -f "${ZBX_WEB_DIR}/conf/zabbix.conf.php" ]; then
			echo -n "Backup 'zabbix.conf.php' file... "
			${CP_BIN} -- "${ZBX_WEB_DIR}/conf/zabbix.conf.php" "${SCRIPT_DIR}/zabbix-${ZBX_VER}/frontends/php/conf" 2>/dev/null
			if [ $? -eq 0 ]; then
				echo "OK"
			else
				echo "ERR_BACKUP_CONF"
				_clean_zabbix_dist
				exit 1
			fi
		fi
		echo -n "Backuping old zabbix frontends... "
		NOW_DATETIME=$(date +%s)
		${TAR_BIN} -zcf "${SCRIPT_DIR}/backup_zabbix_frontends_${NOW_DATETIME}.tar.gz" "${ZBX_WEB_DIR}" 2>/dev/null
		if [ $? -eq 0 ]; then
			echo "OK"
		else
			echo "ERROR_BACKUP"
		fi
		echo -n "Delete old zabbix frontends... "
		${FIND_BIN} "${ZBX_WEB_DIR}" -mindepth 1 -exec ${RM_BIN} -rf '{}' ';' 2>/dev/null
		if [ ! -f "${ZBX_WEB_DIR}/index.php" ]; then
			echo "OK"
		else
			echo "ERR_DELETE_OLD_ZABBIX"
			_clean_zabbix_dist
			exit 1
		fi
		echo -n "Copy new zabbix frontends... "
		${RSYNC_BIN} -av "${SCRIPT_DIR}/zabbix-${ZBX_VER}/frontends/php/" "${ZBX_WEB_DIR}/" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "OK"
		else
			echo "ERR_COPY_NEW_ZABBIX_FRONTEND"
			_clean_zabbix_dist
			exit 1
		fi
		echo -n "Set directory owner ${ZBX_WEB_DIR_OWNER}:${ZBX_WEB_DIR_GROUP}... "
		${CHOWN_BIN} -R ${ZBX_WEB_DIR_OWNER}:${ZBX_WEB_DIR_GROUP} "${ZBX_WEB_DIR}/" 2>/dev/null
		if [ $? -eq 0 ]; then
			echo "OK"
		else
			echo "ERR_SET_WEBDIR_OWNER"
			_clean_zabbix_dist
			exit 1
		fi
	else
		echo "WARNING: Directory '${ZBX_WEB_DIR}' not exist. Abort update..."
	fi
	_clean_zabbix_dist
fi
