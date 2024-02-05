#!/usr/bin/env bash

#
# Program: Percona xtrabackup reciver <xtrabackup_reciver.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
# 
# Current Version: 1.0.4
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

# Run auto installing needed packeges (percona, socat and etc)
AUTO_INSTALL_NEED_PKG=0
# Version of Percona Xtrabackup (24 or 80)
PERCONA_XTRABACKUP_VER=24
# Full restore backup (prepare and move), old mysql data delete!
FULL_RESTORE_BACKUP=0
# Stop MySQL before recive backup
STOP_MYSQL_BEFORE=0
# Delete MySQL data before recive backup
DELETE_MYSQL_DATA_BEFORE=0
# Xtrabackup prepare data options, see https://www.percona.com/doc/percona-xtrabackup/2.4/xtrabackup_bin/xbk_option_reference.html
XTRABACKUP_PREPARE_OPTS="--use-memory=100M"
# Mariabackup prepare data options
MARIABACKUP_PREPARE_OPTS="--use-memory=100M"
# Xtrabackup info file
XTRABACKUP_INFO_FILE="xtrabackup_info"
# Xtrabackup binlog info file
XTRABACKUP_BINLOG_INFO_FILE="xtrabackup_binlog_info"
# Run replication
RUN_REPLICATION=0
# Default MySQL datadir
MYSQL_DATA_DIR=/var/lib/mysql
# Default MySQL binary log dir
MYSQL_BINLOG_DIR=/var/lib/mysql-bin
# MySQL cmd options (-u root -pXXXX and etc)
MYSQL_OPTS=""
# MySQL master host
MYSQL_MASTER_HOST="mysql01.mysite.ru"
# MySQL master host port
MYSQL_MASTER_HOST_PORT="3306"
# MySQL replication user
MYSQL_MASTER_USER="replica"
# MySQL replication user password
MYSQL_MASTER_USER_PASSWORD="XXXXX"
# MySQL use autoposition
MYSQL_USE_AUTO_POSITION=1
# MySQL master log file name
MYSQL_MASTER_LOG_FILE=""
# MySQL log position
MYSQL_MASTER_LOG_POS=""
# MySQL use chanel name (master1)
MYSQL_CHANNEL_NAME=""
# MySQL other change master options
MYSQL_OTHER_CHANGE_MASTER_OPTS=""

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
	echo "** Trapped CTRL-C"
	exit 1
}

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPT_NAME=$(basename "$0")

SENDER_MAGIC_TAG="MGPING" # !!!DONT EDIT!!!
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
	echo "Usage: $0 [ -m <BACKUP_METHOD> -p <LISTEN_PORT> -d <BACKUP_DIR>]"
	echo ""
	echo "  -m BACKUP_METHOD	: (Required) Backup method (percona or maria)"
	echo ""
	echo "  -d BACKUP_DIR		: (Required) Backup directory."
	echo ""
	echo "  -p LISTEN_PORT	: (Optional) Listen port (default: 9999)"
	echo ""
	echo "  -s STREAM_PROGRAM	: (Optional) Stream program (socat, nc or ncat) (default: nc)"
	echo ""
	echo "  -h			: Print this screen"
	echo ""
	exit 0
}

[ $# -eq 0 ] && _usage

while getopts ":hm:d:p:s:" option; do
	case "${option}" in
		m)
			BACKUP_METHOD=${OPTARG}
			;;
		d)
			MYSQL_BACKUP_DIR=${OPTARG}
			;;
		p)
			LISTEN_PORT=${OPTARG}
			;;
		s)
			USE_STREAM_PROGRAM=${OPTARG}
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

if [ -z "${MYSQL_BACKUP_DIR}" ]; then
	echo "No options -d <BACKUP_DIR> found!"
	_usage
fi

_logging "Starting script '${SCRIPT_DIR}/${SCRIPT_NAME}'"

if _command_exists mysql ; then
	MYSQL_BIN=$(which mysql)
else
	_fail "ERROR: Command 'mysql' not found."
fi

case "${BACKUP_METHOD}" in
	percona)
		_logging "Select Percona XtraBackup"
	;;
	maria)
		_logging "Select MariaDB Backup"
	;;
	*)
		_usage
	;;
esac

if [ -z "${LISTEN_PORT}" ]; then
	LISTEN_PORT=9999
fi

