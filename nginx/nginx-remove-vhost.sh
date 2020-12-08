#!/usr/bin/env bash
#
# Program: Remove nginx + php-fpm vhosts <nginx-remove-vhost.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.4.8
# 
# Example: ./nginx-remove-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1
#
# Revision History:
#
#  Version 1.4.8
#    Added CentOS Linux and Ubuntu 20.04
#
#  Version 1.4.7
#    Added Debian 10 and PHP-FPM 7.3 support
#
#  Version 1.4.6
#    Fixed RedHat detected
#
#  Version 1.4.5
#    Added custom nginx templates
#
#  Version 1.4.4
#    Added Ubuntu support (php7.2)
#
#  Version 1.4.3
#    Fixed php-fpm socket 
#
#  Version 1.4.2
#    Added Oracle Linux 6.x and 7.x support
#
#  Version 1.4.1
#    Added logrotate rule
#
#  Version 1.4
#    Added Oracle Linux 7.4 support
#
#  Version 1.3
#    Added Oracle Linux 6.9 support
#
#  Version 1.2
#    Added Debian 9 and PHP-FPM 7 support
#
#  Version 1.1
#    Fixed many errors
#
#  Version 1.0
#    Initial Release
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

NGINX_VHOST_DIR=/etc/nginx/sites-available
NGINX_VHOST_SITE_ENABLED_DIR=/etc/nginx/sites-enabled
PHP_FPM_POOL_DIR=/etc/php5/fpm/pool.d
PHP_FPM_SOCK_DIR=/var/lib/php5-fpm
PHP_FPM_RUN_SCRIPT=/etc/init.d/php5-fpm
DEFAULT_SITE_DIR=/var/www

RED='\033[0;31m'        # RED
GREEN='\033[0;32m'      # GREEN
BLUE='\033[0;34m'       # BLUE
CYAN='\033[0;36m'	# CYAN
YELLOW='\033[0;33m'     # YELLOW
NORMAL='\033[0m'        # Default color

command_exists () {
	type "${1}" &> /dev/null ;
}

