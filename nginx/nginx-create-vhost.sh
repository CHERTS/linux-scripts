#!/usr/bin/env bash
#
# Program: Added nginx + php5-fpm vhosts <nginx-create-vhost.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.1
# 
# Example: ./nginx-create-vhost.sh -d "domain.com"
# or
# Example: ./nginx-create-vhost.sh -s "/var/www/domain.com" -d "domain.com"
# or
# Example: ./nginx-create-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1
#
# Revision History:
#
#  Version 1.1
#    Added template function
#
#  Version 1.0
#    Initial Release
#

DEFAULT_SERVERIP="10.0.0.2"
NGINX_USER=www-data
NGINX_DIR=/etc/nginx
NGINX_VHOST_DIR=/etc/nginx/sites-available
NGINX_VHOST_SITE_ENABLED_DIR=/etc/nginx/sites-enabled
NGINX_COMMON_DIR=/etc/nginx/common
NGINX_COMMON_SERVER_CONFFILE=server.conf
NGINX_COMMON_REWRITES_CONFFILE=rewrites.conf
NGINX_COMMON_PHP_CONFFILE=php.conf
PHP_FPM_POOL_DIR=/etc/php5/fpm/pool.d
PHP_FPM_SOCK_DIR=/var/lib/php5-fpm
PHP_FPM_RUN_SCRIPT=/etc/init.d/php5-fpm
DEFAULT_SITE_DIR=/var/www
DEFAULT_TEMPLATE_DIR=/etc/nginx/template
CUR_DIR=`pwd`

RED='\033[0;31m'        # RED
GREEN='\033[0;32m'      # GREEN
BLUE='\033[0;34m'       # BLUE
CYAN='\033[0;36m'	# CYAN
YELLOW='\033[0;33m'     # YELLOW
NORMAL='\033[0m'        # Default color

user_in_group()
{
    groups ${1} | grep $2>/dev/null 2>&1
}

