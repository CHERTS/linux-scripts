#!/usr/bin/env bash

#
# Program: Monit upgrade <monit-upgrade>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.3
#
# Revision History:
#
#  Version 1.3
#    Fixed Content-Length
#
#  Version 1.2
#    Added FreeBSD support
#
#  Version 1.1
#    Added auto detect new monit version on official web site
#    Added OS architecture auto detect
#    Added debug mode in script (debug=1)
#
#  Version 1.0
#    Initial Release
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

set -e

# Set manual monit version
#monit_latest_ver="5.24.0"

# Set manual monit platform (linux-x64 or linux-x86)
#monit_platform=linux-x64

# Set temporary directory
monit_tmp_dir=/tmp

# Set debug to info
debug=0

# Additional functions
command_exists ()
{
	type "$1" &> /dev/null ;
}

function debug_log () {
	if [[ ${debug} -eq 1 ]]; then
		echo "$@"
	fi
}

function linux_stop_monit () {
    case "$(pidof monit | wc -w)" in
       0)  echo "Monit not running."
	   ;;
       1)  echo -n "Stoping current monit... "
           if [ -f /etc/init.d/monit ]; then
               /etc/init.d/monit stop >/dev/null 2>&1
	   else
	       echo "Error"
               echo "ERROR: File /etc/init.d/monit not found."
	       exit 1;
	   fi
	   ;;
       *)  echo "Kill current monit... "
	   kill -9 $(pidof monit | ${awk_bin} '{print $1}')
	   ;;
    esac
    case "$(pidof monit | wc -w)" in
       0)  echo "Done"
	   ;;
       1)  echo "Error"
	   echo "ERROR: monit is not stopped."
	   exit 1;
    esac
}

function freebsd_stop_monit () {
    echo -n "Stoping current monit... "
    if [ -f /usr/local/etc/rc.d/monit ]; then
        /usr/local/etc/rc.d/monit stop >/dev/null 2>&1
    else
	echo "Error"
        echo "ERROR: File /usr/local/etc/rc.d/monit not found"
        exit 1;
    fi
    echo "Done"
}

function linux_start_monit () {
    echo -n "Starting new monit... "
    if [ -f /etc/init.d/monit ]; then
        /etc/init.d/monit start >/dev/null 2>&1
    else
	echo "Error"
        echo "ERROR: File /etc/init.d/monit not found"
        exit 1;
    fi
    case "$(pidof monit | wc -w)" in
	0)  echo "Error"
            echo "ERROR: monit is not running."
	    ;;
        1)  echo "Done"
	    ;;
    esac
}

function freebsd_start_monit () {
    echo -n "Starting new monit... "
    if [ -f /usr/local/etc/rc.d/monit ]; then
        /usr/local/etc/rc.d/monit start >/dev/null 2>&1
    else
	echo "Error"
        echo "ERROR: File /usr/local/etc/rc.d/monit not found"
        exit 1;
    fi
    echo "Done"
}

unknown_os ()
{
  echo
  echo "Unfortunately, your operating system distribution and version are not supported by this script."
  echo
  echo "Please email sleuthhound@gmail.com and let us know if you run into any issues."
  exit 1
}

os=$(uname -s)
os_arch=$(uname -m)
echo -n "Detecting your OS... "
if [ "${os}" = "Linux" ]; then
	echo "Linux (${os_arch})"
elif [ "${os}" = "FreeBSD" ]; then
	echo "FreeBSD (${os_arch})"
else
	echo "Unknown"
	unknown_os
fi

ls_bin=$(which ls)

if ! command_exists monit ; then
	echo "ERROR: Monit not installed!"
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
	monit_bin=$(which monit)
fi

if ! command_exists curl ; then
	echo "ERROR: curl not installed!"
	exit 1;
else
	curl_bin=$(which curl)
fi

if ! command_exists sed ; then
	echo "ERROR: sed not installed!"
	exit 1;
else
	sed_bin=$(which sed)
fi

if ! command_exists awk ; then
	echo "ERROR: awk not installed!"
	exit 1;
else
	awk_bin=$(which awk)
fi

if [ -z "${monit_platform}" ]; then
	if [ "${os}" = "Linux" ]; then
		monit_platform_1="linux"
	elif [ "${os}" = "FreeBSD" ]; then
		monit_platform_1="freebsd"
	elif [ "${os}" = "OpenBSD" ]; then
		monit_platform_1="openbsd"
        elif [ "${os}" = "NetBSD" ]; then
                monit_platform_1="netbsd"
	else
		monit_platform_1="solaris"
	fi
	if [ "${os_arch}" = "amd64" ]; then
		monit_platform_2="x64"
	elif [ "${os_arch}" = "x86_64" ]; then
		monit_platform_2="x64"
	else
		monit_platform_2="x86"
	fi
	monit_platform="${monit_platform_1}-${monit_platform_2}"
fi
debug_log "DEBUG: Monit platform: ${monit_platform}"

