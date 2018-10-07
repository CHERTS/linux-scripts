#!/usr/bin/env bash

#
# Program: Automatic installation (removing) Oracle MySQL <automatic_installation_oracle_mysql.sh>
#
# Author: Mikhail Grigorev <sleuthound at gmail dot com>
#
# Current Version: 1.1
#
# Revision History:
#
#  Version 1.1
#    Added function removing mysql with database directory
#
#  Version 1.1
#    Initial Release
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# Requirements:
#   Requires: apt-get, apt-key, dpkg-query, pwgen
#
# Installation:
#   Copy the shell script to a suitable location
#
# Tested platforms:
#  -- Debian 9 using /bin/bash
#  -- Ubuntu 16.04 using /bin/bash
#
# Usage:
#  Refer to the _usage() sub-routine, or invoke automatic_installation_oracle_mysql.sh
#  with the "-h" option.
#
# Example:
#
#  The first example will run automatic installation and generate random root password:
#
#  $ ./automatic_installation_oracle_mysql.sh -i
#  or
#  $ ./automatic_installation_oracle_mysql.sh -i -p "MYROOTPWD"
#
#  The second example will run automatic removing mysql with data directory:
#
#  $ ./automatic_installation_oracle_mysql.sh -d

VERSION="1.1"

echo ""
echo "Automatic installation (removing) Oracle MySQL v$VERSION"
echo "Written by Mikhail Grigorev (sleuthhound@gmail.com, http://blog.programs74.ru)"
echo ""

MYSQL_CONF_DIR=/etc/mysql
MYSQL_RUN_DIR=/var/run/mysqld
MYSQL_DEBIAN_CNF=${MYSQL_CONF_DIR}/debian.cnf
MYSQL_DEFAULT_LOG_DIR=/var/log/mysql
SYSTEM_LOGROTATE_DIR=/etc/logrotate.d

_command_exists() {
        type "$1" &> /dev/null
}

_unknown_os() {
	echo
	echo "Unfortunately, your operating system are not supported by this script."
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

_lowercase(){
	echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

_usage() {
	echo ""
	echo "Usage: $0 [ -i -p <password> OR -d ]"
	echo ""
	echo "  -i		: Install MySQL"
	echo "  -p password	: MySQL user root password (optional)"
	echo "  -d		: Remove MySQL with database directory"
	echo "  -h		: Print this screen"
	echo ""
	exit 1
}

INSTALL_MYSQL=0
DELETE_MYSQL=0
MYSQL_INSTALLED_DONE=0
USE_PWGEN=0

while getopts "p:idh" option; do
	case "${option}" in
		i)
			INSTALL_MYSQL=1
			;;
		p)
			ROOTPWD=${OPTARG}
			;;
		d)
			DELETE_MYSQL=1
			;;
		*)
			_usage
			;;
	esac
done

if [ -z "${ROOTPWD}" ]; then
	USE_PWGEN=1
fi

OS=$(uname -s)
OS_ARCH=$(uname -m)
echo -n "Detecting your OS: "
if [[ "${OS}" = "Linux" ]]; then
	echo "Linux (${OS_ARCH})"
	PLATFORM="linux"
	DISTROBASEDON="Unknown"
	DIST="Unknown"
	PSUEDONAME="Unknown"
	REV="Unknown"
	if [ -f "/etc/redhat-release" ]; then
		DISTROBASEDON="RedHat"
		DIST=$(cat /etc/redhat-release |sed s/\ release.*//)
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
else
	echo "Unknown"
	_unknown_os
fi

echo -n "Detecting your Linux distrib: "
case "${DIST}" in
	Ubuntu)
		echo -n "${DIST} ${REV}"
		case "${REV}" in
		14.04|16.04|17.10|18.04)
			echo " (${PSUEDONAME})"
			;;
		*)
			_unknown_distrib
			;;
		esac
		;;
	Debian)
		echo -n "${DIST} ${REV}"
		case "${REV}" in
		8|9)
			echo " (${PSUEDONAME})"
			;;
		*)
			_unknown_distrib
			;;
		esac
		;;
	*)
		echo "Unknown"
		_unknown_distrib
		;;
esac

_installing_pwgen() {
	local EXIT_CODE=0
	echo -n "Installing pwgen... "
	case "${DISTROBASEDON}" in
		Debian)
			apt-get -y install pwgen >/dev/null 2>&1
			EXIT_CODE=$?
			;;
		RedHat|Mandrake|SUSE)
			yum -y install pwgen >/dev/null 2>&1
			EXIT_CODE=$?
			;;
		*)
			EXIT_CODE=1
			;;
	esac
	if [ ${EXIT_CODE} -eq 0 ]; then
		echo "OK"
	else
		echo "Error"
	fi
	return ${EXIT_CODE}
}