delete_linux_user_and_group ()
{
	local USERLOGINNAME=${1}
	local GROUPNAME=${2}

	echo -en "${GREEN}Delete group ${GROUPNAME}...\t\t\t\t"
	ret=false
	getent group ${GROUPNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
		groupdel ${GROUPNAME} >/dev/null 2>&1
		ret=false
		getent group ${GROUPNAME} >/dev/null 2>&1 && ret=true
		if $ret; then
		    echo -e "${CYAN}Warning: Group ${GROUPNAME} not deleted${NORMAL}"
		else
		    echo -e "Done${NORMAL}"
		fi
	else
	    echo -e "${CYAN}Warning: Group ${GROUPNAME} not found${NORMAL}"
	fi

	echo -en "${GREEN}Delete user ${USERLOGINNAME}...\t\t\t\t"
	ret=false
	getent passwd ${USERLOGINNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
		userdel ${USERLOGINNAME} >/dev/null 2>&1
		ret=false
		getent passwd ${USERLOGINNAME} >/dev/null 2>&1 && ret=true
		if $ret; then
		    echo -e "${CYAN}Warning: User ${USERLOGINNAME} not deleted${NORMAL}"
		else
		    echo -e "Done${NORMAL}"
		fi
	else
	    echo -e "${CYAN}Warning: User ${USERLOGINNAME} not found${NORMAL}"
	fi
}

delete_nginx_vhost ()
{
	local SITENAME=${1}

	if [ ! -d "${NGINX_VHOST_DIR}" ]; then
		echo -e "${RED}Error: Directory ${NGINX_VHOST_DIR} not exist, please, check directory.${NORMAL}"
		exit 1;
	fi

	echo -en "${GREEN}Deactivate nginx config file...\t\t\t"
	if [ -L "${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost" ]; then
		unlink "${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost"
		if [ ! -L "${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost" ]; then
			echo -e "Done${NORMAL}"
		else
			echo -e "${RED}Error${NORMAL}"
		fi
	else
		echo -e "${RED}Error: Link ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost not exist.${NORMAL}"
	fi
	echo -en "${GREEN}Delete nginx config file...\t\t\t"
	if [ -f "${NGINX_VHOST_DIR}/${SITENAME}.vhost" ]; then
		rm -f "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
		if [ ! -f "${NGINX_VHOST_DIR}/${SITENAME}.vhost" ]; then
			echo -e "Done${NORMAL}"
			nginx_reload
		else
			echo -e "${RED}Error${NORMAL}"
		fi
	else
		echo -e "${RED}Error: File ${NGINX_VHOST_DIR}/${SITENAME}.vhost not exist.${NORMAL}"
	fi

}

delete_phpfpm_conf ()
{
	local USERLOGINNAME=${1}
	local GROUPNAME=${2}

	if [ ! -d "${PHP_FPM_POOL_DIR}" ]; then
		echo -e "${RED}Error: Directory ${PHP_FPM_POOL_DIR} not exist, please, check directory.${NORMAL}"
	fi

	if [ ! -d "${PHP_FPM_SOCK_DIR}" ]; then
		echo -e "${CYAN}Warning: Directory ${PHP_FPM_SOCK_DIR} not exist.${NORMAL}"
	fi

	echo -en "${GREEN}Delete php-fpm config file ${USERLOGINNAME}.conf...\t\t"
	if [ -f "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" ]; then
		rm -f "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" >/dev/null 2>&1
		if [ ! -e "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" ]; then
			echo -e "Done${NORMAL}"
			phpfpm_reload ${USERLOGINNAME}
		fi
	else
		echo -e "${RED}Error: php-fpm config file ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf not found.${NORMAL}"
	fi
}

delete_logrotate ()
{
	local USERLOGINNAME=${1}

	if [ -f "/etc/logrotate.d/${USERLOGINNAME}" ]; then
		echo -en "${GREEN}Delete logrotate rule...\t\t\t"
		rm -f "/etc/logrotate.d/${USERLOGINNAME}" >/dev/null 2>&1
		if [ $(echo $?) != 0 ]; then
			echo -e "${RED}Error: Failed to delete /etc/logrotate.d/${USERLOGINNAME}.${NORMAL}"
		else
			echo -e "Done${NORMAL}"
		fi
	fi
}

phpfpm_reload ()
{
	local USERLOGINNAME=${1}

	echo -en "${GREEN}Configtest php-fpm...\t\t\t\t"
	${PHP_FPM_BIN} -t > /tmp/phpfpm_configtest 2>&1
	PHPFPM_CONFIG_TEST_RESULT=$(grep ERROR /tmp/phpfpm_configtest)
	if [ -n "${PHPFPM_CONFIG_TEST_RESULT}" ]; then
		rm -f /tmp/phpfpm_configtest >/dev/null 2>&1
		echo -e "${RED}Error${NORMAL}"
		exit 1;
	else
		rm -f /tmp/phpfpm_configtest >/dev/null 2>&1
		echo -e "Done${NORMAL}"
		echo -en "${GREEN}Restart php-fpm...\t\t\t\t"
		if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
			SYSTEMCTL_BIN=$(which systemctl)
			${SYSTEMCTL_BIN} restart ${PHP_FPM_RUN_SCRIPT} >/dev/null 2>&1
			if [ ! -S "${PHP_FPM_SOCK_DIR}/${USERLOGINNAME}.sock" ]; then
				echo -e "Done${NORMAL}"
			else
				echo -e "${RED}Error: Socket exist${NORMAL}"
			fi
		else
			if [ -f "${PHP_FPM_RUN_SCRIPT}" ]; then
				${PHP_FPM_RUN_SCRIPT} restart >/dev/null 2>&1
				if [ ! -S "${PHP_FPM_SOCK_DIR}/${USERLOGINNAME}.sock" ]; then
					echo -e "Done${NORMAL}"
				else
					echo -e "${RED}Error: Socket exist${NORMAL}"
				fi
			else
				echo -e "${RED}Error: ${PHP_FPM_RUN_SCRIPT} does not exist.${NORMAL}"
			fi
		fi
	fi
}

nginx_reload ()
{
	echo -en "${GREEN}Nginx configtest...\t\t\t\t"
	${NGINX_BIN} -t > "/tmp/nginx_configtest" 2>&1
	NGX_CONFIG_TEST_RESULT=$(grep successful "/tmp/nginx_configtest")
	if [ -z "${NGX_CONFIG_TEST_RESULT}" ]; then
		rm -f "/tmp/nginx_configtest" >/dev/null 2>&1
		echo -e "${RED}Error${NORMAL}"
		exit 1;
	else
		rm -f "/tmp/nginx_configtest" >/dev/null 2>&1
		echo -e "Done${NORMAL}"
		echo -en "${GREEN}Reload nginx...\t\t\t\t\t"
		${NGINX_BIN} -s reload >/dev/null 2>&1
		echo -e "Done${NORMAL}"
	fi
}

_unknown_os ()
{
	echo
	echo "Unfortunately, your operating system distribution and version are not supported by this script."
	echo
	echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
	exit 1
}

_unknown_distrib ()
{
	echo
	echo "Unfortunately, your ${os} operating system distribution and version are not supported by this script."
	echo
	echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
	exit 1
}

_unknown_debian ()
{
	echo
	echo "Unfortunately, your Debian Linux operating system distribution and version are not supported by this script."
	echo
	echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
	exit 1
}

_unknown_oracle ()
{
	echo
	echo "Unfortunately, your Oracle Linux operating system distribution and version are not supported by this script."
	echo
	echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
	exit 1
}

_unknown_centos ()
{
	echo
	echo "Unfortunately, your CentOS Linux operating system distribution and version are not supported by this script."
	echo
	echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
	exit 1
}

usage()
{
	echo "Usage: $0 [ -d domain_name -s site_directory -u user_name -g group_name]"
	echo ""
	echo "  -d sitename	: Domain name, domain.com"
	echo "  -s sitedir	: Site directory, /var/www/domain.com"
	echo "  -u username	: User name, www-data"
	echo "  -g group	: Group name, www-data"
	echo "  -h		: Print this screen"
	echo ""
}

### Evaluate the options passed on the command line
while getopts h:s:d:u:g: option
do
	case "${option}"
	in
		d) SITENAME=${OPTARG};;
		u) USERLOGINNAME=${OPTARG};;
		g) GROUPNAME=${OPTARG};;
		s) SITEDIR=${OPTARG};;
		\?) usage
		exit 1;;
	esac
