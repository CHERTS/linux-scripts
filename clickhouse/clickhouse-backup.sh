#!/usr/bin/env bash

#
# Program: Backup Clickhouse via clickhouse-backup <clickhouse-backup.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
#
# Current Version: 1.1
#
# Revision History:
#
#  Version 1.1
#    Added caclulate duration of executing script
#
#  Version 1.0
#    Initial Release
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# Requirements:
#   clickhouse-backup, rsync

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPT_NAME=$(basename "$0")

LOG_FILE=/var/log/clickhouse-server/${SCRIPT_NAME%.*}.log
CLICKHOUSE_BACKUP_NAME=clickhouse-backup-$(date +%Y-%m-%d_%H%M%S)
CLICKHOUSE_BASE_DIR=/var/lib/clickhouse
CLICKHOUSE_BACKUP_OPTS="-s"
RSYNC_BACKUP_STORAGE=/opt/storage/clickhouse_backup
RSYNC_OPTS="-avh --delete-after"

if [ -f "${SCRIPT_DIR}/${SCRIPT_NAME%.*}.conf" ]; then
    source "${SCRIPT_DIR}/${SCRIPT_NAME%.*}.conf"
fi

_command_exists() {
        type "$1" &> /dev/null
}

# Don't edit this config
LOG_FILE_WRITABLE=1
LOG_FILE_EXIST_WRITABLE=1
DATE_START=$(date +"%s")

# Logging function
_logging() {
        local MSG=${1}
        local ENDLINE=${2:-"1"}
        if [[ "${ENDLINE}" -eq 0 ]]; then
                printf "%s: %s" "$(date "+%d.%m.%Y %H:%M:%S")" "${MSG}" 2>/dev/null
        else
                printf "%s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "${MSG}" 2>/dev/null
        fi
        if [ ! -f "${LOG_FILE}" ] && [[ "${LOG_FILE_WRITABLE}" -eq 1 ]]; then
                touch "${LOG_FILE}" >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                        printf "%s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "WARNING: Log file '${LOG_FILE}' is not writable." 2>/dev/null
                        LOG_FILE_WRITABLE=0
                fi
        fi
        if [ -w "${LOG_FILE}" ]; then
                printf "%s | %s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "$$" "${MSG}" 1>>"${LOG_FILE}" 2>&1
        else
                if [[ "${LOG_FILE_EXIST_WRITABLE}" -eq 1 ]] && [[ "${LOG_FILE_WRITABLE}" -eq 1 ]]; then
                        printf "%s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "WARNING: Log file '${LOG_FILE}' is not writable." 2>/dev/null
                        LOG_FILE_EXIST_WRITABLE=0
                fi
        fi
}

# Calculate duration function
_duration() {
        local DATE_START=${1:-"$(date +'%s')"}
        local FUNC_NAME=${2:-""}
        local DATE_END=$(date +"%s")
        local D_MSG=""
        local DATE_DIFF=$((${DATE_END}-${DATE_START}))
        if [ -n "${FUNC_NAME}" ]; then
            local D_MSG=" of execute function '${FUNC_NAME}'"
        fi
        _logging "Duration${D_MSG}: $((${DATE_DIFF} / 3600 )) hours $(((${DATE_DIFF} % 3600) / 60)) minutes $((${DATE_DIFF} % 60)) seconds"
}

# Fail, log and exit script function
_fail() {
        local MSG=${1}
        _logging "${MSG}"
        _duration "${DATE_START}"
        _logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'. Goodbye ;)"
        exit 1
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        _fail "** Trapped CTRL-C"
        exit 1
}

_logging "Starting script '${SCRIPT_DIR}/${SCRIPT_NAME}'"

if _command_exists "clickhouse-backup"; then
	CHBACKUP_BIN=$(which clickhouse-backup)
else
        _fail "ERROR: Command 'clickhouse-backup' not found, please download and install latest version from https://github.com/AlexAkulov/clickhouse-backup"
fi

if _command_exists "rsync"; then
        RSYNC_BIN=$(which rsync)
else
        _fail "ERROR: Command 'rsync' not found."
fi

_logging "Current script configuration:"
_logging "LOG_FILE: ${LOG_FILE}"
_logging "CLICKHOUSE_BASE_DIR: ${CLICKHOUSE_BASE_DIR}"
_logging "RSYNC_BACKUP_STORAGE: ${RSYNC_BACKUP_STORAGE}"

_logging "Run clickhouse-backup..."
${CHBACKUP_BIN} create ${CLICKHOUSE_BACKUP_NAME} ${CLICKHOUSE_BACKUP_OPTS} 1>>"${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
        _logging "Backup done."
else
        _fail "ERROR, See log file '${LOG_FILE}'"
fi

if [ ! -d "${RSYNC_BACKUP_STORAGE}" ]; then
	_logging "Creating rsync backup storage '${RSYNC_BACKUP_STORAGE}'..."
	mkdir "${RSYNC_BACKUP_STORAGE}" 1>>"${LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done."
		chmod 700 "${RSYNC_BACKUP_STORAGE}" 1>>"${LOG_FILE}" 2>&1
		chown clickhouse:clickhouse "${RSYNC_BACKUP_STORAGE}" 1>>"${LOG_FILE}" 2>&1
	else
		_fail "ERROR: Directory '${RSYNC_BACKUP_STORAGE}' not created, see log file '${LOG_FILE}'"
	fi
fi

if [ -d "${RSYNC_BACKUP_STORAGE}" ]; then
	if [ -d "${CLICKHOUSE_BASE_DIR}/backup" ]; then
		_logging "Run rsync..."
		${RSYNC_BIN} ${RSYNC_OPTS} ${CLICKHOUSE_BASE_DIR}/backup/ ${RSYNC_BACKUP_STORAGE} 1>>"${LOG_FILE}" 2>&1
		if [ $? -eq 0 ]; then
			_logging "Rsync done."
			chmod 700 "${RSYNC_BACKUP_STORAGE}" 1>>"${LOG_FILE}" 2>&1
			chown clickhouse:clickhouse "${RSYNC_BACKUP_STORAGE}" 1>>"${LOG_FILE}" 2>&1
		else
			_fail "ERROR: Rsync error, see log file '${LOG_FILE}'"
		fi
	else
		_fail "ERROR: Directory '${CLICKHOUSE_BASE_DIR}/backup' not found, see log file '${LOG_FILE}'"
	fi
fi

_logging "All done."
_duration "${DATE_START}"

_logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'. Goodbye ;)"