_password_gen() {
	if [[ "$#" -eq 1 ]]; then
		local __RESULTVAR=$1
	fi
	local RESULT=""
	local EXIT_CODE=0
	if _command_exists pwgen ; then
		PWGEN_BIN=$(which pwgen)
		echo -n "Generate password... "
		RESULT=$(${PWGEN_BIN} -cnB 12 1)"!"
		echo "OK (${RESULT})"
		EXIT_CODE=0
	else
		echo "ERROR: Command 'pwgen' not found."
		EXIT_CODE=1
	fi
	if [[ "$__RESULTVAR" ]]; then
		eval $__RESULTVAR="'${RESULT}'"
	else
		echo "${RESULT}"
	fi
	return ${EXIT_CODE}
}

_randpw(){ < /dev/urandom tr -dc "_#<>%:*A-Z-a-z-0-9" | head -c${1:-12};echo; }

_password_gen_urandom() {
	if [[ "$#" -eq 1 ]]; then
		local __RESULTVAR=$1
	fi
	local RESULT=""
	local EXIT_CODE=0
	echo -n "Generate password... "
	RESULT=$(_randpw)
	if [ -z "${RESULT}" ]; then
		echo "ERROR: /dev/urandom not generate password."
		EXIT_CODE=1
	else
		echo "OK (${RESULT})"
	fi
	if [[ "$__RESULTVAR" ]]; then
		eval $__RESULTVAR="'${RESULT}'"
	else
		echo "${RESULT}"
	fi
	return ${EXIT_CODE}
}

_user_exists() {
	id -u "${1}" &> /dev/null;
}

_create_debian_sys_maint() {
	local MYSQL_ROOT_PASSWD="$1"	
	echo -n "Create debian-sys-maint user... "
	if [ -e "${MYSQL_DEBIAN_CNF}" -a -n "`fgrep mysql_upgrade ${MYSQL_DEBIAN_CNF} 2>/dev/null`" ]; then
		MYSQL_DEBIAN_PASSWD="`sed -n 's/^[     ]*password *= *// p' ${MYSQL_DEBIAN_CNF} | head -n 1`"
		sed -i '/basedir/d' "${MYSQL_DEBIAN_CNF}"
	else
		MYSQL_DEBIAN_PASSWD=$(perl -e 'print map{("a".."z","A".."Z",0..9)[int(rand(62))]}(1..16)')
	fi
	${MYSQL_BIN} -s -e "CREATE USER IF NOT EXISTS 'debian-sys-maint'@'localhost' IDENTIFIED BY '${MYSQL_DEBIAN_PASSWD}';"
	${MYSQL_BIN} -s -e "GRANT ALL ON *.* TO 'debian-sys-maint'@'localhost' WITH GRANT OPTION;"
	${MYSQL_BIN} -s -e "FLUSH PRIVILEGES;" >/dev/null 2>&1
	FIND_USER=$(${MYSQL_BIN} -N -e "select count(*) from mysql.user where user='debian-sys-maint' and host='localhost';") >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "OK"
	else
		echo "Error"
	fi
	echo -n "Creating ${MYSQL_DEBIAN_CNF}... "
	if [ -d "${MYSQL_CONF_DIR}" ]; then
		(cat <<-EOF
			# Automatically generated for Debian scripts. DO NOT TOUCH!
			[client]
			host     = localhost
			user     = debian-sys-maint
			password = ${MYSQL_DEBIAN_PASSWD}
			socket   = ${MYSQL_RUN_DIR}/mysqld.sock
			[mysql_upgrade]
			host     = localhost
			user     = debian-sys-maint
			password = ${MYSQL_DEBIAN_PASSWD}
			socket   = ${MYSQL_RUN_DIR}/mysqld.sock
		EOF
		) > "${MYSQL_DEBIAN_CNF}"
		if [ -f "${MYSQL_DEBIAN_CNF}" ]; then
			echo "OK"
			chmod 0600 "${MYSQL_DEBIAN_CNF}" >/dev/null 2>&1
		else
			echo "Error"
		fi
	else
		echo "Error"
	fi
}

