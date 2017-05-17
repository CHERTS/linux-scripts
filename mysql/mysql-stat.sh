#!/usr/bin/env bash

#
# Program: Simple MySQL database server statistics <mysql-stat.sh>
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
#  -- FreeBSD 10.3 using /usr/local/bin/bash
#  -- Debian 8.5 using /bin/bash
#
# Usage:
#  Refer to the usage() sub-routine, or invoke mysql-stat.sh
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
#  Simple MySQL database server statistics v1.0.0
#  Written by Mikhail Grigorev (sleuthhound@gmail.com, http://www.programs74.ru)
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
#

VERSION="1.0.0"
MYSQL=`which mysql`

echo "Simple MySQL database server statistics v$VERSION"
echo "Written by Mikhail Grigorev (sleuthhound@gmail.com, http://www.programs74.ru)"
echo ""

showHelp() {
	echo -e "\t--help -h\t\tthis menu"
	echo -e "\t--user username\t\tspecify mysql username to use, the script will prompt for a password during runtime, unless you supply a password"
	echo -e "\t--password \"yourpass\""
	echo -e "\t--host hostname\t\tspecify mysql hostname to use, be it local (default) or remote"
}

# Parse arguments
while [[ $1 == -* ]]; do
	case "$1" in
		--user)      mysqlUser="$2"; shift 2;;
		--password)  mysqlPass="$2"; shift 2;;
		--host)      mysqlHost="$2"; shift 2;;
		--help|-h)   showHelp; exit 0;;
		--*)         shift; break;;
	esac
done

if [[ ! ${log} ]]; then
	log="$PWD/mysql_stat.log"
fi
if [[ ! -f ${log} ]]; then
        touch "${log}"
fi

# prevent overwriting the commandline args with the ones in .my.cnf, and check that .my.cnf exists
if [[ ! ${mysqlUser}  && -f "$HOME/.my.cnf" ]]; then
	if grep "user=" "$HOME/.my.cnf" >/dev/null 2>&1; then
		if grep "password=" "$HOME/.my.cnf" >/dev/null 2>&1; then
			mysqlUser=$(grep -m 1 "user=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g');
			mysqlPass=$(grep -m 1 "password=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g');

			if grep "host=" "$HOME/.my.cnf" >/dev/null 2>&1; then
				mysqlHost=$(grep -m 1 "host=" "$HOME/.my.cnf" | sed -e 's/^[^=]\+=//g');
			fi
		else
			echo "Found no pass line in your .my.cnf,, fix this or specify with --password"
		fi
	else
		echo "Found no user line in your .my.cnf, fix this or specify with --user"
		exit 1;
	fi
fi

MYSQL="${MYSQL} -u${mysqlUser} -p${mysqlPass}"

# If set, add -h parameter to mysqlHost
if [[ ${mysqlHost} ]]; then
	MYSQL=${MYSQL}" -h${mysqlHost}"
fi

# Error out if no auth details are found for the user
if [[ ! ${mysqlUser} ]]; then
	echo "ERROR: Authentication information not found as arguments, nor in $HOME/.my.cnf"
	echo
	showHelp
	exit 1;
fi

# Test connecting to the database:
${MYSQL} --skip-column-names --batch -e "show status" >/dev/null 2>>"${log}"

if [[ $? -gt 0 ]]; then
	echo "ERROR: An error occured, check ${log} for more information.";
	exit 1;
fi

${MYSQL} -e "show variables; show status" | awk '
{
VAR[$1]=$2
}
END {
UPTIME = VAR["Uptime"]
MAX_CONN = VAR["max_connections"]
MAX_USED_CONN = VAR["Max_used_connections"]
BASE_MEM=VAR["key_buffer_size"] + VAR["query_cache_size"] + VAR["innodb_buffer_pool_size"] + VAR["innodb_additional_mem_pool_size"] + VAR["innodb_log_buffer_size"]
MEM_PER_CONN=VAR["read_buffer_size"] + VAR["read_rnd_buffer_size"] + VAR["sort_buffer_size"] + VAR["join_buffer_size"] + VAR["binlog_cache_size"] + VAR["thread_stack"]
MEM_TOTAL_MIN=BASE_MEM + MEM_PER_CONN*MAX_USED_CONN
MEM_TOTAL_MAX=BASE_MEM + MEM_PER_CONN*MAX_CONN
printf "+------------------------------------------+--------------------+\n"
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
}'

if [[ ! -s ${log} ]]; then
	rm -f "${log}"
fi
