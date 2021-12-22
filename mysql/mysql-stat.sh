#!/usr/bin/env bash

#
# Program: Simple MySQL database server statistics <mysql-stat.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
# 
# Current Version: 1.4
#
# Revision History:
#
#  Version 1.4
#    Fixed parsing user and password in .my.cnf file
#
#  Version 1.3
#    Added port option
#
#  Version 1.2
#    Fixed error division by zero attempted
#    Fixed creating log file
#    Added check mysql binary file
#
#  Version 1.1
#    Added analysis of query_cache
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
#  -- FreeBSD 10.3 using /usr/local/bin/bash
#  -- Debian 8.5 using /bin/bash
#  -- Ubuntu 14.04.1 using /bin/bash
#
# Usage:
#  Refer to the _usage() sub-routine, or invoke mysql-stat.sh
#  with the "-h" option.
#
# Example:
#
#  The first example will print the mysql stat:
#
#  $ ./mysql-stat.sh
#  or
#  $ ./mysql-stat.sh --user root --password XXXXXXX
#
#  Simple MySQL database server statistics v1.4
#  Written by Mikhail Grigorev (sleuthhound@gmail.com, https://blog.programs74.ru)
#  +------------------------------------------+--------------------+
#  |                                   Uptime |       226h:30m:38s |
#  +------------------------------------------+--------------------+
#  |                          key_buffer_size |         512.000 MB |
#  |                         query_cache_size |         256.000 MB |
#  |                  innodb_buffer_pool_size |        2048.000 MB |
#  |          innodb_additional_mem_pool_size |           8.000 MB |
#  |                   innodb_log_buffer_size |           4.000 MB |
#  +------------------------------------------+--------------------+
#  |                              BASE MEMORY |        2828.000 MB |
#  +------------------------------------------+--------------------+
#  |                         sort_buffer_size |           8.000 MB |
#  |                         read_buffer_size |           0.250 MB |
#  |                     read_rnd_buffer_size |          16.000 MB |
#  |                         join_buffer_size |          32.000 MB |
#  |                             thread_stack |           0.281 MB |
#  |                        binlog_cache_size |           0.031 MB |
#  +------------------------------------------+--------------------+
#  |                    MEMORY PER CONNECTION |          56.562 MB |
#  +------------------------------------------+--------------------+
#  |                  myisam_sort_buffer_size |           8.000 MB |
#  |                           tmp_table_size |        1024.000 MB |
#  +------------------------------------------+--------------------+
#  |                     Max_used_connections |                 26 |
#  |                          max_connections |                400 |
#  +------------------------------------------+--------------------+
#  |                              TOTAL (MIN) |        4298.625 MB |
#  |                              TOTAL (MAX) |       25453.000 MB |
#  +------------------------------------------+--------------------+
#  |                    QUERY_CACHE_USAGE (%) |              26.2% |
#  |                     QUERY_CACHE_FREE (%) |              73.8% |
#  |                 QUERY_CACHE_HIT_RATE (%) |              92.1% |
#  +------------------------------------------+--------------------+
#

VERSION="1.4"

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPT_NAME=$(basename "$0")

echo ""
echo "Simple MySQL database server statistics v$VERSION"
echo "Written by Mikhail Grigorev (sleuthhound@gmail.com, https://blog.programs74.ru)"
echo ""

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
	echo "** Trapped CTRL-C"
	exit 1
}

_command_exists() {
	type "$1" &> /dev/null
}

if _command_exists "mysql"; then
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
}

# Parse arguments
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

if [[ ! "${LOG_FILE}" ]]; then
	LOG_FILE="${SCRIPT_DIR}/mysql_stat.log"
fi

if [[ ! -f "${LOG_FILE}" ]]; then
        touch "${LOG_FILE}" >/dev/null 2>&1
fi

