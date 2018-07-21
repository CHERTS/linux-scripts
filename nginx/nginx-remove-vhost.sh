#!/usr/bin/env bash
#
# Program: Remove nginx + php-fpm vhosts <nginx-remove-vhost.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.4.1
# 
# Example: ./nginx-remove-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1
#
# Revision History:
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

	if [ ! -d ${NGINX_VHOST_DIR} ]
	then
	  echo -e "${RED}Error: Directory ${NGINX_VHOST_DIR} not exist, please, check directory.${NORMAL}"
	  exit 1;
	fi

	echo -en "${GREEN}Deactivate nginx config file...\t\t\t"
	if [ -L "${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost" ]
	then
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
	if [ -e "${NGINX_VHOST_DIR}/${SITENAME}.vhost" ]; then
		rm -f "${NGINX_VHOST_DIR}/${SITENAME}.vhost"
		if [ ! -e "${NGINX_VHOST_DIR}/${SITENAME}.vhost" ]; then
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

	if [ ! -d ${PHP_FPM_POOL_DIR} ]
	then
	  echo -e "${RED}Error: Directory ${PHP_FPM_POOL_DIR} not exist, please, check directory.${NORMAL}"
	fi

	if [ ! -d ${PHP_FPM_SOCK_DIR} ]
	then
	  echo -e "${CYAN}Warning: Directory ${PHP_FPM_SOCK_DIR} not exist.${NORMAL}"
	fi

	echo -en "${GREEN}Delete php-fpm config file ${USERLOGINNAME}.conf...\t\t"
	if [ -e "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" ]
	then
		rm -f "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf"
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
		rm -f "/etc/logrotate.d/${USERLOGINNAME}" 2>/dev/null
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
				echo -e "${RED}Error: Socket does not exist${NORMAL}"
               		fi
		else
			if [ -f "${PHP_FPM_RUN_SCRIPT}" ]; then
				${PHP_FPM_RUN_SCRIPT} restart >/dev/null 2>&1
                		if [ ! -S "${PHP_FPM_SOCK_DIR}/${USERLOGINNAME}.sock" ]; then
					echo -e "Done${NORMAL}"
                		else
					echo -e "${RED}Error: Socket does not exist${NORMAL}"
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
        ${NGINX_BIN} -t > /tmp/nginx_configtest 2>&1
        NGX_CONFIG_TEST_RESULT=$(grep successful /tmp/nginx_configtest)
        if [ -z "${NGX_CONFIG_TEST_RESULT}" ]; then
            rm -f /tmp/nginx_configtest >/dev/null 2>&1
            echo -e "${RED}Error${NORMAL}"
            exit 1;
        else
            rm -f /tmp/nginx_configtest >/dev/null 2>&1
            echo -e "Done${NORMAL}"
            echo -en "${GREEN}Reload nginx...\t\t\t\t\t"
            ${NGINX_BIN} -s reload >/dev/null 2>&1
            echo -e "Done${NORMAL}"
        fi
}

unknown_os ()
{
  echo
  echo "Unfortunately, your operating system distribution and version are not supported by this script."
  echo
  echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
  exit 1
}

unknown_distrib ()
{
  echo
  echo "Unfortunately, your ${os} operating system distribution and version are not supported by this script."
  echo
  echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
  exit 1
}

unknown_debian ()
{
  echo
  echo "Unfortunately, your Debian Linux operating system distribution and version are not supported by this script."
  echo
  echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
  exit 1
}

unknown_oracle ()
{
  echo
  echo "Unfortunately, your Oracle Linux operating system distribution and version are not supported by this script."
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

os=$(uname -s)
os_arch=$(uname -m)
echo -en "${GREEN}Detecting your OS\t"
if [ "${os}" = "Linux" ]; then
        echo -e "Linux (${os_arch})${NORMAL}"
else
        echo -e "${RED}Unknown${NORMAL}"
        unknown_os
fi

if command_exists strings ; then
	STRINGS_BIN=$(which strings)
else
	echo -e "${RED}Error: Command strings not found.${NORMAL}"
	exit 1;
fi

OS_INIT_SYSTEM=$(${STRINGS_BIN} /sbin/init | awk 'match($0, /(upstart|systemd|sysvinit)/) { print toupper(substr($0, RSTART, RLENGTH));exit; }')

echo -en "${GREEN}Detecting ${os} distrib\t"
if [ -f "/etc/debian_version" ]; then
	DEBIAN_VERSION=$(sed 's/\..*//' /etc/debian_version)
	OS_DISTRIB="Debian"
	echo -e "${OS_DISTRIB}${NORMAL}"
	if [[ "${DEBIAN_VERSION}" = "9" ]]; then
		echo -en "${GREEN}Detecting your php-fpm\t"
		if command_exists php-fpm7.0 ; then
			echo -e "Found php-fpm7.0${NORMAL}"
			PHP_FPM_BIN=$(which php-fpm7.0)
                        PHP_FPM_POOL_DIR=/etc/php/7.0/fpm/pool.d
                        PHP_FPM_SOCK_DIR=/run/php
			if [ -f "/etc/init.d/php7.0-fpm" ]; then
	                        PHP_FPM_RUN_SCRIPT=/etc/init.d/php7.0-fpm
			else
				echo -e "${RED}Error: php-fpm init script not found.${NORMAL}"
				exit 1;
			fi
		else
			echo -e "${RED}Error: php-fpm not found.${NORMAL}"
			exit 1;
		fi
	elif [[ "${DEBIAN_VERSION}" = "8" ]]; then
		echo -en "${GREEN}Detecting your php-fpm\t"
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
		unknown_debian
	fi
elif [ -f /etc/oracle-release ]; then
	ORACLE_VERSION=$(cat /etc/oracle-release | sed s/.*release\ // | sed s/\ .*//)
	OS_DISTRIB="Oracle"
	echo -e "${OS_DISTRIB}${NORMAL}"
	if [[ "${ORACLE_VERSION}" = "6.9" ]]; then
                echo -en "${GREEN}Detecting your php-fpm\t"
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
	elif [[ "${ORACLE_VERSION}" = "7.4" ]]; then
                echo -en "${GREEN}Detecting your php-fpm\t"
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
        else
                unknown_oracle
        fi
else
	unknown_distrib
fi

if command_exists nginx ; then
        NGINX_BIN=$(which nginx)
else
        echo -e "${RED}Error: nginx not found.${NORMAL}"
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
	if [ ! -d "${SITEDIR}" ]
	then
	  echo -e "${RED}Error: Site directory ${SITEDIR} not found.${NORMAL}"
	  exit 1;
	fi
        delete_phpfpm_conf "${USERLOGINNAME}" "${GROUPNAME}"
        delete_nginx_vhost "${SITENAME}"
	delete_logrotate "${USERLOGINNAME}"
	if [ -d "${SITEDIR}" ]
	then
	        echo -en "${GREEN}Unset protected attribute to directory...\t"
        	chattr -a "${SITEDIR}"
        	echo -e "Done${NORMAL}"
		echo -en "${GREEN}Delete site directory...\t\t\t"
		rm -rf ${SITEDIR}
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
