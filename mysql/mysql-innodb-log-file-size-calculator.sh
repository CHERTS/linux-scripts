#!/usr/bin/env bash

#
# Program: Calculate InnoDB redo log used and write speed <mysql_innodb_log_file_size_calculator.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
# 
# Current Version: 1.3
#
# Revision History:
#
#  Version 1.3
#    Fixed parsing user and password in .my.cnf file
#
#  Version 1.2
#    Small fix
#
#  Version 1.1
#    Added MySQL 8.x support
#
#  Version 1.1
#    Added MariaDB 10.4 and 10.5 support
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
#   Requires mysql
#
# Installation:
#   Copy the shell script to a suitable location
#
# Tested platforms:
#  -- Debian 9 using /bin/bash
#  -- Debian 10 using /bin/bash
#  -- Ubuntu 16.04 using /bin/bash
#  -- Ubuntu 18.04 using /bin/bash
#
# Tested MySQL:
#  -- Oracle MySQL 5.7.22
#  -- MariaDB 10.1.41/10.3.8/10.4.13
#  -- Percona Server for MySQL 5.6.40-84.0/5.7.22-22
#
# Usage:
#  Refer to the _show_help() sub-routine, or invoke mysql_innodb_log_file_size_calculator.sh
#  with the "-h" option.
#
# Example:
#
#  The first example will run test:
#
#  $ ./mysql_innodb_log_file_size_calculator.sh 
#  or
#  $ ./mysql_innodb_log_file_size_calculator.sh --user root --password "XXXXXXX"
#
#  ================================================
#  Connected MySQL v5.7.22-0ubuntu0.16.04.1-log
#  ================================================
#  Checking InnoDB Monitor...
#  InnoDB Monitor (log_lsn_last_checkpoint): enabled
#  InnoDB Monitor (log_lsn_current): enabled
#  ================================================
#  Calculate InnoDB redo-log used:
#  innodb_log_file_size = 6442450944
#  innodb_log_files_in_group = 2
#  innodb_total_log_size = 12884901888
#  Last checkpoint at: 213558628577512
#  Log sequence number: 213559891585442
#  Log used (byte): 1263007930
#  Log used (Mbyte): 1204
#  Log used (%): 9.00
#  ================================================
#  Calculate InnoDB redo-log write speed:
#  Innodb_os_log_written = 136634707968
#  Sleeping 60 second...
#  Innodb_os_log_written = 136755052032
#  Write speed (MB_per_60_second): 114.769
#  Write speed (MB_per_1_hour): 6886.140
#  ================================================
#  Note: Current redo-log write speed > innodb_log_file_size
#  Recomended set parameter innodb_log_file_size = 7574M
#  ================================================

_command_exists() {
	type "$1" &> /dev/null
}

VERSION="1.0"

echo ""
echo "Calculate InnoDB redo log used and write speed v$VERSION"
echo "Written by Mikhail Grigorev (sleuthhound@gmail.com, http://blog.programs74.ru)"
echo ""

_show_help() {
        echo -e "\t--help -h\t\tthis menu"
        echo -e "\t--user username\t\tspecify mysql username to use, the script will prompt for a password during runtime, unless you supply a password"
        echo -e "\t--password \"yourpass\""
        echo -e "\t--host hostname\t\tspecify mysql hostname to use, be it local (default) or remote"
        echo -e "\t--port port \t\tspecify mysql port to use, default 3306"
}

while [[ $1 == -* ]]; do
        case "$1" in
                --user)         MYSQL_USER="$2"; shift 2;;
                --password)     MYSQL_PASSWD="$2"; shift 2;;
                --host)         MYSQL_HOST="$2"; shift 2;;
                --port)         MYSQL_PORT="$2"; shift 2;;
                --help|-h)      _show_help; exit 0;;
                --*)            shift; break;;
        esac
done

if _command_exists "mysql"; then
	MYSQL_BIN=$(which mysql)
else
	echo "ERROR: Command 'mysql' not found."
	exit 1
fi

MYSQL_CNF="$HOME/.my.cnf"