if [ -z "${monit_latest_ver}" ]; then
	monit_latest_ver=$(${curl_bin} -s https://mmonit.com/monit/changes/ | grep "Version" | grep -o 'id=".*"' | awk -F'"' '{print $2}' | head -n1)
fi

current_monit_ver=$(${monit_bin} -V | ${sed_bin} -n 1p | ${sed_bin} 's/[[:alpha:]|(|[:space:]]//g' | ${awk_bin} -F- '{print $1}')
monit_url="https://mmonit.com/monit/dist/binary/${monit_latest_ver}/monit-${monit_latest_ver}-${monit_platform}.tar.gz"

echo "Version of Monit in your system: ${current_monit_ver}"
echo "Latest Monit version on official web site: ${monit_latest_ver}"
debug_log "DEBUG: Monit URL: ${monit_url}"

if [ "${current_monit_ver}" == "${monit_latest_ver}" ]; then
	echo "You are using the latest Monit version (v${current_monit_ver})"
	exit 0;
fi

if ! command_exists wget ; then
	echo "ERROR: wget not installed!"
	exit 1;
else
	wget_bin=`which wget`
fi

if ! command_exists tar ; then
	echo "ERROR: tar not installed!"
	exit 1;
else
	tar_bin=`which tar`
fi

if [ -f "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz" ]; then
	rm -f "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz"
fi

if [ ! -f "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz" ]; then
    monit_arch_status_code=$(${wget_bin} ${monit_url} --spider --server-response -O - 2>&1 | grep "HTTP/" | awk '{print $2}')
    debug_log "DEBUG: Check monit in official web site... Return HTTP Code: ${monit_arch_status_code}"
    if [ "${monit_arch_status_code}" -ne "200" ]; then
	    echo "ERROR: Monit of version ${monit_latest_ver} not found in official web site https://mmonit.com"
	    exit 1;
    fi
    monit_arch_size=$(${curl_bin} -sI ${monit_url} | grep -i "Content-Length" | awk '{print $2}' | tr -d '\n' | tr -d '\r')
    debug_log "DEBUG: Check monit in official web site... Return file size: ${monit_arch_size}"
    echo -n "Downloading new monit version (v${monit_latest_ver})... "
    ${wget_bin} ${monit_url} -O "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz" >/dev/null 2>&1
    if [ -f "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz" ]; then
	    echo "Done"
            monit_arch_size_on_disk=$(${ls_bin} -l "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz" | awk '{print $5}')
	    debug_log "DEBUG: Check monit archive ${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz on local disk... Size: ${monit_arch_size_on_disk}"
    else
	    echo "Error"
	    exit 1;
    fi
    echo -n "Checking archive size... "
    if [ "${monit_arch_size_on_disk}" -eq "${monit_arch_size}" ]; then
	    echo "Done"
    else
	    echo "Error"
	    echo "ERROR: The size of the archive from the official site does not match the size of the archive on the disk."
	    exit 1;
    fi
fi

if [ -f "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz" ]; then
    if [ -d "${monit_tmp_dir}/monit-${monit_latest_ver}" ]; then
        rm -rf "${monit_tmp_dir}/monit-${monit_latest_ver}"
    fi
    debug_log "DEBUG: Unpacking archive ${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz..."
    echo -n "Unpacking archive... "
    ${tar_bin} -zxf "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz" -C "${monit_tmp_dir}/"
    if [ -d "${monit_tmp_dir}/monit-${monit_latest_ver}" ]; then
       echo "Done"
    else
       echo "Error"
       exit 1;
    fi
    if [ "${os}" = "Linux" ]; then
       linux_stop_monit
    elif [ "${os}" = "FreeBSD" ]; then
       freebsd_stop_monit
    else
       exit 1;
    fi
    echo -n "Delete older version monit... "
    if [ -f ${monit_bin} ]; then
            rm -f ${monit_bin}
    fi
    if [ ! -f ${monit_bin} ]; then
	    echo "Done"
    else
	    echo "Error"
    fi
    echo -n "Copy the new version of monit... "
    cp "${monit_tmp_dir}/monit-${monit_latest_ver}/bin/monit" ${monit_bin}
    if [ "${os}" = "Linux" ]; then
       chown -R root:root ${monit_bin}
    elif [ "${os}" = "FreeBSD" ]; then
       chown -R root:wheel ${monit_bin}
    else
       chown -R root ${monit_bin}
    fi
    chmod a+x ${monit_bin}
    echo "Done"
    if [ "${os}" = "Linux" ]; then
      if [ ! -f /etc/monitrc ]; then
        echo -n "Creatin symlink... "
        ln -s /etc/monit/monitrc /etc/monitrc
	echo "Done"
      fi
    fi
    if [ "${os}" = "Linux" ]; then
       linux_start_monit
    elif [ "${os}" = "FreeBSD" ]; then
       freebsd_start_monit
    else
       exit 1;
    fi
    if [ -d "${monit_tmp_dir}/monit-${monit_latest_ver}" ]; then
        rm -rf "${monit_tmp_dir}/monit-${monit_latest_ver}"
    fi
    if [ -f "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz" ]; then
	rm "${monit_tmp_dir}/monit-${monit_latest_ver}-${monit_platform}.tar.gz"
    fi
fi
