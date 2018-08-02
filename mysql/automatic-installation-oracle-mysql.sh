#!/usr/bin/env bash

#
# Program: Automatic installation Oracle MySQL <automatic_installation_oracle_mysql.sh>
#
# Author: Mikhail Grigorev <sleuthound at gmail dot com>
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
#  $ ./automatic_installation_oracle_mysql.sh
#  or
#  $ ./automatic_installation_oracle_mysql.sh -p "MYROOTPWD"


VERSION="1.0"

echo ""
echo "Automatic installation Oracle MySQL v$VERSION"
echo "Written by Mikhail Grigorev (sleuthhound@gmail.com, http://blog.programs74.ru)"
echo ""

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
        echo "Usage: $0 [ -p password ]"
        echo ""
        echo "  -p password     : MySQL user root password"
        echo "  -h              : Print this screen"
        echo ""
        exit 1
}

while getopts "p:h" option; do
        case "${option}" in
                p)
                        ROOTPWD=${OPTARG}
                        ;;
                *)
                        _usage
                        ;;
        esac
done

if [ -z "${ROOTPWD}" ]; then
        USE_PWGEN=1
else
        USE_PWGEN=0
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
            DISTROBASEDON="SuSe"
            DIST="SuSE"
            PSUEDONAME=$(cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//)
            REV=$(cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //)
        elif [ -f "/etc/mandrake-releasei" ]; then
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
		echo "${DIST} ${REV}"
		case "${REV}" in
		14.04|16.04|17.10|18.04)
			echo  " (${PSUEDONAME})"
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
			echo  " (${PSUEDONAME})"
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
        echo -n "Installing pwgen... "
        apt-get install pwgen -y >/dev/null 2>&1
        if [ $? -eq 0 ]; then
                echo "OK"
        else
                echo "Error"
                exit 1
        fi
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
                RESULT=$(${PWGEN_BIN} -cnB 12 1)
                echo "OK (${RESULT})"
                EXIT_CODE=0
        else
                echo "Error: \"pwgen\" not found."
                EXIT_CODE=1
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

echo -n "Checking your privileges... "
CURRENT_USER=$(whoami) #$EUID
CURRENT_USER_HOME_DIR=$(getent passwd ${CURRENT_USER} | awk -F':' '{print $6}')
MYSQL_CNF="${CURRENT_USER_HOME_DIR}/.my.cnf"
if [[ "${CURRENT_USER}" = "root" ]]; then
        echo "OK"
else
        echo "Error: root access is required"
        exit 1
fi

if ! _command_exists apt-key ; then
        echo "Error: Command 'apt-key' not found."
        exit 1
fi

if [ $(dpkg-query -W -f='${Status}' mysql-community-server  2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        if [ ${USE_PWGEN} -eq 1 ]; then
                if ! _command_exists pwgen ; then
                        _installing_pwgen
                fi
                _password_gen MYSQL_ROOT_PASSWD
                EXIT_CODE=$?
        else
                MYSQL_ROOT_PASSWD=${ROOTPWD}
                EXIT_CODE=0
        fi
        if [ ${EXIT_CODE} -eq 0 ]; then
                echo -n "Adding gpg-key... "
                apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 5072E1F5 >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                        echo "OK"
                else
                        echo "Error"
                fi
                echo -n "Adding Oracle repositary... "
                if [[ "${DIST}" = "Ubuntu" ]] ; then
                        echo "deb http://repo.mysql.com/apt/ubuntu/ ${PSUEDONAME} mysql-apt-config" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
                        echo "deb http://repo.mysql.com/apt/ubuntu/ ${PSUEDONAME} mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
                        echo "deb http://repo.mysql.com/apt/ubuntu/ ${PSUEDONAME} mysql-tools" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
                        echo "deb-src http://repo.mysql.com/apt/ubuntu/ ${PSUEDONAME} mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
                        echo "OK"
                elif [[ "${DIST}" = "Debian" ]] ; then
                        echo "deb http://repo.mysql.com/apt/debian/ ${PSUEDONAME} mysql-apt-config" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
                        echo "deb http://repo.mysql.com/apt/debian/ ${PSUEDONAME} mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
                        echo "deb http://repo.mysql.com/apt/debian/ ${PSUEDONAME} mysql-tools" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
                        echo "deb-src http://repo.mysql.com/apt/debian/ ${PSUEDONAME} mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list >/dev/null 2>&1
                        echo "OK"
                else
                        echo "Error: This distrib not supported from Oracle MySQL"
                        exit 1
                fi
                echo -n "Updating packages list... "
                apt-get update >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                        echo "OK"
                else
                        echo "Error"
                fi
                echo "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections >/dev/null 2>&1
                echo "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections >/dev/null 2>&1
                #echo "mysql-community-server mysql-community-server/data-dir select ''" | debconf-set-selections >/dev/null 2>&1
                echo -n "Installing Oracle MySQL... "
                apt-get install mysql-community-server -y >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                        echo "OK"
                        #sed -i 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
                        mysql -s -u root -p"${MYSQL_ROOT_PASSWD}" -e "UPDATE mysql.user SET Password=PASSWORD('$DATABASE_PASS') WHERE User='root'" >/dev/null 2>&1
                        mysql -s -u root -p"${MYSQL_ROOT_PASSWD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" >/dev/null 2>&1
                        mysql -s -u root -p"${MYSQL_ROOT_PASSWD}" -e "DELETE FROM mysql.user WHERE User=''" >/dev/null 2>&1
                        mysql -s -u root -p"${MYSQL_ROOT_PASSWD}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'" >/dev/null 2>&1
                        mysql -s -u root -p"${MYSQL_ROOT_PASSWD}" -e "FLUSH PRIVILEGES" >/dev/null 2>&1
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
                else
                        echo "Error"
                fi
        else
                echo "ERROR: Error creating password."
        fi
else
        echo "ERROR: Found installed mysql-community-server"
fi
