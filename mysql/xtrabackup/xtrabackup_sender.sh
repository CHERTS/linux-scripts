#!/usr/bin/env bash

#
# Program: Percona xtrabackup sender <xtrabackup_sender.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
# 
# Current Version: 1.0.3
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPT_NAME=$(basename "$0")

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
	echo "** Trapped CTRL-C"
}

RECIVER_MAGIC_TAG="MGPING" # !!!DONT EDIT!!!
XTRABACKUP_OPTS="--defaults-file=/etc/mysql/my.cnf --no-backup-locks --no-lock --parallel=4 --backup --stream=xbstream"
MARIABACKUP_OPTS="--defaults-file=/etc/mysql/mariadb.conf.d/50-server.cnf --no-backup-locks --no-lock --parallel=4 --backup --stream=mbstream"

LOG_FILE=${SCRIPT_DIR}/${SCRIPT_NAME%.*}.log

_logging() {
	local MSG=${1}
	printf "%s | %s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "$$" "${MSG}" 2>/dev/null
	tail -n 1 "${LOG_FILE}" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		if [ -f "${LOG_FILE}" ]; then
			mv "${LOG_FILE}" "${LOG_FILE}.$(date '+%d%m%Y_%H%M%S')" >/dev/null 2>&1
		fi
	fi
	printf "%s | %s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "$$" "${MSG}" 1>>"${LOG_FILE}" 2>&1
}

FAILURE=1
SUCCESS=0

_fail() {
	_logging "$1"
	_logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'"
	exit ${FAILURE}
}

_command_exists() {
	type "$1" &> /dev/null
}

_usage() {
	echo ""
	echo "Usage: $0 [ -m <BACKUP_METHOD> -a <RECIVER_IP> -p <RECIVER_PORT>]"
	echo ""
	echo "  -m BACKUP_METHOD	: (Required) Backup method (percona or maria)"
	echo "  -a RECIVER_IP		: (Required) IP or DNS address of reciver"
	echo "  -p RECIVER_PORT	: (Optional) Reciver port (default: 9999)"
	echo ""
	echo "  -h			: Print this screen"
	echo ""
	exit 0
}

[ $# -eq 0 ] && _usage

while getopts ":hm:a:p:" option; do
	case "${option}" in
		m)
			BACKUP_METHOD=${OPTARG}
			;;
		a)
			RECIVER_IP=${OPTARG}
			;;
		p)
			RECIVER_PORT=${OPTARG}
			;;
		h | *)
			_usage
			;;
	esac
done

if [ -z "${BACKUP_METHOD}" ]; then
	echo "No options -m <BACKUP_METHOD> found!"
	_usage
fi

if [ -z "${RECIVER_IP}" ]; then
	echo "No options -a <RECIVER_IP> found!"
	_usage
fi

_logging "Starting script '${SCRIPT_DIR}/${SCRIPT_NAME}'"

case "${BACKUP_METHOD}" in
	percona)
		_logging "Select Percona XtraBackup"
	;;
	maria)
		_logging "Select MariaDB Backup"
	;;
	* )
		_usage
	;;
esac

if [ -z "${RECIVER_PORT}" ]; then
	RECIVER_PORT=9999
fi

if [ -f "${SCRIPT_DIR}/xtrabackup_sender.conf" ]; then
	source "${SCRIPT_DIR}/xtrabackup_sender.conf"
	if [[ "${BACKUP_METHOD}" = "percona" ]]; then
		if [ -n "${XTRABACKUP_ADDITIONS_OPTS}" ]; then
			XTRABACKUP_OPTS="${XTRABACKUP_OPTS} ${XTRABACKUP_ADDITIONS_OPTS}"
		fi
	fi
	if [[ "${BACKUP_METHOD}" = "maria" ]]; then
		if [ -n "${MARIABACKUP_ADDITIONS_OPTS}" ]; then
			MARIABACKUP_OPTS="${MARIABACKUP_OPTS} ${MARIABACKUP_ADDITIONS_OPTS}"
		fi
	fi
fi

if [ -z "${USE_STREAM_PROGRAM}" ]; then
	USE_STREAM_PROGRAM="nc"