if [ -z "${USE_STREAM_PROGRAM}" ]; then
	USE_STREAM_PROGRAM="nc"
fi

if [ -f "${SCRIPT_DIR}/xtrabackup_reciver.conf" ]; then
	source "${SCRIPT_DIR}/xtrabackup_reciver.conf"
fi

_unknown_os() {
	echo
	echo "Unfortunately, your operating system distribution and version are not supported by this script."
	echo
	echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
	exit 1
}

_unknown_distrib() {
	echo
	echo "Unfortunately, your Linux distribution or distribution version are not supported by this script."
	echo
	echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
	exit 1
}

_detect_linux_distrib() {
	local DIST=$1
	local REV=$2
	local PSUEDONAME=$3
	case "${DIST}" in
		Ubuntu)
			_logging "Detecting your Linux distrib: ${DIST} ${REV}"
			case "${REV}" in
				14.04|16.04|17.10|18.04|18.10|19.04|19.10|20.04|20.10)
					_logging "Found Ubuntu distrib: ${PSUEDONAME}"
					;;
				*)
					_unknown_distrib
					;;
			esac
			;;
		Debian)
			_logging "Detecting your Linux distrib: ${DIST} ${REV}"
			case "${REV}" in
				8|9|10|11)
					_logging "Found Debian distrib: ${PSUEDONAME}"
					;;
				*)
					_unknown_distrib
					;;
			esac
			;;
		"Red Hat"*)
			_logging "Detecting your Linux distrib: ${DIST} ${REV} (${PSUEDONAME})"
			;;
		CentOS)
			_logging "Detecting your Linux distrib: ${DIST} ${REV} (${PSUEDONAME})"
			;;
		*)
			_logging "Detecting your Linux distrib: Unsupported (${DIST} | ${REV} | ${PSUEDONAME})"
			_unknown_distrib
			;;
	esac
}

