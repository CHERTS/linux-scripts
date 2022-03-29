#!/usr/bin/env bash
#
# Program: Added nginx + php-fpm vhosts <nginx-create-vhost.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.4.9
# 
# Example: ./nginx-create-vhost.sh -d "domain.com"
# or
# Example: ./nginx-create-vhost.sh -s "/var/www/domain.com" -d "domain.com"
# or
# Example: ./nginx-create-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1
#
# Revision History:
#
#  Version 1.4.9
#    Added php version vars (PHP_DEFAULT_VERSION_DEBIAN9 and PHP_DEFAULT_VERSION_DEBIAN10) in Debian systems
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
#    Added template function
#
#  Version 1.0
#    Initial Release
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

DEFAULT_SERVERIP="10.10.10.2"
DEFAULT_SERVERPORT="80"
NGINX_USER=nginx
NGINX_DIR=/etc/nginx
NGINX_SSL_DIR=/etc/nginx/ssl
NGINX_VHOST_DIR=/etc/nginx/sites-available
NGINX_VHOST_SITE_ENABLED_DIR=/etc/nginx/sites-enabled
NGINX_TEMPLATE="nginx_virtual_host.template"
PHP_FPM_POOL_DIR=/etc/php5/fpm/pool.d
PHP_FPM_SOCK_DIR=/var/lib/php5-fpm
PHP_FPM_RUN_SCRIPT=/etc/init.d/php5-fpm
PHP_DEFAULT_VERSION_DEBIAN10=7.3
PHP_DEFAULT_VERSION_DEBIAN9=7.0
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
	type "${1}" &> /dev/null ;
}

user_in_group()
{
	groups "${1}" | grep "$2" >/dev/null 2>&1
}

user_exists() {
	id -u "${1}" &> /dev/null;
}

