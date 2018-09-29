#!/usr/bin/env bash
#
# Program: View more information about the domain <view-domain-info.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
#
# Current Version: 1.3
#
# Revision History:
#
#  Version 1.3
#    Added detect of required utilities
#
#  Version 1.2
#    Added alias detection for original domain
#
#  Version 1.1
#    Added subdomain support
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
#   Requires: whois, ip, host, dig, nslookup, grep, awk, sed, sort, tr, wc
#
# Installation:
#   Copy the shell script to a suitable location
#
# Tested platforms:
#  -- Debian 8,9 using /bin/bash
#  -- Ubuntu 16.04 using /bin/bash
#
# Usage:
#  Refer to the _usage() sub-routine, or invoke view-domain-info.sh
#  with the "-h" option.
#
# Example:
#
#  The first example will run:
#
#  $ ./view-domain-info.sh -d yandex.ru
#

_command_exists() {
	type "$1" &> /dev/null
}

_usage() {
	echo "Usage: $0 [ -d domain_name ]"
	echo ""
	echo "  -d domain        : Domain to analyze and show detail info"
	echo ""
}

_get_ip_address() {
	local DOMAIN=${1}
	local domainalias=""
	local ipaddress=""
	domainalias=$(host -t A "${DOMAIN}" | grep "is\ an\ alias" | awk '{print $6}' | sed 's/.$//')
	ipaddress=$(host -t A "${DOMAIN}" | grep -v "has\ no" | awk '{print $4}' | sed '/^ *$/d' | tr '\n' ' ' | sed 's/ $//')
	#ipaddress=$(dig "${DOMAIN}" +short | tr '\n' ' ' | sed 's/ $//')
	if [ -n "${domainalias}" ]; then
		echo -e "Domain:\t\t${DOMAIN} is alias for ${domainalias}"
		ipaddress=$(host -t A "${domainalias}" | grep -v "has\ no" | awk '{print $4}' | sed '/^ *$/d' | tr '\n' ' ' | sed 's/ $//')
	else
		echo -e "Domain:\t\t${DOMAIN}"
	fi
	if [ -n "${ipaddress}" ]; then
		echo -e "IP Address:\t${ipaddress}"
	else
		echo -e "IP Address:\t'A' record not found"
	fi
}

_get_nameserver() {
	local DOMAIN=${1}
	local nsservercnt=0
	local ipnsserver=""
	local i=1
	local ns=""
	#nsservercnt=$(dig ns "${DOMAIN}" | grep -v '^;' | grep NS | awk {'print $5'} | sed '/^$/d' | wc -l)
	nsservercnt=$(host -t NS ${DOMAIN} | grep -v "has\ no NS" | wc -l)
	echo -e "Name Server:\tFound ${nsservercnt} NS record";
	for ns in $(dig ns "${DOMAIN}" | grep -v '^;' | grep NS | awk {'print $5'} | sed '/^$/d' | sed 's/.$//' | sort); do
		#ipnsserver=$(getent hosts "${ns}" | awk '{print $1}')
		ipnsserver=$(host -t A "${ns}" | grep -v "not\ found" | awk '{print $4}' | sed '/^ *$/d' | tr '\n' ' ' | sed 's/ $//')
		if [ -n "${ipnsserver}" ]; then
			echo -e "Name Server $i:\t${ns} (${ipnsserver})";
		else
			echo -e "Name Server $i:\t${ns} (DNS resolv error)";
		fi
		let i++;
	done;
}

_get_mail_server() {
	local DOMAIN=${1}
	local mailserver=""
	local mxservercnt=0
	local ipmailserver=""
	local mx=""
	local i=1
	#mailserver=$(dig mx ${DOMAIN} | grep -v '^;' | grep MX | awk {'print $6'} | sed '/^$/d')
	mailserver=$(host -t MX "${DOMAIN}" | grep -v "has\ no")
	if [ -n "${mailserver}" ]; then
		#mxservercnt=$(dig mx "${DOMAIN}" | grep -v '^;' | grep MX | awk {'print $6'} | sed '/^$/d' | wc -l)
		mxservercnt=$(host -t MX "${DOMAIN}" |sort | awk '{print $7}'| sed 's/.$//' | wc -l)
		echo -e "Mail Server:\tFound ${mxservercnt} MX record";
		for mx in $(dig mx "${DOMAIN}" | grep -v '^;' | grep MX | awk {'print $6'} | sed '/^$/d' | sed 's/.$//' | sort); do
			#ipmailserver=$(getent hosts ${mx} | awk '{print $1}')
			ipmailserver=$(host -t A "${mx}" | grep -v "has\ no" | awk '{print $4}' | sed '/^ *$/d' | tr '\n' ' ' | sed 's/ $//')
			if [ -n "${ipmailserver}" ]; then
				echo -e "Mail Server ${i}:\t${mx} (${ipmailserver})";
			else
				echo -e "Mail Server ${i}:\t${mx}";
			fi
			let i++;
		done;
	else
		echo -e "Mail Server:\tMX record not found";
	fi
}

_view_domain_info() {
	local DOMAIN=${1}
	local whoisdomain=""
	local nslookupdomain=""
	local whoisdomain_delagated=""
	local domainalias=""
	echo "Checking the domain '${DOMAIN}', please wait..."
	whoisdomain=$(whois "${DOMAIN}" | grep -Ei 'state|status')
	nslookupdomain=$(nslookup "${DOMAIN}" | awk '/^Address: / { print $2 }')
	if [ -n "${whoisdomain}" ]; then
		whoisdomain_delagated=$(whois "${DOMAIN}" | grep -Ei 'NOT DELEGATED')
		if [ -n "${whoisdomain_delagated}" ]; then
			echo "Domain ${DOMAIN} is not delegated."
			exit 1
		fi
		_get_ip_address "${DOMAIN}"
		domainalias=$(host -t A "${DOMAIN}" | grep "is\ an\ alias" | awk '{print $6}' | sed 's/.$//')
		if [ -n "${domainalias}" ]; then
			_get_nameserver "${domainalias}"
			_get_mail_server "${domainalias}"
		else
			_get_nameserver "${DOMAIN}"
			_get_mail_server "${DOMAIN}"
		fi
	elif [ -n "${nslookupdomain}" ]; then
		_get_ip_address "${DOMAIN}"
		domainalias=$(host -t A "${DOMAIN}" | grep "is\ an\ alias" | awk '{print $6}' | sed 's/.$//')
		if [ -n "${domainalias}" ]; then
			_get_nameserver "${domainalias}"
			_get_mail_server "${domainalias}"
		else
			_get_nameserver "${DOMAIN}"
			_get_mail_server "${DOMAIN}"
		fi
	else
		echo "Domain '${DOMAIN}' is not registered."
		exit 1
	fi
}

if ! _command_exists whois ; then
        echo "ERROR: Command 'whois' not found."
        exit 1
fi

if ! _command_exists dig ; then
        echo "ERROR: Command 'dig' not found."
        exit 1
fi

if ! _command_exists nslookup ; then
        echo "ERROR: Command 'whois' not found."
        exit 1
fi

### Evaluate the options passed on the command line
while getopts hd: option
do
	case "${option}"
	in
		d)
			DOMAIN=${OPTARG}
		;;
		\?)
			_usage
			exit 1
		;;
		esac
done

if [ "${DOMAIN}" != "" ]
then
	_view_domain_info "${DOMAIN}"
else
	_usage
	exit 1
fi

### Exit with a success indicator
exit 0