_configure_logrotate() {
	local EXIT_CODE=1
	if [ -d "${SYSTEM_LOGROTATE_DIR}" ]; then
		(cat <<-EOF
			${MYSQL_DEFAULT_LOG_DIR}/error.log {
			daily
			rotate 7
			missingok
			create 640 mysql adm
			compress
			sharedscripts
			postrotate
				test -x /usr/bin/mysqladmin || exit 0
				MYADMIN="/usr/bin/mysqladmin --defaults-file=${MYSQL_DEBIAN_CNF}"
				if [ ! -z "\$(\$MYADMIN ping 2>/dev/null)" ]; then
					\$MYADMIN flush-logs
				fi
			endscript
			}
		EOF
		) > "${SYSTEM_LOGROTATE_DIR}/mysql.tmp"
		if [ $? -eq 0  ]; then
			mv "${SYSTEM_LOGROTATE_DIR}/mysql.tmp" "${SYSTEM_LOGROTATE_DIR}/mysql" 2>/dev/null
			if [ $? -eq 0 ]; then
				EXIT_CODE=0
			else
				echo "WARNING. Failed to re-create ${SYSTEM_LOGROTATE_DIR}/mysql"
			fi
		else
			echo "WARNING. Failed to create ${SYSTEM_LOGROTATE_DIR}/mysql.tmp"
		fi
	else
		echo "ERROR: Logrotate directory not found."
	fi
	return ${EXIT_CODE}
}

echo -n "Checking your privileges... "
CURRENT_USER=$(whoami) #$EUID
CURRENT_USER_HOME_DIR=$(getent passwd ${CURRENT_USER} | awk -F':' '{print $6}')
MYSQL_CNF="${CURRENT_USER_HOME_DIR}/.my.cnf"
if [[ "${CURRENT_USER}" = "root" ]]; then
	echo "OK"
else
	echo "ERROR: root access is required"
	exit 1
fi

if [ ${INSTALL_MYSQL} -eq 1 ]; then
	if [ ${DELETE_MYSQL} -eq 1 ]; then
		_usage
	fi
	# Create root password
	MYSQL_ROOT_PASSWD=""
	if [ ${USE_PWGEN} -eq 1 ]; then
		if ! _command_exists pwgen ; then
			_installing_pwgen
		fi
		_password_gen MYSQL_ROOT_PASSWD
		EXIT_CODE=$?
		if [ ${EXIT_CODE} -ne 0 ]; then
			_password_gen_urandom MYSQL_ROOT_PASSWD
		fi
		EXIT_CODE=$?
	else
		MYSQL_ROOT_PASSWD=${ROOTPWD}
		EXIT_CODE=0
	fi
	if [ ${EXIT_CODE} -ne 0 ]; then
		echo "ERROR: Password for 'root' user was not generated."
		exit 1
	fi
	# Installing MySQL
	if [[ "${DISTROBASEDON}" = "Debian" ]]; then
		if ! _command_exists apt-key ; then
			echo "ERROR: Command 'apt-key' not found."
			exit 1
		fi
		if [ $(dpkg-query -W -f='${Status}' mysql-community-server  2>/dev/null | grep -c "ok installed") -eq 0 ]; then
			echo -n "Adding gpg-key... "
			apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 5072E1F5 >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "OK"
			else
				echo "Error"
			fi
			echo -n "Adding Oracle repositary... "
			if [ -f "/etc/apt/sources.list.d/mysql.list" ]; then
				rm -f "/etc/apt/sources.list.d/mysql.list" >/dev/null 2>&1
			fi
			if [[ "${DIST}" = "Ubuntu" ]] ; then
				echo "deb http://repo.mysql.com/apt/ubuntu/ ${PSUEDONAME} mysql-apt-config" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
				echo "deb http://repo.mysql.com/apt/ubuntu/ ${PSUEDONAME} mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
				echo "deb http://repo.mysql.com/apt/ubuntu/ ${PSUEDONAME} mysql-tools" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
				echo "deb-src http://repo.mysql.com/apt/ubuntu/ ${PSUEDONAME} mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
				echo "OK"
				#export DEBIAN_FRONTEND=noninteractive
			elif [[ "${DIST}" = "Debian" ]] ; then
				echo "deb http://repo.mysql.com/apt/debian/ ${PSUEDONAME} mysql-apt-config" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
				echo "deb http://repo.mysql.com/apt/debian/ ${PSUEDONAME} mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
				echo "deb http://repo.mysql.com/apt/debian/ ${PSUEDONAME} mysql-tools" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
				echo "deb-src http://repo.mysql.com/apt/debian/ ${PSUEDONAME} mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
				echo "OK"
				#export DEBIAN_FRONTEND=noninteractive
			else
				echo "ERROR: This distrib not supported from Oracle MySQL"
				exit 1
			fi
			echo -n "Updating packages list... "
			apt-get update >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "OK"
			else
				echo "Error"
				exit 1
			fi
			MYSQL_ROOT_PASSWD=$(printf %q "${MYSQL_ROOT_PASSWD}")
			echo "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections >/dev/null 2>&1
			echo "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections >/dev/null 2>&1
			#echo "mysql-server mysql-server/root_password password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections >/dev/null 2>&1
			#echo "mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections >/dev/null 2>&1
			#echo "mysql-community-server mysql-community-server/data-dir select '/var/lib/mysql/data'" | debconf-set-selections >/dev/null 2>&1
			#echo "mysql-community-server mysql-community-server/data-dir note '/var/lib/mysql/data'" | debconf-set-selections >/dev/null 2>&1
			echo -n "Installing Oracle MySQL... "
			apt-get install mysql-community-server -y >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "OK"
				MYSQL_INSTALLED_DONE=1
			else
				echo "Error"
				exit 1
			fi
		else
			echo "ERROR: Found installed mysql-community-server"
			exit 1
		fi
	else
		_unknown_distrib
	fi
	# Post install procedure
	if [ ${MYSQL_INSTALLED_DONE} -eq 1 ];then
		if _command_exists mysql ; then
			MYSQL_BIN=$(which mysql)
		else
			echo "ERROR: Command 'mysql' not found."
			exit 1
		fi
		# Create ~/.my.cnf file
		echo -n "Creating ${MYSQL_CNF}... "
		(cat <<-EOF
			[mysql]
			prompt = [\\u@\\p][\\d]>\\_
			no-auto-rehash
			user=root
			password=${MYSQL_ROOT_PASSWD}
			[mysqladmin]
			user=root
			password=${MYSQL_ROOT_PASSWD}
			[mysqldump]
			single-transaction
			user=root
			password=${MYSQL_ROOT_PASSWD}
			[mysqlcheck]
			user=root
			password=${MYSQL_ROOT_PASSWD}
			[mysql_upgrade]
			user=root
			password=${MYSQL_ROOT_PASSWD}
		EOF
		) > "${MYSQL_CNF}"
		if [ -f "${MYSQL_CNF}" ]; then
			echo "OK"
		else
			echo "Error"
		fi
		#sed -i 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
		${MYSQL_BIN} -s -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" >/dev/null 2>&1
		${MYSQL_BIN} -s -e "DELETE FROM mysql.user WHERE User=''" >/dev/null 2>&1
		${MYSQL_BIN} -s -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'" >/dev/null 2>&1
		${MYSQL_BIN} -s -e "FLUSH PRIVILEGES;" >/dev/null 2>&1
		# Create debian-sys-maint user
		_create_debian_sys_maint "${MYSQL_ROOT_PASSWD}"
		# Create logrotate rule
		echo -n "Create logrotate... "
		_configure_logrotate
		if [ $? -eq 0 ]; then
			echo "OK"
			echo -n "Checking logrotate... "
			logrotate -f "${SYSTEM_LOGROTATE_DIR}/mysql" > /tmp/logrotate_configtest 2>&1
			LOGROTATE_STATUS=$(cat /tmp/logrotate_configtest | grep -c "error")
			rm -f "/tmp/logrotate_configtest" >/dev/null 2>&1
			if [ ${LOGROTATE_STATUS} -eq 0 ]; then
				echo "SyntaxOK"
			else
				echo "SyntaxError"
			fi
		else
			echo "Error"
		fi
	else
		echo "ERROR: MySQL is not installed on the server or is installed with errors."
		exit 1
	fi
