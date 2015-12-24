#!/bin/bash
#
# Program: Remove nginx + php5-fpm vhosts <nginx-remove-vhost.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.0
# 
# Example: ./nginx-remove-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1
#
# Revision History:
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

delete_linux_user_and_group ()
{
	USERLOGINNAME=${1}
	GROUPNAME=${2}

	echo -n "Delete group ${GROUPNAME}... "
	ret=false
	getent group ${GROUPNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
		groupdel ${GROUPNAME} >/dev/null 2>&1
	else
	    echo "Error, group ${GROUPNAME} not found"
	    exit 1;
	fi
	ret=false
	getent group ${GROUPNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo "Error, group ${GROUPNAME} not deleted"
	    exit 1;
	else
	    echo "Done"
	fi

	echo -n "Delete user ${USERLOGINNAME}... "
	ret=false
	getent passwd ${USERLOGINNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
		userdel ${USERLOGINNAME} >/dev/null 2>&1
	else
	    echo "Error, user ${USERLOGINNAME} not found"
	    exit 1;
	fi
	ret=false
	getent passwd ${USERLOGINNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo "Error, user ${USERLOGINNAME} not deleted"
	    exit 1;
	else
	    echo "Done"
	fi

}

delete_nginx_vhost ()
{
	SITENAME=${1}

	if [ ! -d ${NGINX_VHOST_DIR} ]
	then
	  echo "Error: Directory ${NGINX_VHOST_DIR} not exist, please, check directory."
	  exit 1;
	fi

	echo -n "Deactivate nginx config file... "
	linktest=`readlink ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost`
	if [ -n ${linktest} ]
	then
		rm -f ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost
		linktest=`readlink ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost`
		if [ -n ${linktest} ]; then
			echo "Done"
		else
			echo "Error"
		fi
	else
		echo "Error, link ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost not exist"
	fi
	echo -n "Delete nginx config file ${USERLOGINNAME}.conf... "
	if [ -f ${NGINX_VHOST_DIR}/${SITENAME}.conf ]; then
		rm -f ${NGINX_VHOST_DIR}/${SITENAME}.conf
		if [ ! -f ${NGINX_VHOST_DIR}/${SITENAME}.conf ]; then
			echo "Done"
			nginx_reload
		else
			echo "Error"
		fi
	else
		echo "Error, file ${NGINX_VHOST_DIR}/${SITENAME}.vhost not exist"
	fi

}

delete_phpfpm_conf ()
{
	USERLOGINNAME=${1}
	GROUPNAME=${2}

	if [ ! -d ${PHP_FPM_POOL_DIR} ]
	then
	  echo "Error: Directory ${PHP_FPM_POOL_DIR} not exist, please, check directory."
	  exit 1;
	fi

	if [ ! -d ${PHP_FPM_SOCK_DIR} ]
	then
	  echo "Error: Directory ${PHP_FPM_SOCK_DIR} not exist, please, check directory."
	  exit 1;
	fi

	if [ -f ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf ]
	then
		echo -n "Delete php5-fpm config file ${USERLOGINNAME}.conf... "
		rm -f ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
		if [ ! -f ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf ]; then
			echo "Done"
			echo "Reload php5-fpm..."
			${PHP_FPM_RUN_SCRIPT} reload
			delete_linux_user_and_group "${USERLOGINNAME}" "${GROUPNAME}"
		else
			echo "Error"
		fi
	else
		echo "Error: php5-fpm config file ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf not found."
		delete_linux_user_and_group "${USERLOGINNAME}" "${GROUPNAME}"
	fi
}

nginx_reload ()
{
	echo -n "Nginx configtest... "
	/etc/init.d/nginx configtest > /dev/null
	if [ $? -gt 0 ]; then
	    echo "Error"
	    exit 1;
	else
	    echo "Done"
	    echo "Reload nginx..."
	    /etc/init.d/nginx reload
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
	echo "Error: You must enter a user name."
	usage
	exit 1;
fi

if [ "${GROUPNAME}" == "" ]; then
	echo "Error: You must enter a group name."
	usage
	exit 1;
fi

if [ "${SITENAME}" != "" ]
then
	if [ ! -d ${SITEDIR} ]
	then
	  echo "Error: Site directory ${SITEDIR} not found."
	  exit 1;
	fi
        delete_phpfpm_conf "${USERLOGINNAME}" "${GROUPNAME}"
        delete_nginx_vhost "${SITENAME}"
	if [ -d ${SITEDIR} ]
	then
		echo -n "Delete site directory ${SITEDIR}... "
		rm -rf ${SITEDIR}
		if [ ! -d ${SITEDIR} ]; then
			echo "Done"
		else
			echo "Error: Site directory ${SITEDIR} not deleted."
			exit 1;
		fi
	fi
else
        usage
        exit 1;
fi
