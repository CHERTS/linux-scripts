#!/usr/bin/env bash
#
# Program: Remove nginx + php5-fpm vhosts <nginx-remove-vhost.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.1
# 
# Example: ./nginx-remove-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1
#
# Revision History:
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

delete_linux_user_and_group ()
{
	local USERLOGINNAME=${1}
	local GROUPNAME=${2}

	echo -en "${GREEN}Delete group ${GROUPNAME}...\t\t\t\t\t"
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

	echo -en "${GREEN}Delete user ${USERLOGINNAME}...\t\t\t\t\t"
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

	echo -en "${GREEN}Deactivate nginx config file...\t\t\t\t"
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
	echo -en "${GREEN}Delete nginx config file ${SITENAME}.vhost...\t"
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

	echo -en "${GREEN}Delete php5-fpm config file ${USERLOGINNAME}.conf...\t\t"
	if [ -e "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" ]
	then
		rm -f "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf"
		if [ ! -e "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" ]; then
			echo -e "Done${NORMAL}"
			echo -en "${GREEN}Reload php5-fpm...\t\t\t\t\t"
			${PHP_FPM_RUN_SCRIPT} reload >/dev/null 2>&1
			echo -e "Done${NORMAL}"
		else
			echo -e "${RED}Error${NORMAL}"
		fi
	else
		echo -e "${RED}Error: php5-fpm config file ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf not found.${NORMAL}"
	fi
}

nginx_reload ()
{
        echo -en "${GREEN}Nginx configtest...\t\t\t\t\t"
        /etc/init.d/nginx configtest > /tmp/nginx_configtest 2>&1
        NGX_CONFIG_TEST_RESULT=`cat /tmp/nginx_configtest | grep successful`
        if [ -z "${NGX_CONFIG_TEST_RESULT}" ]; then
            rm /tmp/nginx_configtest
            echo -e "${RED}Error${NORMAL}"
            exit 1;
        else
            rm /tmp/nginx_configtest
            echo -e "Done${NORMAL}"
            echo -en "${GREEN}Reload nginx...\t\t\t\t\t\t"
            /etc/init.d/nginx reload >/dev/null 2>&1
            echo -e "Done${NORMAL}"
        fi
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

if [ "${SITEDIR}" == "" ]; then
	SITEDIR=${DEFAULT_SITE_DIR}/${SITENAME}
fi

if [ "${USERLOGINNAME}" == "" ]; then
	echo -e "${RED}Error: You must enter a user name.${NORMAL}"
	usage
	exit 1;
fi

if [ "${GROUPNAME}" == "" ]; then
	echo -e "${RED}Error: You must enter a group name.${NORMAL}"
	usage
	exit 1;
fi

if [ "${SITENAME}" != "" ]
then
	if [ ! -d "${SITEDIR}" ]
	then
	  echo -e "${RED}Error: Site directory ${SITEDIR} not found.${NORMAL}"
	  exit 1;
	fi
        delete_phpfpm_conf "${USERLOGINNAME}" "${GROUPNAME}"
        delete_nginx_vhost "${SITENAME}"
	if [ -d ${SITEDIR} ]
	then
		echo -en "${GREEN}Delete site directory ${SITEDIR}...\t"
		rm -rf ${SITEDIR}
		if [ ! -d ${SITEDIR} ]; then
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
