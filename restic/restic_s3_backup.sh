#!/bin/bash

#
# Program: Backup to S3 via Restic <restic_s3_backup.sh>
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

# S3 config
S3_HOST=https://s3.xxxxx.io
S3_BUCKET=backetname
export AWS_ACCESS_KEY_ID=XXXXX
export AWS_SECRET_ACCESS_KEY=YYYYYYYYYYYYYY
# Directory we are backing up
SRC_DIR=/var/www
# Backup retention policy (forget options)
BACKUP_RETENTION_POLICY_OPTS="--keep-within-daily 7d --keep-within-weekly 1m --keep-within-monthly 1y --keep-within-yearly 3y --prune --verbose"

# Don't edit this config
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
	DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
	SOURCE="$(readlink "$SOURCE")"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
SCRIPT_NAME=$(basename "$0")

# Log file path + name
LOG_FILE="/var/log/${SCRIPT_NAME%.*}.log"
# Realtime config path + name
RT_CONF_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.*}.conf"

# Check command exist function
_command_exists() {
	type "$1" &>/dev/null
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
	local DATE_DIFF=$((${DATE_END} - ${DATE_START}))
	if [ -n "${FUNC_NAME}" ]; then
		local D_MSG=" of execute function '${FUNC_NAME}'"
	fi
	_logging "Duration${D_MSG}: $((${DATE_DIFF} / 3600)) hours $(((${DATE_DIFF} % 3600) / 60)) minutes $((${DATE_DIFF} % 60)) seconds"
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
}

_logging "Starting script '${SCRIPT_DIR}/${SCRIPT_NAME}'"

if [ -f "${RT_CONF_FILE}" ]; then
	_logging "Read config file..."
	source "${RT_CONF_FILE}" 1>>"${LOG_FILE}" 2>&1
fi

_logging "LOG_FILE: ${LOG_FILE}"
_logging "S3_HOST: ${S3_HOST}"
_logging "S3_BUCKET: ${S3_BUCKET}"
_logging "SRC_DIR: ${SRC_DIR}"

if _command_exists "restic"; then
	RESTIC_BIN=$(which restic)
else
	_fail "ERROR: Command 'restic' not found."
fi

if [ ! -d "${SRC_DIR}" ]; then
	_fail "ERROR: Source directory '${SRC_DIR}' not found."
fi

if [ ! -f "${SCRIPT_DIR}/${S3_BUCKET}_backup_password" ]; then
	_fail "ERROR: File include backup repo password not found, please creating them."
fi

_logging "Checking repository, please wait..."
${RESTIC_BIN} check -r s3:${S3_HOST}/${S3_BUCKET} -p "${SCRIPT_DIR}/${S3_BUCKET}_backup_password" 1>>"${LOG_FILE}" 2>&1
RC=$?
if [ ${RC} -eq 0 ]; then
	_logging "Done"
elif [ ${RC} -eq 10 ]; then
	_logging "Backup repository not found, init..."
	${RESTIC_BIN} init -r s3:${S3_HOST}/${S3_BUCKET} -p "${SCRIPT_DIR}/${S3_BUCKET}_backup_password" 1>>"${LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done"
	else
		_fail "ERROR: Backup repository not created."
	fi
else
	_fail "ERROR: Exit code $?, see Restic docs for more info."
fi

if [ ! -f "${SCRIPT_DIR}/${S3_BUCKET}_excludes" ]; then
	_logging "Creating empty exclude file '${SCRIPT_DIR}/${S3_BUCKET}_excludes'..."
	touch "${SCRIPT_DIR}/${S3_BUCKET}_excludes"
fi

_logging "Starting backup, please wait..."
${RESTIC_BIN} backup -r s3:${S3_HOST}/${S3_BUCKET} -p "${SCRIPT_DIR}/${S3_BUCKET}_backup_password" --exclude-file="${SCRIPT_DIR}/${S3_BUCKET}_excludes" "${SRC_DIR}" 1>>"${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
	_logging "Done"
else
	_fail "ERROR: Backup not complete, exit code $?"
fi

_logging "Show snapshots..."
${RESTIC_BIN} snapshots -r s3:${S3_HOST}/${S3_BUCKET} -p "${SCRIPT_DIR}/${S3_BUCKET}_backup_password" 1>>"${LOG_FILE}" 2>&1

# https://restic.readthedocs.io/en/stable/060_forget.html
_logging "Removing backup snapshots..."
${RESTIC_BIN} forget -r s3:${S3_HOST}/${S3_BUCKET} -p "${SCRIPT_DIR}/${S3_BUCKET}_backup_password" ${BACKUP_RETENTION_POLICY_OPTS} 1>>"${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
	_logging "Done"
else
	_fail "ERROR: Remove old snapshots not complete, exit code $?"
fi

_logging "Show stats..."
${RESTIC_BIN} stats -r s3:${S3_HOST}/${S3_BUCKET} -p "${SCRIPT_DIR}/${S3_BUCKET}_backup_password" 1>>"${LOG_FILE}" 2>&1

# Restore snapshot
#restic restore -r s3:${S3_HOST}/${S3_BUCKET} --target "${SRC_DIR}/restore" <id_snapshot>

_logging "All done."
_duration "${DATE_START}"