create_linux_user_and_group ()
{
	local USERLOGINNAME=${1}
	local GROUPNAME=${2}

	echo -en "${GREEN}Adding new user ${USERLOGINNAME}...\t\t\t\t\t"
	ret=false
	getent passwd ${USERLOGINNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo -e "${RED}Error, user ${USERLOGINNAME} already exists${NORMAL}"
	    exit 1;
	fi
	useradd -d ${SITEDIR} -s /bin/false ${USERLOGINNAME}
	ret=false
	getent passwd ${USERLOGINNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo -e "Done${NORMAL}"
	    NEXTWEBUSER_NUM=`cat ${NGINX_DIR}/settings.conf | grep NEXTWEBUSER | cut -d "=" -f 2 | sed s/[^0-9]//g`
	    NEXTWEBUSER_NAME=`cat ${NGINX_DIR}/settings.conf | grep NEXTWEBUSER | cut -d "=" -f 2 | sed s/[^a-zA-Z]//g`
	    let "NEXTWEBUSER_NUM_INC=${NEXTWEBUSER_NUM}+1"
	    sed -i "s@${USERLOGINNAME}@${NEXTWEBUSER_NAME}${NEXTWEBUSER_NUM_INC}@g" ${NGINX_DIR}/settings.conf
	else
	    echo -e "${RED}Error, the user ${USERLOGINNAME} does not exist${NORMAL}"
	    exit 1;
	fi

	echo -en "${GREEN}Adding new group ${GROUPNAME}...\t\t\t\t"
	ret=false
	getent group ${GROUPNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo -e "${CYAN}Warning, group ${GROUPNAME} already exists${NORMAL}"
	else
		addgroup ${GROUPNAME} >/dev/null 2>&1
		ret=false
		getent group ${GROUPNAME} >/dev/null 2>&1 && ret=true
		if $ret; then
		    echo -e "Done${NORMAL}"
		    NEXTWEBGROUP_NUM=`cat ${NGINX_DIR}/settings.conf | grep NEXTWEBGROUP | cut -d "=" -f 2 | sed s/[^0-9]//g`
		    NEXTWEBGROUP_NAME=`cat ${NGINX_DIR}/settings.conf | grep NEXTWEBGROUP | cut -d "=" -f 2 | sed s/[^a-zA-Z]//g`
		    let "NEXTWEBGROUP_NUM_INC=${NEXTWEBGROUP_NUM}+1"
		    sed -i "s@${GROUPNAME}@${NEXTWEBGROUP_NAME}${NEXTWEBGROUP_NUM_INC}@g" ${NGINX_DIR}/settings.conf
		else
		    echo -e "${RED}Error, the group ${GROUPNAME} does not exist${NORMAL}"
		    exit 1;
		fi
	fi

	echo -en "${GREEN}Adding user ${USERLOGINNAME} to group ${GROUPNAME}...\t\t\t"
	usermod -a -G ${GROUPNAME} ${USERLOGINNAME} >/dev/null 2>&1
	if user_in_group "${USERLOGINNAME}" "${GROUPNAME}"; then
		echo -e "Done${NORMAL}"
	else
		echo -e "${RED}Error: User ${USERLOGINNAME} not adding in group ${GROUPNAME}${NORMAL}"
		exit 1;
	fi

	echo -en "${GREEN}Adding user ${NGINX_USER} to group ${GROUPNAME}...\t\t"
	usermod -a -G ${GROUPNAME} ${NGINX_USER} >/dev/null 2>&1
	if user_in_group "${NGINX_USER}" "${GROUPNAME}"; then
		echo -e "Done${NORMAL}"
	else
		echo -e "${RED}Error: User ${NGINX_USER} not adding in group ${GROUPNAME}${NORMAL}"
		exit 1;
	fi

}

create_simple_index_page ()
{
	local SITEDIR=${1}
	local SITENAME=${2}

	echo -en "${GREEN}Create ${SITEDIR}/web/index.html...\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/index.html.template" "${SITEDIR}/web/index.html"
	if [ -e "${SITEDIR}/web/index.html" ]
	then
	  sed -i "s@!SITENAME!@${SITENAME}@g" ${SITEDIR}/web/index.html
	  echo -e "Done${NORMAL}"
	else
	  echo -e "${RED}Error${NORMAL}"
	fi

}

create_robots_file ()
{
	local SITEDIR=${1}

	echo -en "${GREEN}Create ${SITEDIR}/web/robots.txt...\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/robots.txt.template" "${SITEDIR}/web/robots.txt"
	if [ -e "${SITEDIR}/web/robots.txt" ]
	then
	  echo -e "Done${NORMAL}"
	else
	  echo -e "${RED}Error${NORMAL}"
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

create_nginx_vhost ()
{
	local SITENAME=${1}
	local SITEDIR=${2}
	local USERLOGINNAME=${3}
	local GROUPNAME=${4}

	if [ ! -d "${NGINX_VHOST_DIR}" ]
	then
	  echo -e "${CYAN}Warning: Directory ${NGINX_VHOST_DIR} not exist.${NORMAL}"
	  echo -en "${GREEN}Create a nginx vhost directory ${NGINX_VHOST_DIR}...\t"
	  mkdir -p "${NGINX_VHOST_DIR}"
	  if [ -d "${NGINX_VHOST_DIR}" ]; then
	    echo -e "Done${NORMAL}"
	  else
	    echo -e "${RED}Error${NORMAL}"
	  fi
	fi

	echo -en "${GREEN}Create a home directory...\t\t\t\t"
	mkdir -p "${SITEDIR}"
	if [ -d "${SITEDIR}" ]
	then
	  echo -e "Done${NORMAL}"
	else
	  echo -e "${RED}Error${NORMAL}"
	fi

	echo -en "${GREEN}Create web,log,tmp,private directory...\t\t\t"
	mkdir -p "${SITEDIR}/web"
	mkdir -p "${SITEDIR}/log"
	mkdir -p "${SITEDIR}/private"
	mkdir -p "${SITEDIR}/tmp"
	if [ -d "${SITEDIR}/web" ]
	then
		echo -e "Done${NORMAL}"
		create_simple_index_page "${SITEDIR}" "${SITENAME}"
		create_robots_file "${SITEDIR}"
	else
		echo -e "${RED}Error${NORMAL}"
	fi

	echo -en "${GREEN}Set permition to directory...\t\t\t\t"
	chmod -R 755 ${SITEDIR}
	chmod -R 770 ${SITEDIR}/tmp
	chmod -R 755 ${SITEDIR}/web
	chmod -R 710 ${SITEDIR}/private
	chown -R ${USERLOGINNAME}:${GROUPNAME} ${SITEDIR}/*
	chown root:root ${SITEDIR}
	chown root:root ${SITEDIR}/log
	echo -e "Done${NORMAL}"

	echo -en "${GREEN}Create nginx config file ${SITENAME}.vhost...\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/nginx_virtual_host.template" "${NGINX_VHOST_DIR}/${SITENAME}.vhost"
	if [ -e "${NGINX_VHOST_DIR}/${SITENAME}.vhost" ]
	then
		sed -i "s@!SERVERIP!@${SERVERIP}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		sed -i "s@!SITENAME!@${SITENAME}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		sed -i "s@!SITEDIR!@${SITEDIR}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		sed -i "s@!PHPFPMSOCKDIR!@${PHP_FPM_SOCK_DIR}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		sed -i "s@!USERLOGINNAME!@${USERLOGINNAME}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		echo -e "Done${NORMAL}"
		echo -en "${GREEN}Activate nginx config file...\t\t\t\t"
		ln -s ${NGINX_VHOST_DIR}/${SITENAME}.vhost ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost
		linktest=`readlink ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost`
		if [ -n "${linktest}" ]
		then
			echo -e "Done${NORMAL}"
			nginx_reload
		else
			echo -e "${RED}Error, link ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost not exist${NORMAL}"
		fi
	else
		echo -e "${RED}Error, file ${NGINX_VHOST_DIR}/${SITENAME}.vhost not exist${NORMAL}"
	fi
}

create_phpfpm_conf ()
{
	local SITEDIR=${1}
	local USERLOGINNAME=${2}
	local GROUPNAME=${3}

	if [ ! -d "${PHP_FPM_POOL_DIR}" ]
	then
	  echo -e "${CYAN}Warning: Directory ${PHP_FPM_POOL_DIR} not exist.${NORMAL}"
	  echo -en "${GREEN}Create a php-fpm pool directory ${PHP_FPM_POOL_DIR}...\t"
	  mkdir -p "${PHP_FPM_POOL_DIR}"
	  if [ -d "${PHP_FPM_POOL_DIR}" ]; then
	    echo -e "Done${NORMAL}"
	    chmod 755 "${PHP_FPM_POOL_DIR}"
	  else
	    echo -e "${RED}Error${NORMAL}"
	  fi
	fi

	if [ ! -d "${PHP_FPM_SOCK_DIR}" ]
	then
	  echo -e "${CYAN}Warning: Directory ${PHP_FPM_SOCK_DIR} not exist.${NORMAL}"
	  echo -en "${GREEN}Create a php-fpm socket directory ${PHP_FPM_SOCK_DIR}...\t"
	  mkdir -p "${PHP_FPM_SOCK_DIR}"
	  if [ -d "${PHP_FPM_SOCK_DIR}" ]; then
	    echo -e "Done${NORMAL}"
	    chmod 755 "${PHP_FPM_SOCK_DIR}"
	  else
	    echo -e "${RED}Error${NORMAL}"
	  fi
	fi

	echo -en "${GREEN}Create php5-fpm config file ${USERLOGINNAME}.conf...\t\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/php_fpm.conf.template" "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf"
	if [ -e "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" ]
	then
		sed -i "s@!SITEDIR!@${SITEDIR}@g" ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
		sed -i "s@!USERLOGINNAME!@${USERLOGINNAME}@g" ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
		sed -i "s@!GROUPNAME!@${GROUPNAME}@g" ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
		sed -i "s@!PHPFPMSOCKDIR!@${PHP_FPM_SOCK_DIR}@g" ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
		echo -e "Done${NORMAL}"
		echo -en "${GREEN}Reload php5-fpm...\t\t\t\t\t"
		${PHP_FPM_RUN_SCRIPT} reload >/dev/null 2>&1
		echo -e "Done${NORMAL}"
	else
		echo -e "${RED}Error${NORMAL}"
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


if [ ! -d "${NGINX_DIR}" ]; then
	echo -e "${RED}Error: nginx directory ${NGINX_DIR} not found.${NORMAL}"
	exit 1;
fi

if [ ! -e "${NGINX_DIR}/settings.conf" ]; then
	echo -e "${CYAN}Warning: Main settings file ${NGINX_DIR}/settings.conf not found.${NORMAL}"
	echo -en "${GREEN}Copy default settings file to ${NGINX_DIR}/settings.conf...\t"
	cp -- "${CUR_DIR}/settings.conf" "${NGINX_DIR}"
	if [ -e "${NGINX_DIR}/settings.conf" ]; then
	   echo -e "Done${NORMAL}"
	else
	  echo -e "${RED}Error: Main settings file ${NGINX_DIR}/settings.conf not found.${NORMAL}"
	  exit 1;
	fi
fi

if [ ! -d "${NGINX_COMMON_DIR}" ]; then
	echo -en "${GREEN}Create ${NGINX_COMMON_DIR} directory...\t"
	mkdir -p "${NGINX_COMMON_DIR}"
	if [ -d "${NGINX_COMMON_DIR}" ]; then
	   echo -e "Done${NORMAL}"
	else
	   echo -e "${RED}Error: Failed to create the ${NGINX_COMMON_DIR} directory.${NORMAL}"
	   exit 1;
	fi
fi

if [ ! -e "${NGINX_COMMON_DIR}/${NGINX_COMMON_SERVER_CONFFILE}" ]; then
  if [ -e "${CUR_DIR}/common/${NGINX_COMMON_SERVER_CONFFILE}" ]; then
    cp -- "${CUR_DIR}/common/${NGINX_COMMON_SERVER_CONFFILE}" "${NGINX_COMMON_DIR}"
  else
    echo -e "${RED}Error: File common/${NGINX_COMMON_SERVER_CONFFILE} not found.${NORMAL}"
    exit 1;
  fi
fi

if [ ! -e "${NGINX_COMMON_DIR}/${NGINX_COMMON_REWRITES_CONFFILE}" ]; then
  if [ -e "${CUR_DIR}/common/${NGINX_COMMON_REWRITES_CONFFILE}" ]; then
    cp -- "${CUR_DIR}/common/${NGINX_COMMON_REWRITES_CONFFILE}" "${NGINX_COMMON_DIR}"
  else
    echo -e "${RED}Error: File common/${NGINX_COMMON_REWRITES_CONFFILE} not found.${NORMAL}"
    exit 1;
  fi
fi

if [ ! -e "${NGINX_COMMON_DIR}/${NGINX_COMMON_PHP_CONFFILE}" ]; then
  if [ -e "${CUR_DIR}/common/${NGINX_COMMON_PHP_CONFFILE}" ]; then
    cp -- "${CUR_DIR}/common/${NGINX_COMMON_PHP_CONFFILE}" "${NGINX_COMMON_DIR}"
  else
    echo -e "${RED}Error: File common/${NGINX_COMMON_PHP_CONFFILE} not found.${NORMAL}"
    exit 1;
  fi
fi

if [ ! -d "${DEFAULT_TEMPLATE_DIR}" ]; then
	echo -en "${GREEN}Copy default template directory...\t"
	cp -R -- "${CUR_DIR}/template/" "${NGINX_DIR}"
	if [ -d "${DEFAULT_TEMPLATE_DIR}" ]; then
	   echo -e "Done${NORMAL}"
	else
	   echo -e "${RED}Error: Failed to create the ${DEFAULT_TEMPLATE_DIR} directory.${NORMAL}"
	   exit 1;
	fi
fi

if [ "${SITEDIR}" = "" ]; then
	SITEDIR=${DEFAULT_SITE_DIR}/${SITENAME}
fi

if [ "${USERLOGINNAME}" = "" ]; then
	USERLOGINNAME=`cat ${NGINX_DIR}/settings.conf | grep NEXTWEBUSER | cut -d "=" -f 2`
	if [ "${USERLOGINNAME}" = "" ]; then
	  echo -e "${RED}Error: In file ${NGINX_DIR}/settings.conf not found parameter NEXTWEBUSER.${NORMAL}"
	  usage
	  exit 1;
	fi
fi
echo -e "${GREEN}Set new username:\t${USERLOGINNAME}${NORMAL}"

if [ "${GROUPNAME}" = "" ]; then
	GROUPNAME=`cat ${NGINX_DIR}/settings.conf | grep NEXTWEBGROUP | cut -d "=" -f 2`
	if [ "${GROUPNAME}" = "" ]; then
	  echo -e "${RED}Error: In file ${NGINX_DIR}/settings.conf not found parameter NEXTWEBGROUP.${NORMAL}"
	  usage
	  exit 1;
	fi
fi
echo -e "${GREEN}Set new groupname:\t${GROUPNAME}${NORMAL}"

if [ "${SITENAME}" = "" ]; then
	echo -e "${RED}Error: You must enter a domain name.${NORMAL}"
	usage
	exit 1;
fi

# check the domain is roughly valid!
PATTERN="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,6}$"
if [[ "${SITENAME}" =~ $PATTERN ]]; then
	DOMAIN=`echo ${SITENAME} | tr '[A-Z]' '[a-z]'`
	echo -e "${GREEN}Set nginx hostname:\t${SITENAME}${NORMAL}"
else
	echo -e "${RED}Error: Invalid domain name.${NORMAL}"
	exit 1
fi

if [ -e "${NGINX_DIR}/settings.conf" ]; then
	SERVERIP=`cat ${NGINX_DIR}/settings.conf | grep SERVERIP | cut -d "=" -f 2`
	if [ "${SERVERIP}" = "" ]; then
		SERVERIP = ${DEFAULT_SERVERIP}
	fi
fi
echo -e "${GREEN}Set nginx vhost ip:\t${SERVERIP}${NORMAL}"

if [ "${SITENAME}" != "" ]
then
	if [ -d "${SITEDIR}" ]
	then
	  echo -e "${RED}Error: Site directory ${SITEDIR} alredy exist.${NORMAL}"
	  exit 1;
	fi
	create_linux_user_and_group "${USERLOGINNAME}" "${GROUPNAME}"
        create_phpfpm_conf "${SITEDIR}" "${USERLOGINNAME}" "${GROUPNAME}"
        create_nginx_vhost "${SITENAME}" "${SITEDIR}" "${USERLOGINNAME}" "${GROUPNAME}"
else
        usage
        exit 1;
fi