if [ -f "${MYSQL_CNF}" ]; then
        if egrep -E "host.*=" "${MYSQL_CNF}" >/dev/null 2>&1; then
                MYSQL_HOST=$(egrep -m 1 -E "host.*=" "${MYSQL_CNF}" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
        fi
        if egrep -E "port.*=" "${MYSQL_CNF}" >/dev/null 2>&1; then
                MYSQL_PORT=$(egrep -m 1 -E "port.*=" "${MYSQL_CNF}" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
        fi
        if egrep -E "user.*=" "${MYSQL_CNF}" >/dev/null 2>&1; then
                MYSQL_USER=$(egrep -m 1 -E "user.*=" "${MYSQL_CNF}" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
                if egrep -E "password.*=" "${MYSQL_CNF}" >/dev/null 2>&1; then
                        MYSQL_PASSWD=$(egrep -m 1 -E "password.*=" "${MYSQL_CNF}" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
                else
                        echo "Not found password line in your '${MYSQL_CNF}', fix this or specify with --password"
                fi
        else
                echo "Not found user line in your '${MYSQL_CNF}', fix this or specify with --user"
                exit 1;
        fi
else
        if [ -z "${MYSQL_USER}" ]; then
                echo "ERROR: Authentication information not found as arguments and in file '${MYSQL_CNF}'."
                echo
                _show_help
                exit 1;
        fi
fi

MYSQL="${MYSQL_BIN} -u ${MYSQL_USER}"

if [ -n "${MYSQL_HOST}" ]; then
        MYSQL="${MYSQL} -h ${MYSQL_HOST}"
fi

if [ -n "${MYSQL_PORT}" ]; then
        MYSQL="${MYSQL} -P ${MYSQL_PORT}"
fi

if [ -n "${MYSQL_PASSWD}" ]; then
        export MYSQL_PWD="${MYSQL_PASSWD}"
else
	echo "Error: MySQL password for user ${MYSQL_USER} is empty, please change password and create settings file '${MYSQL_CNF}'."
	exit 1
fi

if [ -f "${MYSQL_CNF}" ]; then
        if ! `echo 'exit' | ${MYSQL_BIN} --defaults-file="${MYSQL_CNF}" -s >/dev/null 2>&1` ; then
                if ! `echo 'exit' | ${MYSQL} -s >/dev/null 2>&1` ; then
                        echo "Error[0]: Supplied mysql username or password appears to be incorrect."
                        exit
                fi
        else
                MYSQL="${MYSQL_BIN} --defaults-file=${MYSQL_CNF}"
        fi
fi

_mysql_exec_one_query() {
        local SQL=$1
        local MYSQL_OPT=${2:-"-N"}
        local RESULT=""
        local RESULT_NUM=0
        local RESULT_CODE=0
        local RESULT_CON=""
        local RESULT_CON_CODE=0
        local EXIT_CODE=0
        local OLD_IFS=$IFS
	if ! `echo 'exit' | ${MYSQL} -s >/dev/null 2>&1` ; then
                RESULT_CON="Supplied mysql username or password appears to be incorrect."
                RESULT_CON_CODE=1
        else
                RESULT=($(echo "${SQL}" | ${MYSQL} ${MYSQL_OPT} 2>/dev/null))
		IFS=$'\n'
                RESULT_CODE=$?
                RESULT_NUM=${#RESULT[*]}
		IFS=$OLD_IFS
        fi
        if [ ${RESULT_CODE} -eq 0 ]; then
                if [ ${RESULT_CON_CODE} -eq 1 ]; then
                        RESULT=${RESULT_CON}
                        EXIT_CODE=1
                else
                        EXIT_CODE=0
                fi
        else
                RESULT="An error occurred while executing SQL query \"$SQL\"."
                EXIT_CODE=1
        fi
        if [ ${RESULT_NUM} -gt 1 ]; then
                echo "${RESULT[*]}"
        else
                echo "${RESULT}"
        fi
        return ${EXIT_CODE}
}

if _command_exists "bc"; then
	MYSQL_VER=$(_mysql_exec_one_query "select version();")
        if [ $? -eq 0 ]; then
                echo "================================================"
                echo "Connected MySQL v${MYSQL_VER}"
                echo "================================================"
                if echo "${MYSQL_VER}" | grep -q -e "^5.6" -e "^10.1" -e "^10.2" -e "^10.3" -e "^10.4" -e "^10.5"; then
                        MYSQL_SETTINGS_SCHEMA="information_schema"
                elif echo "${MYSQL_VER}" | grep -q -e "^5.7" -e "^8.0"; then
                        MYSQL_SETTINGS_SCHEMA="performance_schema"
                else
                        MYSQL_SETTINGS_SCHEMA="information_schema"
                fi
		echo "Checking InnoDB Monitor..."
		LOG_LSN_LAST_CHECKPOINT_ENABLED=$(_mysql_exec_one_query "SELECT status FROM INFORMATION_SCHEMA.INNODB_METRICS WHERE NAME='log_lsn_last_checkpoint';")
		if [ $? -eq 0 ]; then
			echo "InnoDB Monitor (log_lsn_last_checkpoint): ${LOG_LSN_LAST_CHECKPOINT_ENABLED}"
			if [[ "${LOG_LSN_LAST_CHECKPOINT_ENABLED}" = "disabled" ]]; then
				echo -n "Enable monitor log_lsn_last_checkpoint... "
				RESULT=$(_mysql_exec_one_query "SET GLOBAL innodb_monitor_enable = log_lsn_last_checkpoint;" "-s")
				if [ $? -eq 0 ]; then
					echo "OK"
				else
					echo "Error"
				fi
			fi
		fi
		LOG_LSN_CURRENT_ENABLED=$(_mysql_exec_one_query "SELECT status FROM INFORMATION_SCHEMA.INNODB_METRICS WHERE NAME='log_lsn_current';")
		if [ $? -eq 0 ]; then
			echo "InnoDB Monitor (log_lsn_current): ${LOG_LSN_CURRENT_ENABLED}"
                        if [[ "${LOG_LSN_CURRENT_ENABLED}" = "disabled" ]]; then
                                echo -n "Enable monitor log_lsn_current... "
                                RESULT=$(_mysql_exec_one_query "SET GLOBAL innodb_monitor_enable = log_lsn_current;" "-s")
                                if [ $? -eq 0 ]; then
                                        echo "OK"
                                else
                                        echo "Error"
                                fi
                        fi
		fi
		echo "================================================"
        else
                echo "Error[1]: ${MYSQL_VER}"
                exit
        fi
        echo "Calculate InnoDB redo-log used:"
        INNODB_LOG_FILE_SIZE=$(_mysql_exec_one_query "SELECT VARIABLE_VALUE FROM ${MYSQL_SETTINGS_SCHEMA}.global_variables WHERE VARIABLE_NAME = 'innodb_log_file_size';")
        if [ $? -eq 0 ]; then
		if [ -n "${INNODB_LOG_FILE_SIZE}" ]; then
	                echo "innodb_log_file_size = ${INNODB_LOG_FILE_SIZE}"
		else
			echo "innodb_log_file_size = NULL"
			exit 1
		fi
        else
                echo "Error: ${INNODB_LOG_FILE_SIZE}"
                exit
        fi
        INNODB_LOG_FILES_IN_GROUP=$(_mysql_exec_one_query "SELECT VARIABLE_VALUE FROM ${MYSQL_SETTINGS_SCHEMA}.global_variables WHERE VARIABLE_NAME = 'innodb_log_files_in_group';")
        if [ $? -eq 0 ]; then
		if [ -n "${INNODB_LOG_FILES_IN_GROUP}" ]; then
	                echo "innodb_log_files_in_group = ${INNODB_LOG_FILES_IN_GROUP}"
		else
			echo "innodb_log_files_in_group = NULL"
			exit 1
		fi
        else
                echo "Error: ${INNODB_LOG_FILES_IN_GROUP}"
                exit
        fi
        INNODB_TOTAL_LOG_SIZE=$(echo "${INNODB_LOG_FILE_SIZE}*${INNODB_LOG_FILES_IN_GROUP}" | bc)
        echo "innodb_total_log_size = ${INNODB_TOTAL_LOG_SIZE}"
        LOG_LSN_LAST_CHECKPOINT=$(_mysql_exec_one_query "SELECT COUNT FROM INFORMATION_SCHEMA.INNODB_METRICS WHERE NAME='log_lsn_last_checkpoint';")
        if [ $? -eq 0 ]; then
		echo "Last checkpoint at: ${LOG_LSN_LAST_CHECKPOINT}"
        else
                echo "Error: ${LOG_LSN_LAST_CHECKPOINT}"
                exit
        fi
        LOG_LSN_CURRENT=$(_mysql_exec_one_query "SELECT COUNT FROM INFORMATION_SCHEMA.INNODB_METRICS WHERE NAME='log_lsn_current';")
        if [ $? -eq 0 ]; then
                 echo "Log sequence number: ${LOG_LSN_CURRENT}"
        else
                echo "Error: ${LOG_LSN_CURRENT}"
                exit
        fi
        LOG_USED_BYTE=$(echo "${LOG_LSN_CURRENT}-${LOG_LSN_LAST_CHECKPOINT}" | bc)
        echo "Log used (byte): ${LOG_USED_BYTE}"
        LOG_USED_MBYTE=$(echo "${LOG_USED_BYTE}/(1024*1024)" | bc)
        echo "Log used (Mbyte): ${LOG_USED_MBYTE}"
        LOG_USED_PRC=$(echo "scale=2;(${LOG_USED_BYTE}/${INNODB_TOTAL_LOG_SIZE})*100" | bc)
        echo "Log used (%): ${LOG_USED_PRC}"
        echo "================================================"
        echo "Calculate InnoDB redo-log write speed:"
        INNODB_LOG_WRITE_1=$(_mysql_exec_one_query "SELECT VARIABLE_VALUE FROM ${MYSQL_SETTINGS_SCHEMA}.global_status WHERE VARIABLE_NAME = 'Innodb_os_log_written';")
        if [ $? -eq 0 ]; then
		if [ -n "${INNODB_LOG_WRITE_1}" ]; then
	                echo "Innodb_os_log_written = ${INNODB_LOG_WRITE_1}"
		else
			echo "Innodb_os_log_written = NULL"
			exit 1
		fi
        else
                echo "Error: ${INNODB_LOG_WRITE_1}"
                exit
        fi
        echo "Sleeping 3600 second..."
        sleep 3600;
        INNODB_LOG_WRITE_2=$(_mysql_exec_one_query "SELECT VARIABLE_VALUE FROM ${MYSQL_SETTINGS_SCHEMA}.global_status WHERE VARIABLE_NAME = 'Innodb_os_log_written';")
        if [ $? -eq 0 ]; then
		if [ -n "${INNODB_LOG_WRITE_2}" ]; then
	                echo "Innodb_os_log_written = ${INNODB_LOG_WRITE_2}"
		else
			echo "Innodb_os_log_written = NULL"
		fi
        else
                echo "Error: ${INNODB_LOG_WRITE_2}"
                exit
        fi
        INNODB_LOG_WRITE_BYTE_PER_HOUR=$(echo "${INNODB_LOG_WRITE_2}-${INNODB_LOG_WRITE_1}" | bc)
        INNODB_LOG_WRITE_MB_PER_HOUR=$(echo "scale=1;${INNODB_LOG_WRITE_BYTE_PER_HOUR}/1048576" | bc)
        echo "Write speed (MB_per_1_hour): ${INNODB_LOG_WRITE_MB_PER_HOUR}"
	echo "================================================"
        if [ ${INNODB_LOG_WRITE_BYTE_PER_HOUR} -gt ${INNODB_TOTAL_LOG_SIZE} ]; then
                echo "Note: Current redo-log write speed > innodb_log_file_size*innodb_log_files_in_group"
                INNODB_LOG_WRITE_BYTE_PER_HOUR_10PRC=$(echo "(${INNODB_LOG_WRITE_BYTE_PER_HOUR}*1.2)/${INNODB_LOG_FILES_IN_GROUP}" | bc)
                if [ ${INNODB_LOG_WRITE_BYTE_PER_HOUR_10PRC} -gt 1048576 ]; then
                        INNODB_LOG_FILE_SIZE_RECOMEND=$(echo "${INNODB_LOG_WRITE_BYTE_PER_HOUR_10PRC}/1048576" | bc)
                        echo "Recomended set parameter innodb_log_file_size = ${INNODB_LOG_FILE_SIZE_RECOMEND}M"
                else
                        echo "Recomended set parameter innodb_log_file_size = ${INNODB_LOG_WRITE_BYTE_PER_HOUR_10PRC}"
                fi
        else
                echo "innodb_log_file_size is optimal configured, don't change it."
        fi
        echo "================================================"
else
        echo "ERROR: Command 'bc' not found, please install apt-get install bc"
        exit 1
fi