fi

if [[ "${BACKUP_METHOD}" = "percona" ]]; then
	if _command_exists xtrabackup ; then
		XTRABACKUP_BIN=$(which xtrabackup)
	else
		_fail "ERROR: Command 'xtrabackup' not found."
	fi
fi

if [[ "${BACKUP_METHOD}" = "maria" ]]; then
	if _command_exists mariabackup ; then
		MARIABACKUP_BIN=$(which mariabackup)
	else
		_fail "ERROR: Command 'mariabackup' not found."
	fi
fi

NC_ON_BASH=0
if _command_exists nc ; then
	NC_BIN=$(which nc)
else
	if _command_exists ncat ; then
		NC_BIN=$(which ncat)
	else
		NC_ON_BASH=1
	fi
fi

case "${USE_STREAM_PROGRAM}" in
	socat)
		if _command_exists socat ; then
			STREAM_PROGRAM=$(which socat)
			STREAM_PROGRAM_OPTS="- TCP4:${RECIVER_IP}:${RECIVER_PORT}"
		else
			_fail "ERROR: Command 'socat' not found."
		fi
		;;
	nc)
		if _command_exists nc ; then
			STREAM_PROGRAM=$(which nc)
			STREAM_PROGRAM_OPTS="${RECIVER_IP} ${RECIVER_PORT}"
		else
			_fail "ERROR: Command 'nc' not found."
		fi
		;;
	ncat)
		if _command_exists ncat ; then
			STREAM_PROGRAM=$(which ncat)
			STREAM_PROGRAM_OPTS="${RECIVER_IP} ${RECIVER_PORT}"
		else
			_fail "ERROR: Command 'ncat' not found."
		fi
		;;
	*)
		_fail "ERROR: Unrecognize 'USE_STREAM_PROGRAM' settings."
		;;
esac

_nc() {
	(echo "${1}" >/dev/tcp/${2}/${3}) >/dev/null 2>&1
}

_logging "Sending magic tag to reciver..."
if [ ${NC_ON_BASH} -eq 1 ]; then
	_nc "${RECIVER_MAGIC_TAG}" "${RECIVER_IP}" "${RECIVER_PORT}"
	EXIT_CODE=$?
else
	echo "${RECIVER_MAGIC_TAG}" | ${NC_BIN} -w 1 "${RECIVER_IP}" "${RECIVER_PORT}" >/dev/null 2>&1
	EXIT_CODE=$?
fi

if [ ${EXIT_CODE} -eq 0 ]; then
	_logging "Done, magic tag has sended."
	_logging "Waiting 10 second..."
        sleep 10
	if [[ "${BACKUP_METHOD}" = "percona" ]]; then
		_logging "Starting xtrabackup (pipe: ${USE_STREAM_PROGRAM}), please wait..."
		ulimit -n 256000 && ${XTRABACKUP_BIN} ${XTRABACKUP_OPTS} | ${STREAM_PROGRAM} ${STREAM_PROGRAM_OPTS} >/dev/null 2>&1
		EXIT_CODE=$?
	elif [[ "${BACKUP_METHOD}" = "maria" ]]; then
		_logging "Starting mariabackup (pipe: ${USE_STREAM_PROGRAM}), please wait..."
		ulimit -n 256000 && ${MARIABACKUP_BIN} ${MARIABACKUP_OPTS} | ${STREAM_PROGRAM} ${STREAM_PROGRAM_OPTS} >/dev/null 2>&1
		EXIT_CODE=$?
	else
		_fail "ERROR: Unsupported 'BACKUP_METHOD' settings."
	fi
	if [ ${EXIT_CODE} -eq 0 ]; then
		if [[ "${USE_STREAM_PROGRAM}" = "nc" ]]; then
			_logging "Done, please press Ctrl+C to exit."
		else
			_logging "Done, backup has sended."
		fi
	else
		_fail "Error, backup not sended."
	fi
else
	_fail "Error: Reciver '${RECIVER_IP}:${RECIVER_PORT}' not ready to connection."
fi

_logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'"