create_linux_user_and_group ()
{
	local USERLOGINNAME="${1}"
	local GROUPNAME="${2}"
	local USER_CNT=1
	local GROUP_CNT=1

	echo -en "${GREEN}Adding new user '${USERLOGINNAME}'...\t\t\t"
	USER_CNT=$(getent passwd | grep -c "${USERLOGINNAME}")
	if [ ${USER_CNT} -gt 0 ]; then
		echo -e "${RED}Error, user '${USERLOGINNAME}' already exists${NORMAL}"
		exit 1;
	fi
	useradd -d "${SITEDIR}" -s /bin/false "${USERLOGINNAME}" >/dev/null 2>&1
	USER_CNT=$(getent passwd | grep -c "${USERLOGINNAME}")
	if [ ${USER_CNT} -ne 0 ]; then
		echo -e "Done${NORMAL}"
		NEXTWEBUSER_NUM=$(cat "${NGINX_DIR}/settings.conf" | grep NEXTWEBUSER | cut -d "=" -f 2 | sed s/[^0-9]//g)
		NEXTWEBUSER_NAME=$(cat "${NGINX_DIR}/settings.conf" | grep NEXTWEBUSER | cut -d "=" -f 2 | sed s/[^a-zA-Z]//g)
		NEXTWEBUSER_NUM_INC=$(expr ${NEXTWEBUSER_NUM} + 1)
		sed -i "s@${USERLOGINNAME}@${NEXTWEBUSER_NAME}${NEXTWEBUSER_NUM_INC}@g" "${NGINX_DIR}/settings.conf"
	else
		echo -e "${RED}Error, the user ${USERLOGINNAME} does not exist${NORMAL}"
		exit 1;
	fi

	echo -en "${GREEN}Adding new group ${GROUPNAME}...\t\t\t"
	GROUP_CNT=$(getent group | grep -c "${GROUPNAME}")
	if [ ${GROUP_CNT} -gt 0 ]; then
	    echo -e "${CYAN}Warning, group ${GROUPNAME} already exists${NORMAL}"
	else
		if [[ "${OS_DISTRIB}" = "RedHat" ]]; then
			groupadd "${GROUPNAME}" >/dev/null 2>&1
		else
			addgroup "${GROUPNAME}" >/dev/null 2>&1
		fi
		GROUP_CNT=$(getent group | grep -c "${GROUPNAME}")
		if [ ${GROUP_CNT} -ne 0 ]; then
			echo -e "Done${NORMAL}"
			local NEXTWEBGROUP_NUM=$(cat "${NGINX_DIR}/settings.conf" | grep NEXTWEBGROUP | cut -d "=" -f 2 | sed s/[^0-9]//g)
			local NEXTWEBGROUP_NAME=$(cat "${NGINX_DIR}/settings.conf" | grep NEXTWEBGROUP | cut -d "=" -f 2 | sed s/[^a-zA-Z]//g)
			NEXTWEBGROUP_NUM_INC=$(expr ${NEXTWEBGROUP_NUM} + 1)
			sed -i "s@${GROUPNAME}@${NEXTWEBGROUP_NAME}${NEXTWEBGROUP_NUM_INC}@g" "${NGINX_DIR}/settings.conf" >/dev/null 2>&1
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

	echo -en "${GREEN}Adding user ${NGINX_USER} to group ${GROUPNAME}...\t"
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
	cp -- "${DEFAULT_TEMPLATE_DIR}/index.html.template" "${SITEDIR}/web/index.html" >/dev/null 2>&1
	if [ -f "${SITEDIR}/web/index.html" ]
	then
		sed -i "s@!SITENAME!@${SITENAME}@g" "${SITEDIR}/web/index.html"
		echo -e "Done${NORMAL}"
	else
		echo -e "${RED}Error${NORMAL}"
	fi
}

create_robots_file ()
{
	local SITEDIR=${1}

	echo -en "${GREEN}Create robots.txt...\t\t\t\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/robots.txt.template" "${SITEDIR}/web/robots.txt" >/dev/null 2>&1
	if [ -f "${SITEDIR}/web/robots.txt" ]
	then
		echo -e "Done${NORMAL}"
	else
		echo -e "${RED}Error${NORMAL}"
	fi
}

create_logrotate ()
{
	local SITEDIR=${1}
	local USERLOGINNAME=${2}

	echo -en "${GREEN}Create logrotate rule...\t\t\t"

	if [[ "${OS_DISTRIB}" = "RedHat" ]]; then
cat <<EOT > /etc/logrotate.d/${USERLOGINNAME}.tmp
${SITEDIR}/log/access.log ${SITEDIR}/log/error.log {
    create 0644 ${NGINX_USER} root
    daily
    rotate 10
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f /var/run/nginx.pid ] || kill -USR1 \`cat /var/run/nginx.pid\`
        nginx -t >/dev/null 2>&1 && nginx -s reload >/dev/null 2>&1
    endscript
}
EOT
	else
cat <<EOT > /etc/logrotate.d/${USERLOGINNAME}.tmp
${SITEDIR}/log/access.log ${SITEDIR}/log/error.log {
    create 0644 ${NGINX_USER} root
    daily
    rotate 10
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f /var/run/nginx.pid ] || kill -USR1 \`cat /var/run/nginx.pid\`
    endscript
}
EOT
fi

	if [ $(echo $?) != 0 ]; then
		echo -e "${RED}Error: Failed to create /etc/logrotate.d/${USERLOGINNAME}.tmp.${NORMAL}"
	else
		mv /etc/logrotate.d/${USERLOGINNAME}.tmp /etc/logrotate.d/${USERLOGINNAME} 2>/dev/null
		if [ $(echo $?) != 0 ]; then
			echo -e "${RED}Error: Failed to re-create /etc/logrotate.d/${USERLOGINNAME}.${NORMAL}"
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
	${NGINX_BIN} -t > "/tmp/nginx_configtest" 2>&1
	local NGX_CONFIG_TEST_RESULT=$(grep successful "/tmp/nginx_configtest")
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

create_site_dir ()
{
	local SITENAME=${1}
	local SITEDIR=${2}
	local USERLOGINNAME=${3}
	local GROUPNAME=${4}

	echo -en "${GREEN}Create a home directory...\t\t\t"
	mkdir -p "${SITEDIR}" >/dev/null 2>&1
	if [ -d "${SITEDIR}" ]; then
		echo -e "Done${NORMAL}"
	else
		echo -e "${RED}Error${NORMAL}"
	fi

	echo -en "${GREEN}Create web,log,tmp,private directory...\t\t"
	mkdir -p "${SITEDIR}/web" >/dev/null 2>&1
	mkdir -p "${SITEDIR}/log" >/dev/null 2>&1
	mkdir -p "${SITEDIR}/private" >/dev/null 2>&1
	mkdir -p "${SITEDIR}/tmp" >/dev/null 2>&1
	if [ -d "${SITEDIR}/web" ]; then
		echo -e "Done${NORMAL}"
		if [ ${USE_REDIRECT} -eq 0 ]; then
			create_simple_index_page "${SITEDIR}" "${SITENAME}"
			create_robots_file "${SITEDIR}"
		fi
	else
		echo -e "${RED}Error${NORMAL}"
	fi

	echo -en "${GREEN}Set permition to directory...\t\t\t"
	chmod -R 755 "${SITEDIR}" >/dev/null 2>&1
	chmod -R 770 "${SITEDIR}/tmp" >/dev/null 2>&1
	chmod -R 755 "${SITEDIR}/web" >/dev/null 2>&1
	chmod -R 710 "${SITEDIR}/private" >/dev/null 2>&1
	chown -R ${USERLOGINNAME}:${GROUPNAME} "${SITEDIR}"
	chown root:root "${SITEDIR}" >/dev/null 2>&1
	chown root:root "${SITEDIR}/log" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "Done${NORMAL}"
	else
		echo -e "Error${NORMAL}"
	fi

	echo -en "${GREEN}Set protected attribute to directory...\t\t"
	chattr +a "${SITEDIR}" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "Done${NORMAL}"
	else
        	echo -e "Error${NORMAL}"
	fi
}

create_nginx_vhost ()
{
	local SITENAME=${1}
	local SITEDIR=${2}
	local USERLOGINNAME=${3}

	if [ ! -d "${NGINX_VHOST_DIR}" ]; then
		echo -e "${CYAN}Warning: Directory ${NGINX_VHOST_DIR} not exist.${NORMAL}"
		echo -en "${GREEN}Create a nginx vhost directory...\t\t"
		mkdir -p "${NGINX_VHOST_DIR}" >/dev/null 2>&1
		if [ -d "${NGINX_VHOST_DIR}" ]; then
			echo -e "Done${NORMAL}"
		else
			echo -e "${RED}Error${NORMAL}"
		fi
	fi

	if [ ! -d "${NGINX_VHOST_SITE_ENABLED_DIR}" ]; then
		echo -e "${CYAN}Warning: Directory ${NGINX_VHOST_SITE_ENABLED_DIR} not exist.${NORMAL}"
		echo -en "${GREEN}Create a nginx vhost enabled directory...\t"
		mkdir -p "${NGINX_VHOST_SITE_ENABLED_DIR}" >/dev/null 2>&1
		if [ -d "${NGINX_VHOST_SITE_ENABLED_DIR}" ]; then
			echo -e "Done${NORMAL}"
		else
			echo -e "${RED}Error${NORMAL}"
		fi
	fi

	echo -en "${GREEN}Create nginx config file...\t\t\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/${NGINX_TEMPLATE}" "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
	if [ -f "${NGINX_VHOST_DIR}/${SITENAME}.vhost" ]; then
		sed -i "s@!SERVERIP!@${SERVERIP}@g" "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
		sed -i "s@!SERVERPORT!@${SERVERPORT}@g" "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
		sed -i "s@!SITENAME!@${SITENAME}@g" "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
		sed -i "s@!SITEDIR!@${SITEDIR}@g" "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
		sed -i "s@!PHPFPMSOCKDIR!@${PHP_FPM_SOCK_DIR}@g" "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
		sed -i "s@!USERLOGINNAME!@${USERLOGINNAME}@g" "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
		if [ ${USE_REDIRECT} -eq 1 ]; then
			sed -i "s@!REDIRECTSERVER!@${REDIRECTSERVER}@g" "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
			sed -i "s@!REDIRECTPORT!@${REDIRECTPORT}@g" "${NGINX_VHOST_DIR}/${SITENAME}.vhost" >/dev/null 2>&1
		fi
		echo -e "Done${NORMAL}"
		echo -en "${GREEN}Activate nginx config file...\t\t\t"
		ln -s ${NGINX_VHOST_DIR}/${SITENAME}.vhost ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost
		local LINKTEST=$(readlink ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost)
		if [ -n "${LINKTEST}" ]; then
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

	if [ ! -d "${PHP_FPM_POOL_DIR}" ]; then
		echo -e "${CYAN}Warning: Directory ${PHP_FPM_POOL_DIR} not exist.${NORMAL}"
		echo -en "${GREEN}Create a php-fpm pool directory ${PHP_FPM_POOL_DIR}...\t"
		mkdir -p "${PHP_FPM_POOL_DIR}" >/dev/null 2>&1
		if [ -d "${PHP_FPM_POOL_DIR}" ]; then
			echo -e "Done${NORMAL}"
			chmod 755 "${PHP_FPM_POOL_DIR}" >/dev/null 2>&1
		else
			echo -e "${RED}Error${NORMAL}"
		fi
	fi

	if [ ! -d "${PHP_FPM_SOCK_DIR}" ]; then
		echo -e "${CYAN}Warning: Directory ${PHP_FPM_SOCK_DIR} not exist.${NORMAL}"
		echo -en "${GREEN}Create a php-fpm socket directory ${PHP_FPM_SOCK_DIR}...\t"
		mkdir -p "${PHP_FPM_SOCK_DIR}" >/dev/null 2>&1
		if [ -d "${PHP_FPM_SOCK_DIR}" ]; then
			echo -e "Done${NORMAL}"
			chmod 755 "${PHP_FPM_SOCK_DIR}" >/dev/null 2>&1
		else
			echo -e "${RED}Error${NORMAL}"
		fi
	fi

	echo -en "${GREEN}Create php-fpm config file ${USERLOGINNAME}.conf...\t\t"
	cp -- "${DEFAULT_TEMPLATE_DIR}/php_fpm.conf.template" "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" >/dev/null 2>&1
	if [ -f "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" ]; then
		sed -i "s@!SITEDIR!@${SITEDIR}@g" "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" >/dev/null 2>&1
		sed -i "s@!USERLOGINNAME!@${USERLOGINNAME}@g" "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" >/dev/null 2>&1
		sed -i "s@!GROUPNAME!@${GROUPNAME}@g" "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" >/dev/null 2>&1
		sed -i "s@!PHPFPMSOCKDIR!@${PHP_FPM_SOCK_DIR}@g" "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" >/dev/null 2>&1
		echo -e "Done${NORMAL}"
		phpfpm_reload ${USERLOGINNAME}
	else
		echo -e "${RED}Error${NORMAL}"
	fi
}

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
		echo -en "${GREEN}Detecting your php-fpm\t"
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
			if command_exists php-fpm${PHP_DEFAULT_VERSION_DEBIAN10} ; then
				echo -e "Found php-fpm${PHP_DEFAULT_VERSION_DEBIAN10}${NORMAL}"
				PHP_FPM_BIN=$(which php-fpm${PHP_DEFAULT_VERSION_DEBIAN10})
				PHP_FPM_POOL_DIR=/etc/php/${PHP_DEFAULT_VERSION_DEBIAN10}/fpm/pool.d
				PHP_FPM_SOCK_DIR=/run/php
				if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
					PHP_FPM_RUN_SCRIPT="php${PHP_DEFAULT_VERSION_DEBIAN10}-fpm"
				else
					if [ -f "/etc/init.d/php${PHP_DEFAULT_VERSION_DEBIAN10}-fpm" ]; then
						PHP_FPM_RUN_SCRIPT=/etc/init.d/php${PHP_DEFAULT_VERSION_DEBIAN10}-fpm
					else
						echo -e "${RED}Error: php${PHP_DEFAULT_VERSION_DEBIAN10}-fpm init script not found.${NORMAL}"
						exit 1;
					fi
				fi
			else
				echo -e "${RED}Error: php-fpm${PHP_DEFAULT_VERSION_DEBIAN10} not found.${NORMAL}"
				exit 1;
			fi
		elif [[ "${DEBIAN_VERSION}" = "9" ]]; then
			echo -en "${GREEN}Detecting your php-fpm\t\t"
			if command_exists php-fpm${PHP_DEFAULT_VERSION_DEBIAN9} ; then
				echo -e "Found php-fpm${PHP_DEFAULT_VERSION_DEBIAN9}${NORMAL}"
				PHP_FPM_BIN=$(which php-fpm${PHP_DEFAULT_VERSION_DEBIAN9})
				PHP_FPM_POOL_DIR=/etc/php/${PHP_DEFAULT_VERSION_DEBIAN9}/fpm/pool.d
				PHP_FPM_SOCK_DIR=/run/php
				if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
					PHP_FPM_RUN_SCRIPT="php${PHP_DEFAULT_VERSION_DEBIAN9}-fpm"
				else
					if [ -f "/etc/init.d/php${PHP_DEFAULT_VERSION_DEBIAN9}-fpm" ]; then
						PHP_FPM_RUN_SCRIPT=/etc/init.d/php${PHP_DEFAULT_VERSION_DEBIAN9}-fpm
					else
						echo -e "${RED}Error: php${PHP_DEFAULT_VERSION_DEBIAN9}-fpm init script not found.${NORMAL}"
						exit 1;
					fi
				fi
			else
				echo -e "${RED}Error: php-fpm${PHP_DEFAULT_VERSION_DEBIAN9} not found.${NORMAL}"
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

if [ ! -d "${NGINX_DIR}" ]; then
	echo -e "${RED}Error: nginx directory '${NGINX_DIR}' not found.${NORMAL}"
	exit 1;
fi

if [ ! -f "${NGINX_DIR}/nginx.conf" ]; then
	echo -e "${RED}Error: nginx config file '${NGINX_DIR}/nginx.conf' not found.${NORMAL}"
	exit 1;
fi

if [ ! -d "${NGINX_SSL_DIR}" ]; then
	mkdir "${NGINX_SSL_DIR}" 2>/dev/null
fi

echo -en "${GREEN}Detecting nginx owner\t\t"
NGINX_OWNER=$(cat "${NGINX_DIR}/nginx.conf" | grep -E '^user' | awk -F' ' '{print $2}' | tr -d ';')
if [ -n "${NGINX_OWNER}" ]; then
	if user_exists ${NGINX_OWNER}; then
		NGINX_USER=${NGINX_OWNER}
		echo -e "${NGINX_USER}${NORMAL}"
	else
		if user_exists ${NGINX_USER}; then
			echo -e "${NGINX_USER}${NORMAL}"
		else
			echo -e "${RED}Err${NORMAL}"
			echo -e "${RED}Error: standart nginx owner '${NGINX_USER}' not found.${NORMAL}"
			echo -e "${CYAN}Check parameter 'user' in file '"${NGINX_DIR}/nginx.conf"'${NORMAL}"
			exit 1;
		fi
	fi
else
	echo -e "${RED}Err${NORMAL}"
	echo -e "${RED}Error: nginx owner not found.${NORMAL}"
	echo -e "${CYAN}Check parameter 'user' in file '"${NGINX_DIR}/nginx.conf"'${NORMAL}"
	exit 1;
fi

if [ ! -e "${NGINX_DIR}/settings.conf" ]; then
	echo -e "${CYAN}Warning: Main settings file '${NGINX_DIR}/settings.conf' not found.${NORMAL}"
	echo -en "${GREEN}Copy settings.conf to ${NGINX_DIR}...\t"
	if [ -f "${CUR_DIR}/settings.conf" ]; then
		cp -- "${CUR_DIR}/settings.conf" "${NGINX_DIR}" >/dev/null 2>&1
	else
		(cat <<-EOF
		SERVERIP=10.10.10.2
		SERVERPORT=80
		NEXTWEBUSER=web1
		NEXTWEBGROUP=client1
		EOF
		) > "${NGINX_DIR}/settings.conf"
	fi
	if [ -f "${NGINX_DIR}/settings.conf" ]; then
		echo -e "Done${NORMAL}"
	else
		echo -e "${RED}Error: Main settings file ${NGINX_DIR}/settings.conf not found.${NORMAL}"
		exit 1;
	fi
fi

if [ ! -d "${DEFAULT_TEMPLATE_DIR}" ]; then
	echo -en "${GREEN}Copy default template directory...\t"
	if [ -d "${CUR_DIR}/template/" ]; then
		cp -R -- "${CUR_DIR}/template/" "${NGINX_DIR}" >/dev/null 2>&1
		if [ -d "${DEFAULT_TEMPLATE_DIR}" ]; then
			echo -e "Done${NORMAL}"
		else
			echo -e "${RED}Error: Failed to create the '${DEFAULT_TEMPLATE_DIR}' directory.${NORMAL}"
			exit 1;
		fi
	else
		echo -e "${RED}Error: Directory '${CUR_DIR}/template' not found.${NORMAL}"
		exit 1;
	fi
fi

if [ -z "${SITEDIR}" ]; then
	SITEDIR=${DEFAULT_SITE_DIR}/${SITENAME}
fi

USE_REDIRECT=$(echo "${NGINX_TEMPLATE}" | grep -c "redirect")

if [ -z "${USERLOGINNAME}" ]; then
	USERLOGINNAME=$(cat "${NGINX_DIR}/settings.conf" | grep NEXTWEBUSER | cut -d "=" -f 2)
	if [ "${USERLOGINNAME}" = "" ]; then
		echo -e "${RED}Error: In file '${NGINX_DIR}/settings.conf' not found parameter NEXTWEBUSER.${NORMAL}"
		usage
		exit 1;
	fi
fi
echo -e "${GREEN}Set new username\t\t${USERLOGINNAME}${NORMAL}"

if [ -z "${GROUPNAME}" ]; then
	GROUPNAME=$(cat "${NGINX_DIR}/settings.conf" | grep NEXTWEBGROUP | cut -d "=" -f 2)
	if [ -z "${GROUPNAME}" ]; then
		echo -e "${RED}Error: In file '${NGINX_DIR}/settings.conf' not found parameter NEXTWEBGROUP.${NORMAL}"
		usage
		exit 1;
	fi
fi
echo -e "${GREEN}Set new groupname\t\t${GROUPNAME}${NORMAL}"

if [ -z "${SITENAME}" ]; then
	echo -e "${RED}Error: You must enter a domain name.${NORMAL}"
	usage
	exit 1;
fi

# check the domain is roughly valid!
PATTERN="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,6}$"
if [[ "${SITENAME}" =~ $PATTERN ]]; then
	DOMAIN=$(echo ${SITENAME} | tr '[A-Z]' '[a-z]')
	echo -e "${GREEN}Set nginx hostname:\t\t${SITENAME}${NORMAL}"
else
	echo -e "${RED}Error: Invalid domain name.${NORMAL}"
	exit 1
fi

if [ -f "${NGINX_DIR}/settings.conf" ]; then
	SERVERIP=$(cat "${NGINX_DIR}/settings.conf" | grep SERVERIP | cut -d "=" -f 2)
	SERVERPORT=$(cat "${NGINX_DIR}/settings.conf" | grep SERVERPORT | cut -d "=" -f 2)
	REDIRECTSERVER=$(cat "${NGINX_DIR}/settings.conf" | grep REDIRECTSERVER | cut -d "=" -f 2)
	REDIRECTPORT=$(cat "${NGINX_DIR}/settings.conf" | grep REDIRECTPORT | cut -d "=" -f 2)
	AUTO_DETECT_SERVERIP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')
	if [ -n "${AUTO_DETECT_SERVERIP}" ]; then
		if valid_ip ${AUTO_DETECT_SERVERIP}; then
			if [ "${SERVERIP}" != "${AUTO_DETECT_SERVERIP}" ]; then
				SERVERIP=${AUTO_DETECT_SERVERIP}
			fi
			SETTINGS_SERVERIP=$(cat "${NGINX_DIR}/settings.conf" | grep SERVERIP | cut -d "=" -f 2)
			if [ "${SETTINGS_SERVERIP}" != "10.10.10.2" ]; then
				SERVERIP=${SETTINGS_SERVERIP}
			fi
		fi
	fi
	if [ -z "${SERVERIP}" ]; then
		SERVERIP=${DEFAULT_SERVERIP}
	fi
fi
echo -e "${GREEN}Set nginx vhost ip\t\t${SERVERIP}${NORMAL}"
echo -e "${GREEN}Set nginx vhost port\t\t${SERVERPORT}${NORMAL}"

if [ -n "${SITENAME}" ]; then
	if [ -d "${SITEDIR}" ]; then
		echo -e "${RED}Error: Site directory ${SITEDIR} alredy exist.${NORMAL}"
		exit 1;
	fi
	create_linux_user_and_group "${USERLOGINNAME}" "${GROUPNAME}"
	create_site_dir "${SITENAME}" "${SITEDIR}" "${USERLOGINNAME}" "${GROUPNAME}"
	if [ ${USE_REDIRECT} -eq 0 ]; then
		create_phpfpm_conf "${SITEDIR}" "${USERLOGINNAME}" "${GROUPNAME}"
	fi
	create_nginx_vhost "${SITENAME}" "${SITEDIR}" "${USERLOGINNAME}"
	create_logrotate "${SITEDIR}" "${USERLOGINNAME}"
else
	usage
	exit 1;
fi
