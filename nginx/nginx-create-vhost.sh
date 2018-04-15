#!/usr/bin/env bash
#
# Program: Added nginx + php-fpm vhosts <nginx-create-vhost.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.4
# 
# Example: ./nginx-create-vhost.sh -d "domain.com"
# or
# Example: ./nginx-create-vhost.sh -s "/var/www/domain.com" -d "domain.com"
# or
# Example: ./nginx-create-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1
#
# Revision History:
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
#    Added template function
#
#  Version 1.0
#    Initial Release
#

DEFAULT_SERVERIP="10.0.0.2"
DEFAULT_SERVERPORT="80"
NGINX_USER=www-data
NGINX_DIR=/etc/nginx
NGINX_VHOST_DIR=/etc/nginx/sites-available
NGINX_VHOST_SITE_ENABLED_DIR=/etc/nginx/sites-enabled
PHP_FPM_POOL_DIR=/etc/php5/fpm/pool.d
PHP_FPM_SOCK_DIR=/var/lib/php5-fpm
PHP_FPM_RUN_SCRIPT=/etc/init.d/php5-fpm
DEFAULT_SITE_DIR=/var/www
DEFAULT_TEMPLATE_DIR=/etc/nginx/template
CUR_DIR=$(dirname "$0")

RED='\033[0;31m'        # RED
GREEN='\033[0;32m'      # GREEN
BLUE='\033[0;34m'       # BLUE
CYAN='\033[0;36m'	# CYAN
YELLOW='\033[0;33m'     # YELLOW
NORMAL='\033[0m'        # Default color

command_exists () {
        type "$1" &> /dev/null ;
}

user_in_group()
{
	groups ${1} | grep $2>/dev/null 2>&1
}

user_exists()
{
	getent passwd ${1} >/dev/null 2>&1
}