OS=$(uname -s)
OS_ARCH=$(uname -m)
case "${OS}" in
	Linux*)
		_logging "Detecting your OS: Linux (${OS_ARCH})"
		PLATFORM="linux"
		DISTROBASEDON="Unknown"
		DIST="Unknown"
		PSUEDONAME="Unknown"
		REV="Unknown"
		if [ -f "/etc/redhat-release" ]; then
			DISTROBASEDON="RedHat"
			DIST=$(cat /etc/redhat-release | sed s/\ release.*//)
			PSUEDONAME=$(cat /etc/redhat-release | sed s/.*\(// | sed s/\)//)
			REV=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//)
		elif [ -f "/etc/SuSE-release" ]; then
			DISTROBASEDON="SUSE"
			DIST="SuSE"
			PSUEDONAME=$(cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//)
			REV=$(cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //)
		elif [ -f "/etc/mandrake-release" ]; then
			DISTROBASEDON="Mandrake"
			DIST="Mandrake"
			PSUEDONAME=$(cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//)
			REV=$(cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//)
		elif [ -f "/etc/debian_version" ]; then
			if [ -f "/etc/lsb-release" ]; then
				DISTROBASEDON="Debian"
				DIST=$(cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }')
				PSUEDONAME=$(cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }')
				REV=$(cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }')
			elif [ -f "/etc/os-release" ]; then
				DISTROBASEDON="Debian"
				DIST=$(cat /etc/os-release | grep '^NAME' | awk -F=  '{ print $2 }' | grep -oP '(?<=\")(\w+)(?=\ )')
				PSUEDONAME=$(cat /etc/os-release | grep '^VERSION=' | awk -F= '{ print $2 }' | grep -oP '(?<=\()(\w+)(?=\))')
				REV=$(sed 's/\..*//' /etc/debian_version)
			fi
		fi
		_detect_linux_distrib "${DIST}" "${REV}" "${PSUEDONAME}"
		;;
	*)
		_logging "Detecting your OS: Unknown"
		_unknown_os
		;;
esac

CURRENT_USER=$(whoami)
_logging "Checking your privileges..."
if [[ "${CURRENT_USER}" = "root" ]]; then
	_logging "Good, script running from root."
else
	_fail "ERROR: root access is required."
fi

_install_debian_keyring () {
	if [[ "${DIST}" = "Debian" ]]; then
		_logging "Installing debian-archive-keyring which is needed for installing apt-transport-https on many Debian systems..."
		apt-get install -y debian-archive-keyring &> /dev/null
		EXIT_CODE=$?
		if [ ${EXIT_CODE} -eq 0 ]; then
			_logging "Done, debian-archive-keyring installed."
		else
			_fail "Error apt-get install debian-archive-keyring"
		fi
	fi
	_logging "Installing apt-transport-https..."
	apt-get install -y apt-transport-https &> /dev/null
	EXIT_CODE=$?
	if [ ${EXIT_CODE} -eq 0 ]; then
		_logging "Done, apt-transport-https installed."
	else
		_fail "Error apt-get install apt-transport-https"
	fi
}

_install_packages() {
	local PKG_NAME=$1
	local EXIT_CODE=1
	_logging "Installing dependent packages..."
	case "${DIST}" in
		Ubuntu|Debian)
			apt-get update -qq
			EXIT_CODE=$?
			if [ ${EXIT_CODE} -eq 0 ]; then
				apt-get install -y "${PKG_NAME}" >/dev/null 2>&1
				EXIT_CODE=$?
				if [ ${EXIT_CODE} -eq 0 ]; then
					_logging "Done, ${PKG_NAME} installed."
				else
					_fail "Error apt-get install ${PKG_NAME}"
				fi
			else
				_fail "Error apt-get update"
			fi
			;;
		CentOS|"Red Hat"*)
			yum install -y "${PKG_NAME}" >/dev/null 2>&1
			EXIT_CODE=$?
			if [ ${EXIT_CODE} -eq 0 ]; then
				_logging "Done, ${PKG_NAME} installed."
			else
				_fail "Error yum install ${PKG_NAME}"
			fi
			;;
		*)
			_fail "Unsupported Linux distributive."
			;;
	esac
}

if _command_exists wget ; then
	WGET_BIN=$(which wget)
else
	if [ ${AUTO_INSTALL_NEED_PKG} -eq 1 ]; then
		_logging "WARNING: Command 'wget' not found."
		_install_packages "wget"
	else
		_fail "ERROR: Command 'wget' not found."
	fi
fi

_install_percona_packages() {
	local PKG_NAME=$1
	local EXIT_CODE=1
	_logging "Installing ${PKG_NAME}..."
	case "${DIST}" in
		Ubuntu|Debian)
			wget "https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb" -O "/tmp/percona-release_latest.$(lsb_release -sc)_all.deb" >/dev/null 2>&1
			EXIT_CODE=$?
			if [ ${EXIT_CODE} -eq 0 ]; then
				if [ -f "/tmp/percona-release_latest.$(lsb_release -sc)_all.deb" ]; then
					dpkg -i "/tmp/percona-release_latest.$(lsb_release -sc)_all.deb" >/dev/null 2>&1
					EXIT_CODE=$?
					if [ ${EXIT_CODE} -eq 0 ]; then
						percona-release enable-only tools release >/dev/null 2>&1
						EXIT_CODE=$?
						if [ ${EXIT_CODE} -eq 0 ]; then
							apt-get install -y "${PKG_NAME}" >/dev/null 2>&1
							EXIT_CODE=$?
							if [ ${EXIT_CODE} -eq 0 ]; then
								_logging "Done, ${PKG_NAME} installed."
							else
								_fail "Error installing package '${PKG_NAME}'"
							fi
						else
							_fail "Error enabling percona repo tools and release."
						fi
					else
						_fail "Error installing 'percona-release_latest.$(lsb_release -sc)_all.deb'"
					fi
					rm -f "/tmp/percona-release_latest.$(lsb_release -sc)_all.deb" >/dev/null 2>&1
				fi
			else
				_fail "Error downloading 'percona-release_latest.$(lsb_release -sc)_all.deb', please check your internet connection."
			fi
			;;
		CentOS|"Red Hat"*)
			yum install "https://repo.percona.com/yum/percona-release-latest.noarch.rpm" >/dev/null 2>&1
			EXIT_CODE=$?
			if [ ${EXIT_CODE} -eq 0 ]; then
				percona-release enable-only tools release >/dev/null 2>&1
				EXIT_CODE=$?
				if [ ${EXIT_CODE} -eq 0 ]; then
					yum install -y "${PKG_NAME}" >/dev/null 2>&1
					EXIT_CODE=$?
					if [ ${EXIT_CODE} -eq 0 ]; then
						_logging "Done, ${PKG_NAME} installed."
					else
						_fail "Error installing package '${PKG_NAME}'"
					fi
				else
					_fail "Error enabling percona repo tools and release."
				fi
			else
				_fail "Error installing 'percona-release-latest.noarch.rpm', please check your internet connection."
			fi
			;;
		*)
			_fail "Unsupported Linux distributive."
			;;
	esac
}