done

_detect_linux_distrib() {
	local DIST=$1
	local REV=$2
	local PSUEDONAME=$3
	echo -en "${GREEN}Detecting your Linux distrib\t"
	case "${DIST}" in
		Ubuntu)
			echo -n "${DIST} ${REV}"
			case "${REV}" in
			14.04|16.04|17.10|18.04|20.04)
				echo -e " (${PSUEDONAME})${NORMAL}"
				;;
			*)
				_unknown_distrib
				;;
			esac
			;;
		Debian)
			echo -n "${DIST} ${REV}"
			case "${REV}" in
			8|9|10)
				echo -e " (${PSUEDONAME})${NORMAL}"
				;;
			*)
				_unknown_distrib
				;;
			esac
			;;
		"Red Hat"*|"RedHat"*)
			echo -e "${DIST} ${REV} (${PSUEDONAME})${NORMAL}"
			;;
		CentOS|"CentOS Linux")
			echo -e "${DIST} ${REV} (${PSUEDONAME})${NORMAL}"
			;;
		*)
			echo -e "Unsupported (${DIST} | ${REV} | ${PSUEDONAME})${NORMAL}"
			_unknown_distrib
			;;
	esac
}

OS=$(uname -s)
OS_ARCH=$(uname -m)
echo -en "${GREEN}Detecting your OS\t\t"
case "${OS}" in
	Linux*)
		echo -e "Linux (${OS_ARCH})${NORMAL}"
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
		echo -e "Unknown${NORMAL}"
		_unknown_os
		;;
esac

echo -en "${GREEN}Checking your privileges\t"
CURRENT_USER=$(whoami)
if [[ "${CURRENT_USER}" = "root" ]]; then
	echo -e "OK${NORMAL}"
else
	echo -e "${RED}Error: root access is required${NORMAL}"
	exit 1
fi

if command_exists strings ; then
	STRINGS_BIN=$(which strings)
else
	echo -e "${RED}Error: Command strings not found.${NORMAL}"
	exit 1;
fi

OS_INIT_SYSTEM=$(${STRINGS_BIN} /sbin/init | awk 'match($0, /(upstart|systemd|sysvinit)/) { print toupper(substr($0, RSTART, RLENGTH));exit; }')

