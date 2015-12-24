#!/bin/bash
#
# Program: Added nginx + php5-fpm vhosts <nginx-create-vhost.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.0
# 
# Example: ./nginx-create-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1
#
# Revision History:
#
#  Version 1.0
#    Initial Release
#

SERVERIP="10.0.0.1"
NGINX_VHOST_DIR=/etc/nginx/sites-available
NGINX_VHOST_SITE_ENABLED_DIR=/etc/nginx/sites-enabled
PHP_FPM_POOL_DIR=/etc/php5/fpm/pool.d
PHP_FPM_SOCK_DIR=/var/lib/php5-fpm
PHP_FPM_RUN_SCRIPT=/etc/init.d/php5-fpm
DEFAULT_SITE_DIR=/var/www

user_in_group()
{
    groups $1 | grep $2>/dev/null 2>&1
}

create_linux_user_and_group ()
{
	USERLOGINNAME=${1}
	GROUPNAME=${2}

	echo -n "Adding new user ${USERLOGINNAME}... "
	ret=false
	getent passwd ${USERLOGINNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo "Error, user ${USERLOGINNAME} already exists"
	    exit 1;
	fi
	useradd -d ${SITEDIR} -s /bin/false ${USERLOGINNAME}
	ret=false
	getent passwd ${USERLOGINNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo "Done"
	else
	    echo "Error, the user ${USERLOGINNAME} does not exist"
	    exit 1;
	fi

	echo -n "Adding new group ${GROUPNAME}... "
	ret=false
	getent group ${GROUPNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo "Error, group ${GROUPNAME} already exists"
	    exit 1;
	fi
	addgroup ${GROUPNAME} >/dev/null 2>&1
	ret=false
	getent group ${GROUPNAME} >/dev/null 2>&1 && ret=true
	if $ret; then
	    echo "Done"
	else
	    echo "Error, the group ${GROUPNAME} does not exist"
	    exit 1;
	fi

	echo -n "Adding user ${USERLOGINNAME} to group ${GROUPNAME}... "
	usermod -a -G ${GROUPNAME} ${USERLOGINNAME} >/dev/null 2>&1
	if user_in_group ${USERLOGINNAME} ${GROUPNAME}; then
		echo "Done"
	else
		echo "Error: User ${USERLOGINNAME} not adding in group ${GROUPNAME}"
		exit 1;
	fi
}

create_simple_index_page ()
{
	SITEDIR=${1}
	SITENAME=${2}

	echo -n "Create ${SITEDIR}/web/index.html... "

cat <<EOF> ${SITEDIR}/web/index.html
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html>
<head>
<meta name='author' content='Administrator'>
<meta name='description' content='${SITENAME}'>
<meta name="robots" content="all">
<meta http-equiv='Content-Type' content='text/html; charset=utf-8'>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<title>${SITENAME}</title>
</head>
<body>
${SITENAME}
</body>
</html>
EOF

	if [ -f "${SITEDIR}/web/index.html" ]
	then
	  echo "Done"
	else
	  echo "Error"
	fi

}

create_robots_file ()
{
	SITEDIR=${1}

	echo -n "Create ${SITEDIR}/web/robots.txt... "

cat <<EOF> ${SITEDIR}/web/robots.txt
User-agent: *
Disallow: /
EOF

	if [ -f "${SITEDIR}/web/robots.txt" ]
	then
	  echo "Done"
	else
	  echo "Error"
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

create_nginx_vhost ()
{
	SITENAME=${1}
	SITEDIR=${2}
	USERLOGINNAME=${3}
	GROUPNAME=${4}

	if [ ! -d ${NGINX_VHOST_DIR} ]
	then
	  echo "Error: Directory ${NGINX_VHOST_DIR} not exist, please, create manual."
	  exit 1;
	fi

	echo -n "Create home directory... "
	mkdir -p ${SITEDIR}
	if [ -d ${SITEDIR} ]
	then
	  echo "Done"
	else
	  echo "Error"
	fi

	echo -n "Create web,log,tmp,private directory... "
	mkdir -p ${SITEDIR}/{web,log,private,tmp}
	if [ -d ${SITEDIR}/web ]
	then
		echo "Done"
		create_simple_index_page "${SITEDIR}" "${SITENAME}"
		create_robots_file "${SITEDIR}"
	else
		echo "Error"
	fi

	echo -n "Set permition to directory... "
	chmod -R 755 ${SITEDIR}
	chmod -R 770 ${SITEDIR}/tmp
	chmod -R 755 ${SITEDIR}/web
	chmod -R 710 ${SITEDIR}/private
	chown -R ${USERLOGINNAME}:${GROUPNAME} ${SITEDIR}/*
	chown root:root ${SITEDIR}
	chown root:root ${SITEDIR}/log
	echo "Done"

	if [ ! -f "/etc/nginx/common/server.conf" ]
	then
	  echo "Error: File /etc/nginx/common/server.conf not exist, please, create manual."
	  exit 1;
	fi
	if [ ! -f "/etc/nginx/common/rewrites.conf" ]
	then
	  echo "Error: File /etc/nginx/common/rewrites.conf not exist, please, create manual."
	  exit 1;
	fi
	if [ ! -f "/etc/nginx/common/php.conf" ]
	then
	  echo "Error: File /etc/nginx/common/php.conf not exist, please, create manual."
	  exit 1;
	fi

	echo -n "Create nginx config file ${USERLOGINNAME}.conf... "

cat <<EOF> ${NGINX_VHOST_DIR}/${SITENAME}.conf
server {
        listen ${SERVERIP}:80;
        server_name ${SITENAME} www.${SITENAME};
        root ${SITEDIR}/web;

        include /etc/nginx/common/server.conf;
        include /etc/nginx/common/rewrites.conf;

        index index.php index.html index.htm;

        error_log ${SITEDIR}/log/error.log;
        access_log ${SITEDIR}/log/access.log main;

        set $fastcgipass unix:${PHP_FPM_SOCK_DIR}/${USERLOGINNAME}.sock;

        include /etc/nginx/common/php.conf;
}
EOF

	if [ -f "${NGINX_VHOST_DIR}/${SITENAME}.conf" ]
	then
		echo "Done"
		echo -n "Activate nginx config file... "
		ln -s ${NGINX_VHOST_DIR}/${SITENAME}.vhost ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost
		linktest=`readlink ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost`
		if [ -n ${linktest} ]
		then
			echo "Done"
			nginx_reload
		else
			echo "Error, link ${NGINX_VHOST_SITE_ENABLED_DIR}/100-${SITENAME}.vhost not exist"
		fi
	else
		echo "Error, file ${NGINX_VHOST_DIR}/${SITENAME}.vhost not exist"
	fi
}

create_phpfpm_conf ()
{
	SITEDIR=${1}
	USERLOGINNAME=${2}
	GROUPNAME=${3}

	if [ ! -d ${PHP_FPM_POOL_DIR} ]
	then
	  echo "Error: Directory ${PHP_FPM_POOL_DIR} not exist, please, create manual."
	  exit 1;
	fi

	if [ ! -d ${PHP_FPM_SOCK_DIR} ]
	then
	  echo "Error: Directory ${PHP_FPM_SOCK_DIR} not exist, please, create manual."
	  exit 1;
	fi

	echo -n "Create php5-fpm config file ${USERLOGINNAME}.conf... "
cat <<EOF> ${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf
[${USERLOGINNAME}]

listen = ${PHP_FPM_SOCK_DIR}/${USERLOGINNAME}.sock
listen.owner = ${USERLOGINNAME}
listen.group = ${GROUPNAME}
listen.mode = 0660

user = ${USERLOGINNAME}
group = ${GROUPNAME}

pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 5
pm.max_requests = 500
request_terminate_timeout = 15m
request_slowlog_timeout = 5s
slowlog = ${SITEDIR}/log/php-slow.log

chdir = /

php_admin_value[open_basedir] = ${SITEDIR}/web:${SITEDIR}/private:${SITEDIR}/tmp:/usr/share/php5:/usr/share/php:/tmp:/usr/share/phpmyadmin:/etc/phpmyadmin:/var/lib/phpmyadmin
php_admin_value[session.save_path] = ${SITEDIR}/tmp
php_admin_value[upload_tmp_dir] = ${SITEDIR}/tmp

php_admin_flag[cgi.fix_pathinfo] = off
php_admin_value[error_log] = ${SITEDIR}/log/php-error.log
EOF

	if [ -f "${PHP_FPM_POOL_DIR}/${USERLOGINNAME}.conf" ]
	then
		echo "Done"
		echo "Reload php5-fpm..."
		${PHP_FPM_RUN_SCRIPT} reload
	else
		echo "Error"
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
	if [ -d ${SITEDIR} ]
	then
	  echo "Error: Site directory ${SITEDIR} alredy exist."
	  exit 1;
	fi
	create_linux_user_and_group "${USERLOGINNAME}" "${GROUPNAME}"
        create_nginx_vhost "${SITENAME}" "${SITEDIR}" "${USERLOGINNAME}" "${GROUPNAME}"
        create_phpfpm_conf "${SITEDIR}" "${USERLOGINNAME}" "${GROUPNAME}"
else
        usage
        exit 1;
fi