if _command_exists socat ; then
	SOCAT_BIN=$(which socat)
else
	if [ ${AUTO_INSTALL_NEED_PKG} -eq 1 ]; then
		_logging "WARNING: Command 'socat' not found."
		_install_percona_packages "socat"
	else
		_fail "ERROR: Command 'socat' not found."
		exit 1
	fi
fi

case "${USE_STREAM_PROGRAM}" in
	socat)
		if _command_exists socat ; then
			STREAM_PROGRAM=$(which socat)
			STREAM_PROGRAM_OPTS="-u tcp-listen:${LISTEN_PORT},reuseaddr stdout 2>${LOG_FILE}"
		fi
		;;
	nc)
		if _command_exists nc ; then
			STREAM_PROGRAM=$(which nc)
			STREAM_PROGRAM_OPTS="-l ${LISTEN_PORT}"
		else
			_fail "ERROR: Command 'nc' not found."
		fi
		;;
	ncat)
		if _command_exists ncat ; then
			STREAM_PROGRAM=$(which ncat)
			STREAM_PROGRAM_OPTS="-l ${LISTEN_PORT}"
		else
			_fail "ERROR: Command 'ncat' not found."
		fi
		;;
	*)
		_fail "ERROR: Unrecognize '-s' options."
		;;
esac

if [[ "${BACKUP_METHOD}" = "percona" ]]; then
	if _command_exists xbstream ; then
		STREAM_BIN=$(which xbstream)
	else
		if [ ${AUTO_INSTALL_NEED_PKG} -eq 1 ]; then
			_logging "WARNING: Command 'xbstream' not found."
			_install_percona_packages "percona-xtrabackup-${PERCONA_XTRABACKUP_VER}"
		else
			_fail "ERROR: Command 'xbstream' not found."
		fi
	fi
fi

if [[ "${BACKUP_METHOD}" = "maria" ]]; then
	if _command_exists mbstream ; then
		STREAM_BIN=$(which mbstream)
	else
		_fail "ERROR: Command 'mbstream' not found."
	fi
fi

if [ ! -d "${MYSQL_BACKUP_DIR}" ]; then
	_fail "Error, main backup directory '${MYSQL_BACKUP_DIR}' not found, please create manual."
else
	DATE_TIME=$(date "+%d%m%Y_%H%M%S")
	MYSQL_FULL_BACKUP_DIR="${MYSQL_BACKUP_DIR}/${DATE_TIME}"
	if [ ! -d "${MYSQL_FULL_BACKUP_DIR}" ]; then
		_logging "Creating temporary backup directory '${MYSQL_FULL_BACKUP_DIR}'..."
		mkdir "${MYSQL_FULL_BACKUP_DIR}" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			_logging "Done, temporary backup directory has created."
		else
			_fail "Error, temporary backup directory not created."
		fi
	fi
fi

_stop_mysql() {
	_logging "Stopping MySQL, please wait..."
	systemctl stop mysql 1>>"${LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, MySQL stopped."
	else
		_fail "Error, MySQL not stopped."
	fi
}

_start_mysql() {
	_logging "Starting MySQL, please wait..."
	systemctl start mysql 1>>"${LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, MySQL started."
	else
		_fail "Error, MySQL not started."
	fi
}