case "${DIST}" in
	Ubuntu)
		echo -en "${GREEN}Detecting your php-fpm\t\t"
		if command_exists php-fpm7.2 ; then
			echo -e "Found php-fpm7.2${NORMAL}"
			PHP_FPM_BIN=$(which php-fpm7.2)
			PHP_FPM_POOL_DIR="/etc/php/7.2/fpm/pool.d"
			PHP_FPM_SOCK_DIR="/run/php"
			if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
				PHP_FPM_RUN_SCRIPT="php7.2-fpm"
			else
				if [ -f "/etc/init.d/php7.2-fpm" ]; then
					PHP_FPM_RUN_SCRIPT="/etc/init.d/php7.2-fpm"
				else
					echo -e "${RED}Error: php-fpm init script not found.${NORMAL}"
					exit 1;
				fi
			fi
		else
			echo -e "${RED}Error: php-fpm not found.${NORMAL}"
			exit 1;
		fi
		;;
	Debian)
		DEBIAN_VERSION=$(sed 's/\..*//' /etc/debian_version)
		OS_DISTRIB="Debian"
		echo -e "${GREEN}Detect Debian version\t\t${OS_DISTRIB} (${OS_INIT_SYSTEM})${NORMAL}"
		if [[ "${DEBIAN_VERSION}" = "10" ]]; then
			echo -en "${GREEN}Detecting your php-fpm\t\t"
			if command_exists php-fpm7.3 ; then
				echo -e "Found php-fpm7.3${NORMAL}"
				PHP_FPM_BIN=$(which php-fpm7.3)
				PHP_FPM_POOL_DIR=/etc/php/7.3/fpm/pool.d
				PHP_FPM_SOCK_DIR=/run/php
				if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
					PHP_FPM_RUN_SCRIPT="php7.3-fpm"
				else
					if [ -f "/etc/init.d/php7.3-fpm" ]; then
						PHP_FPM_RUN_SCRIPT=/etc/init.d/php7.3-fpm
					else
						echo -e "${RED}Error: php-fpm init script not found.${NORMAL}"
						exit 1;
					fi
				fi
			else
				echo -e "${RED}Error: php-fpm not found.${NORMAL}"
				exit 1;
			fi
		elif [[ "${DEBIAN_VERSION}" = "9" ]]; then
			echo -en "${GREEN}Detecting your php-fpm\t\t"
			if command_exists php-fpm7.0 ; then
				echo -e "Found php-fpm7.0${NORMAL}"
				PHP_FPM_BIN=$(which php-fpm7.0)
				PHP_FPM_POOL_DIR=/etc/php/7.0/fpm/pool.d
				PHP_FPM_SOCK_DIR=/run/php
				if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
					PHP_FPM_RUN_SCRIPT="php7.0-fpm"
				else
					if [ -f "/etc/init.d/php7.0-fpm" ]; then
						PHP_FPM_RUN_SCRIPT=/etc/init.d/php7.0-fpm
					else
						echo -e "${RED}Error: php-fpm init script not found.${NORMAL}"
						exit 1;
					fi
				fi
			else
				echo -e "${RED}Error: php-fpm not found.${NORMAL}"
				exit 1;
			fi
		elif [[ "${DEBIAN_VERSION}" = "8" ]]; then
			echo -en "${GREEN}Detecting your php-fpm\t\t"
			if command_exists php5-fpm ; then
				echo -e "Found php5-fpm${NORMAL}"
				PHP_FPM_BIN=$(which php5-fpm)
				PHP_FPM_POOL_DIR=/etc/php5/fpm/pool.d
				PHP_FPM_SOCK_DIR=/var/lib/php5-fpm
				if [ -f "/etc/init.d/php5-fpm" ]; then
					PHP_FPM_RUN_SCRIPT=/etc/init.d/php5-fpm
				else
					echo -e "${RED}Error: php-fpm init script not found.${NORMAL}"
					exit 1;
				fi
			else
				echo -e "${RED}Error: php-fpm not found.${NORMAL}"
				exit 1;
			fi
		else
			_unknown_debian
		fi
		;;
    "Red Hat"*|"RedHat"*)
		if [ -f "/etc/oracle-release" ]; then
			ORACLE_VERSION=$(cat "/etc/oracle-release" | sed s/.*release\ // | sed s/\ .*//)
			OS_DISTRIB="RedHat"
			echo -e "${GREEN}Detect OracleLinux version\t\t${OS_DISTRIB} ${ORACLE_VERSION} (${OS_INIT_SYSTEM})${NORMAL}"
			case "${ORACLE_VERSION}" in
				6.*)
					echo -en "${GREEN}Detecting your php-fpm\t\t"
					if command_exists php-fpm ; then
						PHP_FPM_BIN=$(which php-fpm)
						echo -e "Found php-fpm${NORMAL}"
						if [ -d "/etc/php-fpm.d" ]; then
							PHP_FPM_POOL_DIR=/etc/php-fpm.d
							PHP_FPM_SOCK_DIR=/var/run
							if [ -f "/etc/init.d/php-fpm" ]; then
								PHP_FPM_RUN_SCRIPT=/etc/init.d/php-fpm
							else
								echo -e "${RED}Error: php-fpm init script not found.${NORMAL}"
								exit 1;
							fi
						else
							echo -e "${RED}Error: php-fpm not found.${NORMAL}"
							exit 1;
						fi
					else
						echo -e "${RED}Error: php-fpm not found.${NORMAL}"
						exit 1;
					fi
				;;
				7.*|8.*)
					echo -en "${GREEN}Detecting your php-fpm\t\t"
					if command_exists php-fpm ; then
						PHP_FPM_BIN=$(which php-fpm)
						echo -e "Found php-fpm${NORMAL}"
						if [ -d "/etc/php-fpm.d" ]; then
							PHP_FPM_POOL_DIR=/etc/php-fpm.d
							PHP_FPM_SOCK_DIR=/run
							if [ -f "/usr/lib/systemd/system/php-fpm.service" ]; then
								PHP_FPM_RUN_SCRIPT=php-fpm
							else
								echo -e "${RED}Error: php-fpm unit not found.${NORMAL}"
								exit 1;
							fi
						else
							echo -e "${RED}Error: php-fpm not found.${NORMAL}"
							exit 1;
						fi
					else
						echo -e "${RED}Error: php-fpm not found.${NORMAL}"
						exit 1;
					fi
				;;
				*)
					_unknown_oracle
				;;
			esac
		else
			_unknown_os
		fi
		;;
	CentOS|"CentOS Linux")
		if [ -f "/etc/centos-release" ]; then
			CENTOS_VERSION=$(cat "/etc/centos-release" | sed s/.*release\ // | sed s/\ .*//)
			OS_DISTRIB="RedHat"
			echo -e "${GREEN}Detect CentOS version\t\t${OS_DISTRIB} ${CENTOS_VERSION} (${OS_INIT_SYSTEM})${NORMAL}"
			case "${CENTOS_VERSION}" in
				7.*|8.*)
					echo -en "${GREEN}Detecting your php-fpm\t\t"
					if command_exists php-fpm ; then
						PHP_FPM_BIN=$(which php-fpm)
						echo -e "Found php-fpm${NORMAL}"
						if [ -d "/etc/php-fpm.d" ]; then
							PHP_FPM_POOL_DIR=/etc/php-fpm.d
							PHP_FPM_SOCK_DIR=/run
							if [ -f "/usr/lib/systemd/system/php-fpm.service" ]; then
								PHP_FPM_RUN_SCRIPT=php-fpm
							else
								echo -e "${RED}Error: php-fpm unit not found.${NORMAL}"
								exit 1;
							fi
						else
							echo -e "${RED}Error: php-fpm not found.${NORMAL}"
							exit 1;
						fi
					else
						echo -e "${RED}Error: php-fpm not found.${NORMAL}"
						exit 1;
					fi
				;;
				*)
					_unknown_centos
				;;
			esac
		else
			_unknown_os
		fi
		;;
	*)
		_unknown_distrib
		;;
