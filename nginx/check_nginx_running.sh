#!/usr/bin/env bash

#
# Program: Check nginx main and worker process and restart if crash <check_nginx_running.sh>
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

RESTART_NGINX_IF_NOT_RUNNING=1
ENABLE_SILENT_MODE=0
SCRIPT_NAME=$(basename $0)
LOG_FILE=/var/log/${SCRIPT_NAME%.*}.log
EXIT_CODE=0

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

_command_exists () {
	type "${1}" &> /dev/null ;
}

_logging() {
	local MSG=${1}
	if [ ${ENABLE_SILENT_MODE} -eq 0 ]; then
		printf "%s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "${MSG}" 2>/dev/null
	fi
	printf "%s | %s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "$$" "${MSG}" 1>>${LOG_FILE} 2>&1
}

_logging "[INIT] Starting script '${SCRIPT_DIR}/${SCRIPT_NAME}'"

CURRENT_USER=$(whoami)
if [[ "${CURRENT_USER}" = "root" ]]; then
	_logging "[CHECK] Checking your privileges... OK"
else
	_logging "[ERROR] root access is required."
	_logging "[END] Script '${SCRIPT_DIR}/${SCRIPT_NAME}'"
	exit 1
fi

if _command_exists nginx ; then
	NGINX_BIN=$(which nginx)
else
	_logging "[ERROR] nginx binary not found."
	_logging "[END] Script '${SCRIPT_DIR}/${SCRIPT_NAME}'"
	exit 1
fi

if _command_exists pmap ; then
	PMAP_BIN=$(which pmap)
else
	_logging "[ERROR] pmap binary not found."
	_logging "[END] Script '${SCRIPT_DIR}/${SCRIPT_NAME}'"
	exit 1
fi

NGINX_MASTER_PROCESS_NUM=$(ps -ef | grep [n]ginx | grep -c master)
NGINX_WORKER_PROCESS_NUM=$(ps -ef | grep [n]ginx | grep -c worker)

_logging "[CHECK] Found ${NGINX_MASTER_PROCESS_NUM} nginx main process."
_logging "[CHECK] Found ${NGINX_WORKER_PROCESS_NUM} nginx worker process."

if [ ${NGINX_MASTER_PROCESS_NUM} -eq 0 ]; then
	_logging "[CRITICAL] Master process not running!"
	${NGINX_BIN} -t > "/tmp/nginx_configtest" 2>&1
	NGX_CONFIG_TEST_RESULT=$(grep successful "/tmp/nginx_configtest")
	if [ -z "${NGX_CONFIG_TEST_RESULT}" ]; then
		_logging "[CRITICAL] Nginx configuration is broken."
	else
		_logging "[OK] Nginx configuration correct."
	fi
	rm -f "/tmp/nginx_configtest" >/dev/null 2>&1
	if [ ${RESTART_NGINX_IF_NOT_RUNNING} -eq 1 ]; then
		systemctl stop nginx >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			_logging "[OK] The nginx process has been successfully stopped."
		else
			_logging "[WARNING] The nginx process failed to stop."
		fi
		systemctl start nginx >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			_logging "[OK] The nginx process has been successfully started."
		else
			_logging "[CRITICAL] The nginx process failed to start."
			EXIT_CODE=1
		fi
	fi
else
	NGINX_MASTER_PID=$(ps -eo pid,command | grep [n]ginx | grep master | awk -F' ' '{print $1}')
	if [ -n ${NGINX_MASTER_PID} ]; then
		NGINX_MASTER_MEM_USAGE=$(${PMAP_BIN} ${NGINX_MASTER_PID} | tail -n 1 | awk '/[0-9]K/{print $2}')
		_logging "[STAT] Nginx master process ${NGINX_MASTER_PID} used ${NGINX_MASTER_MEM_USAGE} memory."
	fi
	OLD_IFS=$IFS
	IFS=$'\n'
	NGINX_WORKERS_PID=($(ps -eo pid,command | grep [n]ginx | grep worker | awk -F' ' '{print $1}'))
	for ((i=0; i<${#NGINX_WORKERS_PID[@]}; i++)); do
		if [ -n ${NGINX_WORKERS_PID[$i]} ]; then
			NGINX_WORKER_MEM_USAGE=$(${PMAP_BIN} ${NGINX_WORKERS_PID[$i]} | tail -n 1 | awk '/[0-9]K/{print $2}')
			_logging "[STAT] Nginx worker process ${NGINX_WORKERS_PID[$i]} used ${NGINX_WORKER_MEM_USAGE} memory."
		fi
	done
	IFS=${OLD_IFS}
fi

_logging "[END] Script '${SCRIPT_DIR}/${SCRIPT_NAME}'"
exit ${EXIT_CODE}