_delete_mysql_data() {
	if [ -n "${MYSQL_BINLOG_DIR}" ]; then
		if [ -d "${MYSQL_BINLOG_DIR}" ]; then
			_logging "Delete MySQL binary log directory, please wait..."
			rm -rf "${MYSQL_BINLOG_DIR}" >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				_logging "Done, MySQL binary log directory deleted."
			else
				_fail "Error, MySQL binary log directory not deleted."
			fi
		else
			_logging "Warning, MySQL binary log directory not found."
		fi
		if [ ! -d "${MYSQL_BINLOG_DIR}" ]; then
			_logging "Creating MySQL binary log directory, set owner..."
			mkdir "${MYSQL_BINLOG_DIR}" >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				_logging "Done, MySQL binary log directory has created."
			else
				_fail "Error, MySQL binary log directory not created."
			fi
			_logging "Set MySQL binary log directory owner..."
			chown mysql:mysql "${MYSQL_BINLOG_DIR}" >/dev/null 2>&1
			chmod 750 "${MYSQL_BINLOG_DIR}" >/dev/null 2>&1
		fi
	fi
	if [ -d "${MYSQL_DATA_DIR}" ]; then
		_logging "Delete MySQL data directory, please wait..."
		rm -rf "${MYSQL_DATA_DIR}" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			_logging "Done, MySQL data directory deleted."
		else
			_fail "Error, MySQL data directory not deleted."
		fi
	else
		_fail "Error, MySQL data directory not found."
	fi
	if [ ! -d "${MYSQL_DATA_DIR}" ]; then
		_logging "Creating MySQL data directory..."
		mkdir "${MYSQL_DATA_DIR}" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			_logging "Done, MySQL data directory has created."
		else
			_fail "Error, MySQL data directory not created."
		fi
		_logging "Set MySQL data directory owner..."
		chown mysql:mysql "${MYSQL_DATA_DIR}" >/dev/null 2>&1
		chmod 750 "${MYSQL_DATA_DIR}" >/dev/null 2>&1
	fi
}

_run_full_restore() {
	local MYSQL_FULL_BACKUP_DIR=$1
	if [[ "${BACKUP_METHOD}" = "percona" ]]; then
		_logging "Running xtrabackup prepare, please wait..."
		if [ -n "${XTRABACKUP_PREPARE_OPTS}" ]; then
			xtrabackup --prepare ${XTRABACKUP_PREPARE_OPTS} --target-dir=${MYSQL_FULL_BACKUP_DIR} 1>>"${LOG_FILE}" 2>&1
			EXIT_CODE=$?
		else
			xtrabackup --prepare --target-dir=${MYSQL_FULL_BACKUP_DIR} 1>>"${LOG_FILE}" 2>&1
			EXIT_CODE=$?
		fi
	fi
	if [[ "${BACKUP_METHOD}" = "maria" ]]; then
		_logging "Running mariabackup prepare, please wait... "
		if [ -n "${MARIABACKUP_PREPARE_OPTS}" ]; then
			mariabackup --prepare ${MARIABACKUP_PREPARE_OPTS} --target-dir=${MYSQL_FULL_BACKUP_DIR} 1>>"${LOG_FILE}" 2>&1
			EXIT_CODE=$?
		else
			mariabackup --prepare --target-dir=${MYSQL_FULL_BACKUP_DIR} 1>>"${LOG_FILE}" 2>&1
			EXIT_CODE=$?
		fi
	fi
	if [ ${EXIT_CODE} -eq 0 ]; then
		_logging "Done, prepare complete."
	else
		_fail "Error, prepare not complete."
	fi
	if [ ${STOP_MYSQL_BEFORE} -eq 0 ]; then
		_stop_mysql
	fi
	if [ ${DELETE_MYSQL_DATA_BEFORE} -eq 0 ]; then
		_delete_mysql_data
	fi
	if [[ "${BACKUP_METHOD}" = "percona" ]]; then
		_logging "Running xtrabackup move-back, please wait..."
		xtrabackup --move-back --target-dir=${MYSQL_FULL_BACKUP_DIR} 1>>"${LOG_FILE}" 2>&1
		EXIT_CODE=$?
	fi
	if [[ "${BACKUP_METHOD}" = "maria" ]]; then
		_logging "Running mariabackup move-back, please wait..."
		mariabackup --move-back --target-dir=${MYSQL_FULL_BACKUP_DIR} 1>>"${LOG_FILE}" 2>&1
		EXIT_CODE=$?
	fi
	if [ ${EXIT_CODE} -eq 0 ]; then
		_logging "Done, move-back complete."
	else
		_fail "Error, move-back not complete."
	fi
	_logging "Set MySQL data directory owner..."
	chown -R mysql:mysql "${MYSQL_DATA_DIR}" >/dev/null 2>&1
	_logging "Set MySQL binary log directory owner..."
	chown -R mysql:mysql "${MYSQL_BINLOG_DIR}" >/dev/null 2>&1
	_start_mysql
	_logging "Delete backup directory, please wait..."
	rm -rf "${MYSQL_FULL_BACKUP_DIR}" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, backup directory deleted."
	else
		_fail "Error, backup directory not deleted."
	fi
}