esac

if command_exists nginx ; then
	NGINX_BIN=$(which nginx)
else
	echo -e "${RED}Error: nginx not found.${NORMAL}"
	exit 1;
fi

if [ -z "${SITENAME}" ]; then
	echo -e "${RED}Error: You must enter a site name.${NORMAL}"
	usage
	exit 1;
fi

if [ -z "${SITEDIR}" ]; then
	SITEDIR=${DEFAULT_SITE_DIR}/${SITENAME}
fi

if [ -z "${USERLOGINNAME}" ]; then
	echo -e "${RED}Error: You must enter a user name.${NORMAL}"
	usage
	exit 1;
fi

if [ -z "${GROUPNAME}" ]; then
	echo -e "${RED}Error: You must enter a group name.${NORMAL}"
	usage
	exit 1;
fi

if [ -n "${SITENAME}" ]; then
	if [ ! -d "${SITEDIR}" ]; then
		echo -e "${RED}Error: Site directory ${SITEDIR} not found.${NORMAL}"
		exit 1;
	fi
	delete_phpfpm_conf "${USERLOGINNAME}" "${GROUPNAME}"
	delete_nginx_vhost "${SITENAME}"
	delete_logrotate "${USERLOGINNAME}"
	if [ -d "${SITEDIR}" ]; then
		echo -en "${GREEN}Unset protected attribute to directory...\t"
		chattr -a "${SITEDIR}" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo -e "Done${NORMAL}"
		else
			echo -e "Error${NORMAL}"
		fi
		echo -en "${GREEN}Delete site directory...\t\t\t"
		rm -rf "${SITEDIR}" >/dev/null 2>&1
		if [ ! -d "${SITEDIR}" ]; then
			echo -e "Done${NORMAL}"
		else
			echo -e "${CYAN}Warning: Site directory ${SITEDIR} not deleted.${NORMAL}"
		fi
	fi
	delete_linux_user_and_group "${USERLOGINNAME}" "${GROUPNAME}"
else
	usage
	exit 1;
fi
