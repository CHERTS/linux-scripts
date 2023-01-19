#!/usr/bin/env bash

#
# Program: Create partition and move date for Zabbix database <zabbix_create_partition_v2.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
# 
# Current Version: 1.0
#
# Revision History:
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
#  -- Debian 10 using /bin/bash
#  -- Ubuntu 18.04 using /bin/bash
#
# Usage:
#  Refer to the _usage() sub-routine, or invoke zabbix_create_partition_v2.sh
#  with the "-h" option.
#
# Example:
#
#  The first example:
#
#  $ ./zabbix_create_partition_v2.sh
#  or
#  $ ./zabbix_create_partition_v2.sh --user zabbix --password XXXXXXX --dbname zbxserver
#

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPT_NAME=$(basename "$0")

ZBX_LOG_FILE="${SCRIPT_DIR}/${SCRIPT_NAME%.*}.log"
ZBX_TABLE_LIST="history history_uint history_str history_log history_text trends trends_uint"
#ZBX_STATIC_MIN_CLOCK="2022-01-01"
ZBX_STATIC_MIN_CLOCK="$(date -d '- 30 day' '+%Y-%m-%d')"
ZBX_DROP_OLD_HISTORY_TABLE=0
ZBX_DELETE_OLD_HISTORY=1
ZBX_DELETE_OLD_HISTORY_ANY_CLOCK=1

if [ -f "${SCRIPT_DIR}/${SCRIPT_NAME%.*}.conf" ]; then
	source "${SCRIPT_DIR}/${SCRIPT_NAME%.*}.conf"
fi

function _logging() {
	local MSG=${1}
	printf "%s | %s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "$$" "${MSG}" 2>/dev/null
	tail -n 1 "${ZBX_LOG_FILE}" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		if [ -f "${ZBX_LOG_FILE}" ]; then
			mv "${ZBX_LOG_FILE}" "${LOG_FILE}.$(date '+%d%m%Y_%H%M%S')" >/dev/null 2>&1
		fi
	fi
	printf "%s | %s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "$$" "${MSG}" 1>>"${ZBX_LOG_FILE}" 2>&1
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
	_logging "Trapped CTRL-C and end script '${SCRIPT_DIR}/${SCRIPT_NAME}'. Goodbye ;)"
	exit 1
}

_command_exists() {
	type "$1" &> /dev/null
}

if _command_exists expr; then
	EXPR_BIN=$(which expr)
else
	echo "ERROR: Command 'expr' not found."
	exit 1
fi

if _command_exists mysql; then
	MYSQL_BIN=$(which mysql)
else
	echo "ERROR: Command 'mysql' not found."
	exit 1
fi

_usage() {
	echo -e "\t--help -h\t\tthis menu"
	echo -e "\t--user username\t\tspecify mysql username to use, the script will prompt for a password during runtime, unless you supply a password"
	echo -e "\t--password \"yourpass\""
	echo -e "\t--host hostname\t\tspecify mysql hostname to use, be it local (default) or remote"
	echo -e "\t--port port\t\tspecify mysql port number to use, be it 3306 (default)"
	echo -e "\t--dbname database\tspecify zabbix database name, be it zabbix (default)"
}

# Parse arguments
while [[ $1 == -* ]]; do
	case "$1" in
		--user)      MYSQLUSER="$2"; shift 2;;
		--password)  MYSQLPASS="$2"; shift 2;;
		--host)      MYSQLHOST="$2"; shift 2;;
		--port)      MYSQLPORT="$2"; shift 2;;
		--dbname)    MYSQLDB="$2"; shift 2;;
		--help|-h)   _usage; exit 0;;
		--*)         shift; break;;
	esac
done

_logging "Starting script '${SCRIPT_DIR}/${SCRIPT_NAME}'"