_run_replica() {
	if [ -n "${MYSQL_OPTS}" ]; then
		MYSQL_BIN="${MYSQL_BIN} ${MYSQL_OPTS}"
	fi
	_logging "Reset master..."
	${MYSQL_BIN} -e "RESET MASTER;" 1>>"${LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, master data reset."
	else
		_fail "Error, master data not reset."
	fi
	_logging "Reset slave..."
	${MYSQL_BIN} -e "RESET SLAVE;" 1>>"${LOG_FILE}" 2>&1
	${MYSQL_BIN} -e "RESET SLAVE ALL;" 1>>"${LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, slave data reset."
	else
		_fail "Error, slave data not reset."
	fi
	MYSQL_REPLICA_OPTS=""
	if [ ${MYSQL_USE_AUTO_POSITION} -eq 1 ]; then
		if [ -f "${MYSQL_DATA_DIR}/${XTRABACKUP_INFO_FILE}" ]; then
			_logging "Set global gtid_purged..."
			cat "${MYSQL_DATA_DIR}/${XTRABACKUP_INFO_FILE}" | grep binlog_pos | awk -F' ' '{print "set global gtid_purged="$12";"}' | ${MYSQL_BIN}
		fi
  		MYSQL_REPLICA_OPTS=", MASTER_AUTO_POSITION=1"
	else
 		if [ -z "${MYSQL_MASTER_LOG_FILE}"; ]; then
 			if [ -f "${MYSQL_DATA_DIR}/${XTRABACKUP_BINLOG_INFO_FILE}" ]; then
    				_logging "Get master log file and master log position.."
				MYSQL_MASTER_LOG_FILE=$(cat "${MYSQL_DATA_DIR}/${XTRABACKUP_BINLOG_INFO_FILE}" 2>/dev/null | awk {'print $1'} )
				MYSQL_MASTER_LOG_POS=$(cat "${MYSQL_DATA_DIR}/${XTRABACKUP_BINLOG_INFO_FILE}" 2>/dev/null | awk {'print $2'} )
    			else
       				_logging "WARNING: File '${MYSQL_DATA_DIR}/${XTRABACKUP_BINLOG_INFO_FILE}' not found."
    			fi
    		fi
      		if [ -n "${MYSQL_MASTER_LOG_FILE}"; ]; then
			MYSQL_REPLICA_OPTS=", MASTER_LOG_FILE='${MYSQL_MASTER_LOG_FILE}', MASTER_LOG_POS=${MYSQL_MASTER_LOG_POS}"
   		fi
	fi
	if [ -n "${MYSQL_OTHER_CHANGE_MASTER_OPTS}" ]; then
		MYSQL_REPLICA_OPTS="${MYSQL_REPLICA_OPTS}, ${MYSQL_OTHER_CHANGE_MASTER_OPTS}"
	fi
	if [ -n "${MYSQL_CHANNEL_NAME}" ]; then
		MYSQL_REPLICA_OPTS="${MYSQL_REPLICA_OPTS} FOR CHANNEL '${MYSQL_CHANNEL_NAME}'"
	fi
	_logging "Set change master to..."
	${MYSQL_BIN} -e "CHANGE MASTER TO MASTER_HOST='${MYSQL_MASTER_HOST}', MASTER_PORT=${MYSQL_MASTER_HOST_PORT}, MASTER_USER='${MYSQL_MASTER_USER}', MASTER_PASSWORD='${MYSQL_MASTER_USER_PASSWORD}'${MYSQL_REPLICA_OPTS};" 1>>"${LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, set change master ."
	else
		_fail "Error, change master not set."
	fi
	_logging "Set read only mode..."
	${MYSQL_BIN} -e "SET GLOBAL read_only=1;" 1>>"${LOG_FILE}" 2>&1
	${MYSQL_BIN} -e "SET GLOBAL super_read_only=1;" 1>>"${LOG_FILE}" 2>&1
	if [ $? -eq 0 ]; then
		_logging "Done, set read only mode."
	else
		_fail "Error, read only mode not set."
	fi
	_logging "Start slave..."
	if [ -n "${MYSQL_CHANNEL_NAME}" ]; then
		${MYSQL_BIN} -e "START SLAVE FOR CHANNEL '${MYSQL_CHANNEL_NAME}';" 1>>"${LOG_FILE}" 2>&1
	else
		${MYSQL_BIN} -e "START SLAVE;" 1>>"${LOG_FILE}" 2>&1
	fi
	if [ $? -eq 0 ]; then
		_logging "Done, slave started."
	else
		_fail "Error, slave not started."
	fi
}