# Prevent overwriting the commandline args with the ones in .my.cnf, and check that .my.cnf exists
if [[ ! ${MYSQL_USER} && -f "$HOME/.my.cnf" ]]; then
        if egrep -E "host.*=" "$HOME/.my.cnf" >/dev/null 2>&1; then
                MYSQL_HOST=$(egrep -m 1 -E "host.*=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
        fi
        if egrep -E "port.*=" "$HOME/.my.cnf" >/dev/null 2>&1; then
                MYSQL_PORT=$(egrep -m 1 -E "port.*=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
        fi
        if egrep -E "user.*=" "$HOME/.my.cnf" >/dev/null 2>&1; then
                MYSQL_USER=$(egrep -m 1 -E "user.*=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
                if egrep -E "password.*=" "$HOME/.my.cnf" >/dev/null 2>&1; then
                        MYSQL_PASSWD=$(egrep -m 1 -E "password.*=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g' | sed 's/^[ \t]*//;s/[ \t]*$//');
                else
                        echo "Not found password line in your '$HOME/.my.cnf', fix this or specify with --password"
                fi
        else
                echo "Not found user line in your '$HOME/.my.cnf', fix this or specify with --user"
                exit 1;
        fi
fi

if [ -z "${MYSQL_USER}" ]; then
	MYSQL_USER="root"
fi

MYSQL="${MYSQL_BIN} -u${MYSQL_USER}"

# If set, add -h parameter to MYSQL_HOST
if [ -n "${MYSQL_HOST}" ]; then
	MYSQL=${MYSQL}" -h${MYSQL_HOST}"
fi

# If set, add -P parameter to MYSQL_PORT
if [ -n "${MYSQL_PORT}" ]; then
        MYSQL=${MYSQL}" -P${MYSQL_PORT}"
fi

if [ -n "${MYSQL_PASSWD}" ]; then
	export MYSQL_PWD="${MYSQL_PASSWD}"
else
	echo "Error: MySQL password for user '${MYSQL_USER}' is empty, please change password and create settings file '$HOME/.my.cnf'."
	echo
	_usage
	exit 1
fi

if [ -f "$HOME/.my.cnf" ]; then
        if ! `echo 'exit' | ${MYSQL_BIN} --defaults-file="$HOME/.my.cnf" -s >/dev/null 2>&1` ; then
                if ! `echo 'exit' | ${MYSQL} -s >/dev/null 2>&1` ; then
                        echo "Error[0]: Supplied mysql username or password appears to be incorrect."
                        exit
                fi
        else
                MYSQL="${MYSQL_BIN} --defaults-file=$HOME/.my.cnf"
        fi
fi

# Test connecting to the database:
${MYSQL} --skip-column-names --batch -e "SELECT 1;" >/dev/null 2>>"${LOG_FILE}"

if [ $? -ne 0 ]; then
	echo "ERROR: An error occured, check log file '${LOG_FILE}' for more information.";
	exit 1;
fi

${MYSQL} -e "show variables; show status" | awk '
{
VAR[$1]=$2
}
END {
split(VAR["version"],VERSION,"-")
UPTIME = VAR["Uptime"]
MAX_CONN = VAR["max_connections"]
MAX_USED_CONN = VAR["Max_used_connections"]
BASE_MEM=VAR["key_buffer_size"] + VAR["query_cache_size"] + VAR["innodb_buffer_pool_size"] + VAR["innodb_additional_mem_pool_size"] + VAR["innodb_log_buffer_size"]
MEM_PER_CONN=VAR["read_buffer_size"] + VAR["read_rnd_buffer_size"] + VAR["sort_buffer_size"] + VAR["join_buffer_size"] + VAR["binlog_cache_size"] + VAR["thread_stack"]
MEM_TOTAL_MIN=BASE_MEM + MEM_PER_CONN*MAX_USED_CONN
MEM_TOTAL_MAX=BASE_MEM + MEM_PER_CONN*MAX_CONN
if (VAR["query_cache_size"]) {
QUERY_CACHE_FREE=VAR["Qcache_free_memory"]*100/VAR["query_cache_size"]
QUERY_CACHE_USAGE=((VAR["query_cache_size"]-VAR["Qcache_free_memory"])/VAR["query_cache_size"])*100
QUERY_CACHE_HIT_RATE=((VAR["Qcache_hits"]/(VAR["Qcache_hits"]+VAR["Qcache_inserts"]+VAR["Qcache_not_cached"]))*100)
}
printf "+------------------------------------------+--------------------+\n"
printf "| %40s | %18s |\n", "Version", VERSION[1]
printf "| %40s | %9dh:%dm:%ds |\n", "Uptime", UPTIME/3600, UPTIME%3600/60, UPTIME%60
printf "+------------------------------------------+--------------------+\n"
printf "| %40s | %15.3f MB |\n", "key_buffer_size", VAR["key_buffer_size"]/1048576
printf "| %40s | %15.3f MB |\n", "query_cache_size", VAR["query_cache_size"]/1048576
printf "| %40s | %15.3f MB |\n", "innodb_buffer_pool_size", VAR["innodb_buffer_pool_size"]/1048576
printf "| %40s | %15.3f MB |\n", "innodb_additional_mem_pool_size", VAR["innodb_additional_mem_pool_size"]/1048576
printf "| %40s | %15.3f MB |\n", "innodb_log_buffer_size", VAR["innodb_log_buffer_size"]/1048576
printf "+------------------------------------------+--------------------+\n"
printf "| %40s | %15.3f MB |\n", "BASE MEMORY", BASE_MEM/1048576
printf "+------------------------------------------+--------------------+\n"
printf "| %40s | %15.3f MB |\n", "sort_buffer_size", VAR["sort_buffer_size"]/1048576
printf "| %40s | %15.3f MB |\n", "read_buffer_size", VAR["read_buffer_size"]/1048576
printf "| %40s | %15.3f MB |\n", "read_rnd_buffer_size", VAR["read_rnd_buffer_size"]/1048576
printf "| %40s | %15.3f MB |\n", "join_buffer_size", VAR["join_buffer_size"]/1048576
printf "| %40s | %15.3f MB |\n", "thread_stack", VAR["thread_stack"]/1048576
printf "| %40s | %15.3f MB |\n", "binlog_cache_size", VAR["binlog_cache_size"]/1048576
printf "+------------------------------------------+--------------------+\n"
printf "| %40s | %15.3f MB |\n", "MEMORY PER CONNECTION", MEM_PER_CONN/1048576
printf "+------------------------------------------+--------------------+\n"
printf "| %40s | %15.3f MB |\n", "myisam_sort_buffer_size", VAR["myisam_sort_buffer_size"]/1048576
printf "| %40s | %15.3f MB |\n", "tmp_table_size", VAR["tmp_table_size"]/1048576
printf "+------------------------------------------+--------------------+\n"
printf "| %40s | %18d |\n", "Max_used_connections", MAX_USED_CONN
printf "| %40s | %18d |\n", "max_connections", MAX_CONN
printf "+------------------------------------------+--------------------+\n"
printf "| %40s | %15.3f MB |\n", "TOTAL (MIN)", MEM_TOTAL_MIN/1048576
printf "| %40s | %15.3f MB |\n", "TOTAL (MAX)", MEM_TOTAL_MAX/1048576
printf "+------------------------------------------+--------------------+\n"
printf "| %40s | %17.1f% |\n", " QUERY_CACHE_USAGE (%)", QUERY_CACHE_USAGE
printf "| %40s | %17.1f% |\n", " QUERY_CACHE_FREE (%)", QUERY_CACHE_FREE
printf "| %40s | %17.1f% |\n", " QUERY_CACHE_HIT_RATE (%)", QUERY_CACHE_HIT_RATE
printf "+------------------------------------------+--------------------+\n"
}'

if [[ ! -s "${LOG_FILE}" ]]; then
	rm -f "${LOG_FILE}" >/dev/null 2>&1
fi