# Prevent overwriting the commandline args with the ones in .my.cnf, and check that .my.cnf exists
if [[ -z "${MYSQLUSER}" ]] && [[ -f "$HOME/.my.cnf" ]]; then
        if egrep -E "host.*=" "$HOME/.my.cnf" >/dev/null 2>&1; then
                MYSQLHOST=$(egrep -m 1 -E "host.*=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
        fi
        if egrep -E "port.*=" "$HOME/.my.cnf" >/dev/null 2>&1; then
                MYSQLPORT=$(egrep -m 1 -E "port.*=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
        fi
        if egrep -E "user.*=" "$HOME/.my.cnf" >/dev/null 2>&1; then
                MYSQLUSER=$(egrep -m 1 -E "user.*=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
                if egrep -E "password.*=" "$HOME/.my.cnf" >/dev/null 2>&1; then
                        MYSQLPASS=$(egrep -m 1 -E "password.*=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
                else
                        _logging "Not found password line in your '$HOME/.my.cnf', fix this or specify with --password"
                fi
        else
                _logging "Not found user line in your '$HOME/.my.cnf', fix this or specify with --user"
                exit 1;
        fi
fi

if [ -z "${MYSQLUSER}" ]; then
	MYSQLUSER="root"
fi

MYSQL="${MYSQL_BIN} -u${MYSQLUSER} -p${MYSQLPASS}"

# If set, add -h parameter to MYSQLHOST
if [[ -n "${MYSQLHOST}" ]]; then
	MYSQL=${MYSQL}" -h${MYSQLHOST}"
fi

# If set, add -p parameter to MYSQLHOST
if [[ -n "${MYSQLPORT}" ]]; then
	MYSQL=${MYSQL}" -P${MYSQLPORT}"
fi

if [[ -z "${MYSQLDB}" ]]; then
	MYSQLDB="zabbix"
fi

if [ -n "${MYSQLPASS}" ]; then
	export MYSQL_PWD="${MYSQLPASS}"
else
	_logging "ERROR[1]: MySQL password for user '${MYSQLUSER}' is empty, please change password and create settings file '$HOME/.my.cnf'."
	echo
	_usage
	exit 1
fi

if [ -f "$HOME/.my.cnf" ]; then
        if ! `echo 'exit' | ${MYSQL_BIN} --defaults-file="$HOME/.my.cnf" -s >/dev/null 2>&1` ; then
                if ! `echo 'exit' | ${MYSQL} "${MYSQLDB}" -s >/dev/null 2>&1` ; then
                        _logging "ERROR[2]: Supplied MySQL username or password appears to be incorrect."
                        exit
                fi
		MYSQL="${MYSQL} ${MYSQLDB}"
        else
                MYSQL="${MYSQL_BIN} --defaults-file=$HOME/.my.cnf ${MYSQLDB}"
        fi
else
	MYSQL="${MYSQL} ${MYSQLDB}"
fi

# Test connecting to the database
${MYSQL} --skip-column-names --batch -e "show status" >/dev/null 2>&1

if [ $? -eq 1 ]; then
	_logging "ERROR[3]: Failed test connection to MySQL."
	exit 1
fi

# Check zabbix database
ZBX_CONFIG=$(${MYSQL} --skip-column-names --batch -e "SELECT count(*) FROM config;" 2>/dev/null)

if [ -z "${ZBX_CONFIG}" ]; then
	_logging "ERROR[4]: The specified database '${MYSQLDB}' is not used for Zabbix"
	exit 1
fi

if [ ${ZBX_CONFIG} -eq 0 ]; then
	_logging "ERROR[5]: The specified database '${MYSQLDB}' is not used for Zabbix"
	exit 1
fi

function _end_exit()
{
	_logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'. Goodbye ;)"
	exit 1
}

function _run_create_parts()
{
	local TABLE_FILE_NAME=$1
	local TABLE_NAME=$2
	if [ -f "${TABLE_FILE_NAME}" ]; then
		_logging "Running create partition in table '${TABLE_NAME}' via file '${TABLE_FILE_NAME}', please wait..."
		${MYSQL} --batch --skip-column-names --execute="source ${TABLE_FILE_NAME};" 1>>"${ZBX_LOG_FILE}" 2>&1
		if [ $? -eq 0 ]; then
			PART_COUNT=$(${MYSQL} --batch --skip-column-names --execute="SELECT count(PARTITION_NAME) AS PARTITION_CNT FROM information_schema.partitions WHERE PARTITION_NAME IS NOT NULL AND TABLE_SCHEMA='${MYSQLDB}' AND TABLE_NAME='${TABLE_NAME}';" 2>/dev/null)
			_logging "Done, all partitions are created, found '${PART_COUNT}' partitions in table '${TABLE_NAME}'."
			rm -f "${TABLE_FILE_NAME}" 1>>"${ZBX_LOG_FILE}" 2>&1
		else
			_logging "ERROR[9]: Failed to create partitions in table ${TABLE_NAME}, see log file '${ZBX_LOG_FILE}' for more detail."
			_end_exit
		fi
	else
		_logging "ERROR[8]: SQL file '${TABLE_FILE_NAME}' not found."
		_end_exit
	fi
}

function _gen_alter_table()
{
	local TABLE_NAME=$1
	local START_DATE=$2
	local END_DATE=$3

	local TABLE_FILE_NAME="${TABLE_NAME}_parted.sql"

	_logging "Start creating alter table and save to file '${TABLE_FILE_NAME}', please wait..."
	_logging "Start date: ${START_DATE}"
	_logging "End date: ${END_DATE}"

	echo "ALTER TABLE \`${TABLE_NAME}\` PARTITION BY RANGE (clock)" > ${SCRIPT_DIR}/${TABLE_FILE_NAME}
	echo -n "(" >> ${SCRIPT_DIR}/${TABLE_FILE_NAME}

	local START_EPOCH=$(date +"%s" -d "${START_DATE}") || {
		_logging "Error processing start date ${START_DATE}"
		_end_exit
	}
	local END_EPOCH=$(date +"%s" -d "${END_DATE}") || {
		_logging "Error processing end date ${END_DATE}"
		_end_exit
	}
	if [ "${END_EPOCH}" -lt "${START_EPOCH}" ]; then
		_logging "End date ${END_DATE} is before start date ${START_DATE}"
		_end_exit
	fi
	local OK_SEQ=1
	local CURRENT_DATE="${START_DATE}"
	while [ "${OK_SEQ}" -ne 0 ]
 	do
		local EOD_EPOCH=$(date +"%s" -d "${CURRENT_DATE}") || {
			# This should never happen.
			_logging "Error processing end-of-day date ${CURRENT_DATE}"
			_end_exit
		}
		local PART_YEAR=$(echo ${CURRENT_DATE} | awk -F'-' '{print $1}')
		local PART_MON=$(echo ${CURRENT_DATE} | awk -F'-' '{print $2}')
		local PART_DAY=$(echo ${CURRENT_DATE} | awk -F'-' '{print $3}')
		if [ "${END_EPOCH}" -lt "${EOD_EPOCH}" ]; then
			if [ "${CURRENT_DATE}" != "${END_DATE}" ]; then
				# Sanity check -- this should not happen.
				local NEXT_DAY=$(date +"%Y-%m-%d" -d "${CURRENT_DATE} next day") || {
					# This shouldn’t happen.
					_logging "Error getting next day after ${CURRENT_DATE}"
					_end_exit
				}
				local PART_NEXT_YEAR=$(echo ${NEXT_DAY} | awk -F'-' '{print $1}')
				local PART_NEXT_MON=$(echo ${NEXT_DAY} | awk -F'-' '{print $2}')
				local PART_NEXT_DAY=$(echo ${NEXT_DAY} | awk -F'-' '{print $3}')
				echo "PARTITION p${PART_YEAR}${PART_MON}${PART_DAY}0000 VALUES LESS THAN (UNIX_TIMESTAMP(\"${PART_NEXT_YEAR}-${PART_NEXT_MON}-${PART_NEXT_DAY} 00:00:00\")) ENGINE = InnoDB);"  >> ${SCRIPT_DIR}/${TABLE_FILE_NAME}
				_logging "We're finishing, file '${SCRIPT_DIR}/${TABLE_FILE_NAME}' created."
				break
			fi
			OK_SEQ=0
		fi
		CURRENT_DATE=$(date +"%Y-%m-%d" -d "${CURRENT_DATE} next day") || {
			# This shouldn’t happen.
			_logging "Error getting next day after ${CURRENT_DATE}"
			_end_exit
		}
		local PART_NEXT_YEAR=$(echo ${CURRENT_DATE} | awk -F'-' '{print $1}')
		local PART_NEXT_MON=$(echo ${CURRENT_DATE} | awk -F'-' '{print $2}')
		local PART_NEXT_DAY=$(echo ${CURRENT_DATE} | awk -F'-' '{print $3}')
		echo "PARTITION p${PART_YEAR}${PART_MON}${PART_DAY}0000 VALUES LESS THAN (UNIX_TIMESTAMP(\"${PART_NEXT_YEAR}-${PART_NEXT_MON}-${PART_NEXT_DAY} 00:00:00\")) ENGINE = InnoDB,"  >> ${SCRIPT_DIR}/${TABLE_FILE_NAME}
	done
}

function _prepare_table()                                                                                                                                         
{
	local TABLE_NAME=$1
	_logging "Create table '${TABLE_NAME}_tmp'..."
	${MYSQL} --batch --skip-column-names --execute="CREATE TABLE ${TABLE_NAME}_tmp LIKE ${TABLE_NAME};" 1>>"${ZBX_LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, table '${TABLE_NAME}_tmp' created."
	else
		_logging "ERROR[6]: Failed to create table '${TABLE_NAME}_tmp'."
		_end_exit
	fi
	local CURRENT_DATE=$(date -d "+ 1 day" "+%Y-%m-%d")
	_logging "Set static min clock from table '${TABLE_NAME}' is ${ZBX_STATIC_MIN_CLOCK}"
	_gen_alter_table "${TABLE_NAME}_tmp" "${ZBX_STATIC_MIN_CLOCK}" "${CURRENT_DATE}"
	_run_create_parts "${SCRIPT_DIR}/${TABLE_NAME}_tmp_parted.sql" "${TABLE_NAME}_tmp"
	_logging "Rename original table '${TABLE_NAME}' to '${TABLE_NAME}_old' and rename '${TABLE_NAME}_tmp' to '${TABLE_NAME}'..."
	${MYSQL} --batch --skip-column-names --execute="RENAME TABLE ${TABLE_NAME} TO ${TABLE_NAME}_old, ${TABLE_NAME}_tmp TO ${TABLE_NAME};" 1>>"${ZBX_LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, all table renamed."
	else
		_logging "ERROR[7]: Failed to rename table, see log file '${ZBX_LOG_FILE}' for more detail."
		_end_exit
	fi
}

function _copy_data() {
	local ZBX_TABLE=$1
	local ZBX_ITEM=$2
	local ZBX_MIN_CLOCK=$3
	_logging "Copy items '${ZBX_ITEM}' and clock '>${ZBX_MIN_CLOCK}' from table '${ZBX_TABLE}_old' to '${ZBX_TABLE}', please wait..."
	local ZBX_ITEM_HISTORY_COUNT=$(${MYSQL} --batch --skip-column-names --execute="SELECT count(1) FROM ${ZBX_TABLE}_old WHERE itemid=${ZBX_ITEM} AND clock>${ZBX_MIN_CLOCK};" 2>/dev/null)
	if [ ${ZBX_ITEM_HISTORY_COUNT} -eq 0 ]; then
		_logging "Found '${ZBX_ITEM_HISTORY_COUNT}' history record, skip copy."
		return
	fi
	_logging "Found '${ZBX_ITEM_HISTORY_COUNT}' history record, starting copy, please wait..."
	${MYSQL} --batch --skip-column-names --execute="INSERT IGNORE INTO ${ZBX_TABLE} SELECT * FROM ${ZBX_TABLE}_old WHERE itemid=${ZBX_ITEM} AND clock>${ZBX_MIN_CLOCK};" 1>>"${ZBX_LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, all data copyed."
	else
		_logging "ERROR[8]: Failed to copy data, see log file '${ZBX_LOG_FILE}' for more detail."
	fi
}

function _delete_data() {
	local ZBX_TABLE=$1
	local ZBX_ITEM=$2
	local ZBX_MIN_CLOCK=$3
	if [ ${ZBX_DELETE_OLD_HISTORY_ANY_CLOCK} -eq 1 ]; then
		_logging "Delete items '${ZBX_ITEM}' and any clock from table '${ZBX_TABLE}_old', please wait..."
		${MYSQL} --batch --skip-column-names --execute="DELETE FROM ${ZBX_TABLE}_old WHERE itemid=${ZBX_ITEM};" 1>>"${ZBX_LOG_FILE}" 2>&1
	else
		_logging "Delete items '${ZBX_ITEM}' and clock '>${ZBX_MIN_CLOCK}' from table '${ZBX_TABLE}_old', please wait..."
		${MYSQL} --batch --skip-column-names --execute="DELETE FROM ${ZBX_TABLE}_old WHERE itemid=${ZBX_ITEM} AND clock>${ZBX_MIN_CLOCK};" 1>>"${ZBX_LOG_FILE}" 2>&1
	fi
	if [ $? -eq 0 ]; then
		_logging "Done, item data deleted."
	else
		_logging "ERROR[9]: Failed to delete data, see log file '${ZBX_LOG_FILE}' for more detail."
	fi
}

function _copy_history_data() {
	local TABLE_NAME=$1
	# 0 - float, 1 - str, 2 - log, 3 - uint, 4 - text
	case "${TABLE_NAME}" in
    		history)
        		ZBX_ITEMS_TYPE=0
        		;;
    		history_str)
        		ZBX_ITEMS_TYPE=1
        		;;
    		history_log)
        		ZBX_ITEMS_TYPE=2
        		;;
    		history_uint)
        		ZBX_ITEMS_TYPE=3
        		;;
    		history_text)
        		ZBX_ITEMS_TYPE=4
        		;;
		trends)
			ZBX_ITEMS_TYPE=0
			;;
		trends_uint)
			ZBX_ITEMS_TYPE=3
			;;
    		*)
        		_logging "Unknow history table name. Exiting."
        		_end_exit
        	;;
    	esac
	_logging "Getting items count where type '${ZBX_ITEMS_TYPE}', please wait..."
	local ZBX_ITEMS_COUNT=$(${MYSQL} --batch --skip-column-names --execute="SELECT count(1) FROM items i JOIN hosts h ON h.hostid=i.hostid WHERE h.status IN (0,1) AND i.value_type=${ZBX_ITEMS_TYPE} AND h.templateid IS NULL;" 2>/dev/null)
	_logging "Found '${ZBX_ITEMS_COUNT}' items."
	_logging "Getting items list where type '${ZBX_ITEMS_TYPE}', please wait..."
	ZBX_ITEMS_LIST=$(${MYSQL} --batch --skip-column-names --execute="SELECT i.itemid FROM items i JOIN hosts h ON h.hostid=i.hostid WHERE h.status IN (0,1) AND i.value_type=${ZBX_ITEMS_TYPE} AND h.templateid IS NULL;" 2>/dev/null)
	ZBX_MIN_CLOCK=$(date +"%s" -d "${ZBX_STATIC_MIN_CLOCK}") || {
		_logging "Error processing min date ${ZBX_STATIC_MIN_CLOCK}"
		_end_exit
	}
	_logging "Set static min clock for all items: '${ZBX_STATIC_MIN_CLOCK}' (unixtime: '${ZBX_MIN_CLOCK}')"
	for ZBX_ITEM in ${ZBX_ITEMS_LIST}
	do
		_copy_data "${TABLE_NAME}" "${ZBX_ITEM}" "${ZBX_MIN_CLOCK}"
		if [ ${ZBX_DELETE_OLD_HISTORY} -eq 1 ]; then
			_delete_data "${TABLE_NAME}" "${ZBX_ITEM}" "${ZBX_MIN_CLOCK}"
		fi
	done
}