if [ ${STOP_MYSQL_BEFORE} -eq 1 ]; then
	_stop_mysql
fi

if [ ${DELETE_MYSQL_DATA_BEFORE} -eq 1 ]; then
	_delete_mysql_data
fi

_logging "Started socat on port ${LISTEN_PORT}, wait for magic tag..."
SOCAT_TEST=$(${SOCAT_BIN} -u tcp-listen:${LISTEN_PORT},reuseaddr stdout 2>${LOG_FILE})

if [ -n "${SOCAT_TEST}" ]; then
	if [[ "${SOCAT_TEST}" == "${SENDER_MAGIC_TAG}" ]]; then
		_logging "Good, magic tag recived."
		if [ -d "${MYSQL_FULL_BACKUP_DIR}" ]; then
			_logging "Started ${USE_STREAM_PROGRAM} on port ${LISTEN_PORT}, wait for ending mysql backup..."
			sleep 5
			${STREAM_PROGRAM} ${STREAM_PROGRAM_OPTS} | ${STREAM_BIN} -x -C "${MYSQL_FULL_BACKUP_DIR}"
			if [ -f "${MYSQL_FULL_BACKUP_DIR}/${XTRABACKUP_INFO_FILE}" ]; then
				_logging "All mysql backup recived and save to '${MYSQL_FULL_BACKUP_DIR}'"
				if [ ${FULL_RESTORE_BACKUP} -eq 1 ]; then
					_run_full_restore "${MYSQL_FULL_BACKUP_DIR}"
					if [ ${RUN_REPLICATION} -eq 1 ]; then
						_run_replica
					fi
				else
					_logging "Follow these steps to restore MySQL from this backup:"
					if [[ "${BACKUP_METHOD}" = "percona" ]]; then
						_logging "1) Run: xtrabackup --prepare --target-dir=${MYSQL_FULL_BACKUP_DIR}"
					fi
					if [[ "${BACKUP_METHOD}" = "maria" ]]; then
						_logging "1) Run: mariabackup --prepare --target-dir=${MYSQL_FULL_BACKUP_DIR}"
					fi
					_logging "2) Run: systemctl stop mysql"
					_logging "3) Run: mv /var/lib/mysql /var/lib/mysql_old OR rm -rf /var/lib/mysql"
					_logging "4) Run: mkdir /var/lib/mysql; chown mysql:mysql /var/lib/mysql; chmod 750 /var/lib/mysql"
					if [[ "${BACKUP_METHOD}" = "percona" ]]; then
						_logging "5) Run: xtrabackup --move-back --target-dir=${MYSQL_FULL_BACKUP_DIR}"
					fi
					if [[ "${BACKUP_METHOD}" = "maria" ]]; then
						_logging "5) Run: mariabackup --move-back --target-dir=${MYSQL_FULL_BACKUP_DIR}"
					fi
					_logging "6) Run: chown -R mysql:mysql /var/lib/mysql"
					_logging "7) Run: systemctl start mysql"
					_logging "8) Run: mysql -u root -p"
					_logging "9) Run: rm -rf /var/lib/mysql_old"
				fi
			else
				if [ -f "${LOG_FILE}" ]; then
					SOCAT_ERROR=$(cat "${LOG_FILE}")
					if [ -n "${SOCAT_ERROR}" ]; then
						_fail "ERROR: See log '${LOG_FILE}'"
					fi
				fi
			fi
		else
			_fail "ERROR: Directory '${MYSQL_FULL_BACKUP_DIR}' not found."
		fi
	else
		_fail "ERROR: Bad socat test connection."
	fi
else
	_fail "ERROR: Socat test connection failed."
fi

if [ -f "${SOCAT_ERROR_LOG}" ]; then
       	rm -f "${SOCAT_ERROR_LOG}" >/dev/null 2>&1
fi

_logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'"
