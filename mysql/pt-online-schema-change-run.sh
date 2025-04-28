#!/usr/bin/env bash

#
# Program: Interactive run pt-online-schema-change <pt-online-schema-change-run.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
# 
# Current Version: 1.0.1
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

PT_MASTER_HOST=127.0.0.1
PT_SLAVE_HOST=10.XX.XX.XX
PT_PORT=3306
PT_USER=root
PT_DB=mydb
PT_TBL=mytable
PT_ALTER="ADD COLUMN mycol INT NOT NULL DEFAULT 0"
PT_OPTS="--recursion-method=none --no-drop-old-table --ask-pass --critical-load='Threads_running=200' --max-load='Threads_running=100' --check-interval=1 --max-lag=2s --progress=time,2"

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPT_NAME=$(basename $0)

# Log file path + name
LOG_FILE=/var/log/${SCRIPT_NAME%.*}.log
# Realtime config path + name
RT_CONF_FILE=${SCRIPT_DIR}/${SCRIPT_NAME%.*}.conf
# pt-online-schema-change pause file
PT_P_FILE=${SCRIPT_DIR}/pt-online-pausefile-$(date +%s)

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

if _command_exists pt-online-schema-change; then
	PT_BIN=$(which pt-online-schema-change)
else
	echo "Command 'pt-online-schema-change' not found."
	exit 1
fi

_logging "Starting script '${SCRIPT_DIR}/${SCRIPT_NAME}'"

if [ -f "${RT_CONF_FILE}" ]; then
        _logging "Read config file..."
        source "${RT_CONF_FILE}" 1>>"${LOG_FILE}" 2>&1
fi

_logging "Current script configuration:"
_logging "LOG_FILE: ${LOG_FILE}"
_logging "RT_CONF_FILE: ${RT_CONF_FILE}"
_logging "MASTER: ${PT_MASTER_HOST}"
_logging "SLAVE: ${PT_SLAVE_HOST}"
_logging "PORT: ${PT_PORT}"
_logging "DB: ${PT_DB}"
_logging "USER: ${PT_USER}"
_logging "TABLE: ${PT_TBL}"
_logging "ALTER: ${PT_ALTER}"
_logging "PAUSE_FILE: ${PT_P_FILE}"
_logging "PT_OPTS: ${PT_OPTS}"

read -n 1 -s -r -p "Press any key to run pt-osc or press Ctrl+C to abort" && echo

${PT_BIN} ${PT_OPTS} --check-slave-lag=h=${PT_SLAVE_HOST},P=${PT_PORT},D=${PT_DB},t=${PT_TBL} \
--user=${PT_USER} --alter="${PT_ALTER}" \
--execute h=${PT_MASTER_HOST},P=${PT_PORT},D=${PT_DB},t=${PT_TBL} --pause-file ${PT_P_FILE}

_logging "All done."
_duration "${DATE_START}"

_logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'. Goodbye ;)"