function _drop_table() {
	local TABLE_NAME=$1
    ${MYSQL} --batch --skip-column-names --execute="DROP TABLE IF EXISTS '${TABLE_NAME}_old';" 1>>"${ZBX_LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        _logging "Done, table '${TABLE_NAME}_old' droped."
    else
        _logging "ERROR[7]: Failed to drop table '${TABLE_NAME}_old', see log file '${ZBX_LOG_FILE}' for more detail."
        _end_exit
    fi
}

_logging "Now connected to database '${MYSQLDB}'"

for ZBX_TABLE_NAME in ${ZBX_TABLE_LIST}
do
	TABLE_PARTITION_COUNT=$(${MYSQL} --batch --skip-column-names --execute="SELECT count(PARTITION_NAME) AS PARTITION_CNT FROM information_schema.partitions WHERE PARTITION_NAME IS NOT NULL AND TABLE_SCHEMA='${MYSQLDB}' AND TABLE_NAME='${ZBX_TABLE_NAME}';" 2>/dev/null)
	if [ ${TABLE_PARTITION_COUNT} -eq 0 ]; then
		_logging "Start partitioning table '${ZBX_TABLE_NAME}'..."
		_prepare_table "${ZBX_TABLE_NAME}"
		_copy_history_data "${ZBX_TABLE_NAME}"
		if [ ${ZBX_DROP_OLD_HISTORY_TABLE} -eq 1 ]; then
			_drop_table "${ZBX_TABLE_NAME}"
		fi
	else
		_logging "WARNING: Table '${ZBX_TABLE_NAME}' is already partitioned, it will be skipped..."
		continue
	fi
done

_logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'. Goodbye ;)"