create_linux_user_and_group ()
{
	local USERLOGINNAME=${1}
	local GROUPNAME=${2}

	echo -en "${GREEN}Adding new user ${USERLOGINNAME}...\t\t\t\t"
	ret=false
	getent passwd ${USERLOGINNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo -e "${RED}Error, user ${USERLOGINNAME} already exists${NORMAL}"
	    exit 1;
	fi
	useradd -d ${SITEDIR} -s /bin/false ${USERLOGINNAME} >/dev/null 2>&1
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

	echo -en "${GREEN}Adding new group ${GROUPNAME}...\t\t\t"
	ret=false
	getent group ${GROUPNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo -e "${CYAN}Warning, group ${GROUPNAME} already exists${NORMAL}"
	else
		if [ ${OS_DISTRIB} == 'Oracle' ]; then
			groupadd ${GROUPNAME} >/dev/null 2>&1
		else
			addgroup ${GROUPNAME} >/dev/null 2>&1
		fi
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

	echo -en "${GREEN}Adding user ${USERLOGINNAME} to group ${GROUPNAME}...\t\t"
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

	echo -en "${GREEN}Create index.html...\t\t\t\t"
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

	echo -en "${GREEN}Create robots.txt...\t\t\t\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/robots.txt.template" "${SITEDIR}/web/robots.txt"
	if [ -e "${SITEDIR}/web/robots.txt" ]
	then
	  echo -e "Done${NORMAL}"
	else
	  echo -e "${RED}Error${NORMAL}"
	fi

}

phpfpm_reload ()
{
	local USERLOGINNAME=$1

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
		if [ ${OS_INIT_SYSTEM} == "SYSTEMD" ]; then
			SYSTEMCTL_BIN=$(which systemctl)
			${SYSTEMCTL_BIN} restart ${PHP_FPM_RUN_SCRIPT} >/dev/null 2>&1
               		if [ -S "${PHP_FPM_SOCK_DIR}/${USERLOGINNAME}.sock" ]; then
				echo -e "Done${NORMAL}"
               		else
				echo -e "${RED}Error: Socket does not exist${NORMAL}"
               		fi
		else
			if [ -f "${PHP_FPM_RUN_SCRIPT}" ]; then
				${PHP_FPM_RUN_SCRIPT} restart >/dev/null 2>&1
                		if [ -S "${PHP_FPM_SOCK_DIR}/${USERLOGINNAME}.sock" ]; then
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

create_site_dir ()
{
        local SITENAME=${1}
        local SITEDIR=${2}
        local USERLOGINNAME=${3}
        local GROUPNAME=${4}

        echo -en "${GREEN}Create a home directory...\t\t\t"
        mkdir -p "${SITEDIR}"
        if [ -d "${SITEDIR}" ]
        then
          echo -e "Done${NORMAL}"
        else
          echo -e "${RED}Error${NORMAL}"
        fi

        echo -en "${GREEN}Create web,log,tmp,private directory...\t\t"
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

        echo -en "${GREEN}Set permition to directory...\t\t\t"
        chmod -R 755 "${SITEDIR}"
        chmod -R 770 "${SITEDIR}/tmp"
        chmod -R 755 "${SITEDIR}/web"
        chmod -R 710 "${SITEDIR}/private"
        chown -R ${USERLOGINNAME}:${GROUPNAME} "${SITEDIR}"
        chown root:root "${SITEDIR}"
        chown root:root "${SITEDIR}/log"
        echo -e "Done${NORMAL}"

        echo -en "${GREEN}Set protected attribute to directory...\t\t"
        chattr +a "${SITEDIR}"
        echo -e "Done${NORMAL}"
}

create_nginx_vhost ()
{
	local SITENAME=${1}
	local SITEDIR=${2}
	local USERLOGINNAME=${3}

	if [ ! -d "${NGINX_VHOST_DIR}" ]
	then
	  echo -e "${CYAN}Warning: Directory ${NGINX_VHOST_DIR} not exist.${NORMAL}"
	  echo -en "${GREEN}Create a nginx vhost directory...\t\t"
	  mkdir -p "${NGINX_VHOST_DIR}"
	  if [ -d "${NGINX_VHOST_DIR}" ]; then
	    echo -e "Done${NORMAL}"
	  else
	    echo -e "${RED}Error${NORMAL}"
	  fi
	fi

        if [ ! -d "${NGINX_VHOST_SITE_ENABLED_DIR}" ]
        then
          echo -e "${CYAN}Warning: Directory ${NGINX_VHOST_SITE_ENABLED_DIR} not exist.${NORMAL}"
          echo -en "${GREEN}Create a nginx vhost enabled directory...\t"
          mkdir -p "${NGINX_VHOST_SITE_ENABLED_DIR}"
          if [ -d "${NGINX_VHOST_SITE_ENABLED_DIR}" ]; then
            echo -e "Done${NORMAL}"
          else
            echo -e "${RED}Error${NORMAL}"
          fi
        fi

	echo -en "${GREEN}Create nginx config file...\t\t\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/nginx_virtual_host.template" "${NGINX_VHOST_DIR}/${SITENAME}.vhost"
	if [ -e "${NGINX_VHOST_DIR}/${SITENAME}.vhost" ]
	then
		sed -i "s@!SERVERIP!@${SERVERIP}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		sed -i "s@!SERVERPORT!@${SERVERPORT}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		sed -i "s@!SITENAME!@${SITENAME}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		sed -i "s@!SITEDIR!@${SITEDIR}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		sed -i "s@!PHPFPMSOCKDIR!@${PHP_FPM_SOCK_DIR}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		sed -i "s@!USERLOGINNAME!@${USERLOGINNAME}@g" ${NGINX_VHOST_DIR}/${SITENAME}.vhost
		echo -e "Done${NORMAL}"
		echo -en "${GREEN}Activate nginx config file...\t\t\t"
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

	echo -en "${GREEN}Create php-fpm config file ${USERLOGINNAME}.conf...\t\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/php_fpm.conf.template" "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf"
	if [ -e "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" ]
	then
		sed -i "s@!SITEDIR!@${SITEDIR}@g" ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
		sed -i "s@!USERLOGINNAME!@${USERLOGINNAME}@g" ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
		sed -i "s@!GROUPNAME!@${GROUPNAME}@g" ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
		sed -i "s@!PHPFPMSOCKDIR!@${PHP_FPM_SOCK_DIR}@g" ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
		echo -e "Done${NORMAL}"
		phpfpm_reload ${USERLOGINNAME}
        else
                echo -e "${RED}Error${NORMAL}"
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


function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
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

OS_INIT_SYSTEM=$(strings /sbin/init | awk 'match($0, /(upstart|systemd|sysvinit)/) { print toupper(substr($0, RSTART, RLENGTH));exit; }')

echo -en "${GREEN}Detecting ${os} distrib\t"
if [ -f /etc/debian_version ]; then
	DEBIAN_VERSION=$(sed 's/\..*//' /etc/debian_version)
	OS_DISTRIB="Debian"
	echo -e "${OS_DISTRIB}${NORMAL}"
	if [ ${DEBIAN_VERSION} == '9' ]; then
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
	elif [ ${DEBIAN_VERSION} == '8' ]; then
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
	if [ ${ORACLE_VERSION} == '6.9' ]; then
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
	elif [ ${ORACLE_VERSION} == '7.4' ]; then
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

if [ ! -d "${NGINX_DIR}" ]; then
	echo -e "${RED}Error: nginx directory ${NGINX_DIR} not found.${NORMAL}"
	exit 1;
fi

echo -en "${GREEN}Detecting nginx owner\t"
if user_exists ${NGINX_USER}; then
	echo -e "Found ${NGINX_USER}${NORMAL}"
else
	if user_exists nginx; then
		NGINX_USER=nginx
		echo -e "Found ${NGINX_USER}${NORMAL}"
	else
		echo -e "${RED}Err${NORMAL}"
		echo -e "${RED}Error: nginx owner not found.${NORMAL}"
		echo -e "${CYAN}See parameter 'user' in file '"${NGINX_DIR}/nginx.conf"'${NORMAL}"
		exit 1;
	fi
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
	SERVERIP=$(cat ${NGINX_DIR}/settings.conf | grep SERVERIP | cut -d "=" -f 2)
	SERVERPORT=$(cat ${NGINX_DIR}/settings.conf | grep SERVERPORT | cut -d "=" -f 2)
	AUTO_DETECT_SERVERIP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')
	if valid_ip ${AUTO_DETECT_SERVERIP}; then
		if [ "${SERVERIP}" != "${AUTO_DETECT_SERVERIP}" ]; then
			SERVERIP=${AUTO_DETECT_SERVERIP}
		fi
		SETTINGS_SERVERIP=$(cat ${NGINX_DIR}/settings.conf | grep SERVERIP | cut -d "=" -f 2)
		if [ "${SETTINGS_SERVERIP}" != "10.10.10.3" ]; then
			SERVERIP=${SETTINGS_SERVERIP}
		fi
	fi
	if [ -z "${SERVERIP}" ]; then
		SERVERIP=${DEFAULT_SERVERIP}
	fi
fi
echo -e "${GREEN}Set nginx vhost ip:\t${SERVERIP}:${SERVERPORT}${NORMAL}"

if [ "${SITENAME}" != "" ]
then
	if [ -d "${SITEDIR}" ]
	then
	  echo -e "${RED}Error: Site directory ${SITEDIR} alredy exist.${NORMAL}"
	  exit 1;
	fi
	create_linux_user_and_group "${USERLOGINNAME}" "${GROUPNAME}"
	create_site_dir "${SITENAME}" "${SITEDIR}" "${USERLOGINNAME}" "${GROUPNAME}"
        create_phpfpm_conf "${SITEDIR}" "${USERLOGINNAME}" "${GROUPNAME}"
        create_nginx_vhost "${SITENAME}" "${SITEDIR}" "${USERLOGINNAME}"
else
        usage
        exit 1;
fi