else
	# Removing MySQL
	if [ ${DELETE_MYSQL} -eq 1 ]; then
		if [[ "${DISTROBASEDON}" = "Debian" ]]; then
			if [ $(dpkg-query -W -f='${Status}' mysql-community-server  2>/dev/null | grep -c "ok installed") -ne 0 ]; then
				echo -n "Removing MySQL... "
				echo "mysql-community-server mysql-community-server/remove-data-dir boolean true" | debconf-set-selections >/dev/null 2>&1
				apt-get -y remove mysql-community-server mysql-community-client mysql-common --purge >/dev/null 2>&1
				if [ $(dpkg-query -W -f='${Status}' mysql-community-server  2>/dev/null | grep -c "ok installed") -eq 0 ]; then
					echo "OK"
					# Delete ~/.my.cnf file
					echo -n "Delete ${MYSQL_CNF}... "
					if [ -f "${MYSQL_CNF}" ]; then
						rm -f "${MYSQL_CNF}" >/dev/null 2>&1
						if [ ! -f "${MYSQL_CNF}" ]; then
							echo "OK"
						else
							echo "Error"
						fi
					else
						echo "NotFound"
					fi
					# Delete logrotate rule
					echo -n "Delete logrotate rule... "
					if [ -f "${SYSTEM_LOGROTATE_DIR}/mysql" ]; then
						rm -f "${SYSTEM_LOGROTATE_DIR}/mysql" >/dev/null 2>&1
						if [ ! -f "${SYSTEM_LOGROTATE_DIR}/mysql" ]; then
							echo "OK"
						else
							echo "Error"
						fi
					else
						echo "NotFound"
					fi
				else
					echo "Error"
				fi
			else
				echo "ERROR: Package mysql-community-server not found."
			fi
		fi
	else
		_usage
	fi
fi
