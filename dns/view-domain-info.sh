#!/bin/bash
#
# Program: View more information about the domain <view-domain-info.sh>
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

usage()
{
        echo "Usage: $0 [ -d domain_name ]"
        echo ""
        echo "  -d domain        : Domain to analyze and show detail info"
        echo ""
}

view_domain_info() 
{
  DOMAIN=${1}
  echo "Starts checking the domain '${DOMAIN}', please wait..."
  whoisdomain=`whois ${DOMAIN} | grep -Ei 'state|status'`
  if [ -n "$whoisdomain" ]
  then
	whoisdomain_delagated=`whois ${DOMAIN} | grep -Ei 'NOT DELEGATED'`
	if [ -n "$whoisdomain_delagated" ]
	then
		echo "Domain ${DOMAIN} is not delegated."
		exit 1
	fi
	#ipaddress=`dig ${DOMAIN} +short | tr '\n' ' ' | sed 's/ $//'`
	ipaddress=`host -t A ${DOMAIN} | grep -v "has\ no" | awk '{print $4}' | sed '/^ *$/d' | tr '\n' ' ' | sed 's/ $//'`
	echo -e "Domain:\t\t${DOMAIN}"
	if [ -n "$ipaddress" ]
	then
		echo -e "IP Address:\t${ipaddress}"
	else
		echo -e "IP Address:\t'A' record not found"
	fi
	i=1;
	#nsservercnt=`dig ns ${DOMAIN} | grep -v '^;' | grep NS | awk {'print $5'} | sed '/^$/d' | wc -l`
	nsservercnt=`host -t NS ${DOMAIN} | grep -v "has\ no NS" | wc -l`
	echo -e "Name Server:\tFound $nsservercnt NS record";
	for ns in $(dig ns ${DOMAIN} | grep -v '^;' | grep NS | awk {'print $5'} | sed '/^$/d' | sed 's/.$//' | sort); do
		#ipnsserver=`getent hosts $ns | awk '{print $1}'`
		ipnsserver=`host -t A $ns | grep -v "not\ found" | awk '{print $4}' | sed '/^ *$/d' | tr '\n' ' ' | sed 's/ $//'`
		if [ -n "$ipnsserver" ]
		then
			echo -e "Name Server $i:\t$ns ($ipnsserver)";
		else
			echo -e "Name Server $i:\t$ns (DNS resolv error)";
		fi
		let i++;
	done;
        #mailserver=`dig mx ${DOMAIN} | grep -v '^;' | grep MX | awk {'print $6'} | sed '/^$/d'`
	mailserver=`host -t MX ${DOMAIN} | grep -v "has\ no"`
	if [ -n "$mailserver" ]
	then
		#mxservercnt=`dig mx ${DOMAIN} | grep -v '^;' | grep MX | awk {'print $6'} | sed '/^$/d' | wc -l`
		mxservercnt=`host -t MX ${DOMAIN} |sort | awk '{print $7}'| sed 's/.$//' | wc -l`
		echo -e "Mail Server:\tFound $mxservercnt MX record";
		i=1;
		for mx in $(dig mx ${DOMAIN} | grep -v '^;' | grep MX | awk {'print $6'} | sed '/^$/d' | sed 's/.$//' | sort); do
			#ipmailserver=`getent hosts $mx | awk '{print $1}'`
			ipmailserver=`host -t A $mx | grep -v "has\ no" | awk '{print $4}' | sed '/^ *$/d' | tr '\n' ' ' | sed 's/ $//'`
			if [ -n "$ipmailserver" ]
			then
				echo -e "Mail Server $i:\t$mx ($ipmailserver)";
			else
				echo -e "Mail Server $i:\t$mx";
			fi
			let i++;
		done;
	else
		echo -e "Mail Server:\tMX record not found";
	fi
  else
    echo "Domain ${DOMAIN} is not registered."
    exit 1
  fi
}

### Evaluate the options passed on the command line
while getopts hd: option
do
        case "${option}"
        in
                d) DOMAIN=${OPTARG};;
                \?) usage
                    exit 1;;
        esac
done

if [ "${DOMAIN}" != "" ]
then
        view_domain_info "${DOMAIN}"
else
        usage
        exit 1
fi

### Exit with a success indicator
exit 0
