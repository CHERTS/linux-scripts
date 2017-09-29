#!/usr/bin/env bash

#
# Program: Creating a self-signed SSL certificate for Monit <monit-create-ssl>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.0
#
# Revision History:
#
#  Version 1.0
#    Initial Release
#

set -e

monit_ssl_dir="/etc/monit/ssl"
now=$(date +%Y%m%d%H%M%S)
cert_cn="127.0.0.1"
cert_o="MyCompany Ltd."
cert_l="Moscow"
cert_c="RU"

command_exists ()
{
    type "$1" &> /dev/null ;
}

if ! command_exists monit ; then
    echo "ERROR: monit not installed!"
    if [ -f /etc/debian_version ]; then
        DEBIAN_VERSION=$(sed 's/\..*//' /etc/debian_version)
        if [ ${DEBIAN_VERSION} == '9' ]; then
            echo "NOTICE: Please, run: apt-get install monit"
        elif [ ${DEBIAN_VERSION} == '8' ]; then
            echo "NOTICE: Please, run: apt-get install monit"
        elif [ ${DEBIAN_VERSION} == '7' ]; then
            echo "NOTICE: Please, run: apt-get install monit"
        else
            echo "ERROR: Unknown Debian version"
            exit 1;
        fi
    else
        echo "ERROR: Unknown Linux version"
        exit 1;
    fi
    exit 1;
else
	if ! command_exists openssl ; then
	    	echo "ERROR: openssl not installed!"
		exit 1;
	else
		openssl_bin=`which openssl`
	fi
fi

if [ ! -d "${monit_ssl_dir}" ]; then
	echo -n "Create ${monit_ssl_dir} directory... "
	mkdir -p "${monit_ssl_dir}"
	if [ -d "${monit_ssl_dir}" ]; then
		echo "Done"
	else
		echo "Error"
		exit 1;
	fi
fi

if [ -f "${monit_ssl_dir}/monit.cnf" ]; then
	if [ -f "${monit_ssl_dir}/monit.pem" ]; then
		mv "${monit_ssl_dir}/monit.pem" "${monit_ssl_dir}/monit.pem.${now}.bak"
	fi
	${openssl_bin} req -new -x509 -sha256 -days 3650 -nodes -config "${monit_ssl_dir}/monit.cnf" -out "${monit_ssl_dir}/monit.pem" -keyout "${monit_ssl_dir}/monit.pem" -subj "/C=${cert_c}/L=${cert_l}/O=${cert_o}/CN=${cert_cn}"
	${openssl_bin} gendh 512 >> "${monit_ssl_dir}/monit.pem"
	if [ -f "${monit_ssl_dir}/monit.pem" ]; then
		${openssl_bin} x509 -subject -dates -fingerprint -noout -in "${monit_ssl_dir}/monit.pem"
		chown root:root "${monit_ssl_dir}/monit.pem"
		chmod 700 "${monit_ssl_dir}/monit.pem"
		echo "Monit SSL certificate info:"
		${openssl_bin} x509 -in ${monit_ssl_dir}/monit.pem -noout -text -purpose | more
	fi
else
	echo "ERROR: File ${monit_ssl_dir}/monit.cnf not found."
fi
