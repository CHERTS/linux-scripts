#!/usr/bin/env bash

#
# Program: Automatic install zabbix-agent2 <zabbix_agent2_install.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
# 
# Current Version: 1.0.4
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# Tested platforms:
#  - Debian 10,11 using /bin/bash
#  - RedHat 7,8,9 using /bin/bash
#  - Ubuntu 18.04,20.04,22.04 using /bin/bash
#
# Run (scenario 1):
# export ZABBIX_AGENT_SERVER="zabbix.myserver.org"
# export ZABBIX_AGENT_HOSTMETA="Linux"
# export ZABBIX_AGENT_PSK_NAME="mypsk"
# Download and run script
# wget https://raw.githubusercontent.com/CHERTS/linux-scripts/master/zabbix/zabbix_agent2_install.sh -O ~/zabbix_agent2_install.sh && bash ~/zabbix_agent2_install.sh
#
# Run (scenario 2):
# Create config file zbx_agent2_install.conf
# ZABBIX_AGENT_SERVER="zabbix.myserver.org"
# ZABBIX_AGENT_HOSTMETA="Linux"
# ZABBIX_AGENT_PSK_NAME="mypsk"
# Download and run script
# wget https://raw.githubusercontent.com/CHERTS/linux-scripts/master/zabbix/zabbix_agent2_install.sh -O ~/zabbix_agent2_install.sh && bash ~/zabbix_agent2_install.sh

ZBX_VER="6.0"
ZBX_LOCAL_HOST=$(hostname)
ZBX_AGENT_CONFIG_FILE="/etc/zabbix/zabbix_agent2.conf"
ZBX_AGENT_SERVER_DEFAULT="zabbix.myserver.org"
ZBX_AGENT_LISTENPORT_DEFAULT=10050
ZBX_AGENT_HOSTMETA_DEFAULT="Linux"
ZBX_AGENT_PSK_NAME_DEFAULT="default"
ZBX_AGENT_PSK_KEY_GENERATE=1
ZBX_AGENT_PSK_KEY_DEFAULT=""

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPT_NAME=$(basename "$0")

# Log file path + name
LOG_FILE=${SCRIPT_DIR}/${SCRIPT_NAME%.*}.log
# Realtime config path + name
RT_CONF_FILE=${SCRIPT_DIR}/${SCRIPT_NAME%.*}.conf

_user_exists() {
	id -u "${1}" &> /dev/null;
}

_command_exists() {
	type "$1" &> /dev/null
}

# Don't edit this config
LOG_FILE_WRITABLE=1
LOG_FILE_EXIST_WRITABLE=1
DATE_START=$(date +"%s")

# Logging function
_logging() {
        local MSG=${1}
        local ENDLINE=${2:-"1"}
        if [[ "${ENDLINE}" -eq 0 ]]; then
                printf "%s: %s" "$(date "+%d.%m.%Y %H:%M:%S")" "${MSG}" 2>/dev/null
        else
                printf "%s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "${MSG}" 2>/dev/null
        fi
        if [ ! -f "${LOG_FILE}" ] && [[ "${LOG_FILE_WRITABLE}" -eq 1 ]]; then
                touch "${LOG_FILE}" >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                        printf "%s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "WARNING: Log file '${LOG_FILE}' is not writable." 2>/dev/null
                        LOG_FILE_WRITABLE=0
                fi
        fi
        if [ -w "${LOG_FILE}" ]; then
                printf "%s | %s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "$$" "${MSG}" 1>>"${LOG_FILE}" 2>&1
        else
                if [[ "${LOG_FILE_EXIST_WRITABLE}" -eq 1 ]] && [[ "${LOG_FILE_WRITABLE}" -eq 1 ]]; then
                        printf "%s: %s\n" "$(date "+%d.%m.%Y %H:%M:%S")" "WARNING: Log file '${LOG_FILE}' is not writable." 2>/dev/null
                        LOG_FILE_EXIST_WRITABLE=0
                fi
        fi
}

# Calculate duration function
_duration() {
        local DATE_START=${1:-"$(date +'%s')"}
        local FUNC_NAME=${2:-""}
        local DATE_END=$(date +"%s")
        local D_MSG=""
        local DATE_DIFF=$((${DATE_END}-${DATE_START}))
        if [ -n "${FUNC_NAME}" ]; then
            local D_MSG=" of execute function '${FUNC_NAME}'"
        fi
        _logging "Duration${D_MSG}: $((${DATE_DIFF} / 3600 )) hours $(((${DATE_DIFF} % 3600) / 60)) minutes $((${DATE_DIFF} % 60)) seconds"
}

# Fail, log and exit script function
_fail() {
        local MSG=${1}
        _logging "${MSG}"
        _duration "${DATE_START}"
        _logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'. Goodbye ;)"
        exit 1
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        _fail "** Trapped CTRL-C"
        exit 1
}

if _command_exists "wget"; then
	WGET_BIN=$(which wget)
else
	echo "ERROR: Command 'wget' not found."
	exit 1
fi

if _command_exists "netstat"; then
	NETSTAT_BIN=$(which netstat)
else
	echo "ERROR: Command 'netstat' not found."
	exit 1
fi

if _command_exists "openssl"; then
	OPENSSL_BIN=$(which openssl)
else
    echo "ERROR: Command 'openssl' not found."
    exit 1
fi

if [ -f "${RT_CONF_FILE}" ]; then
	_logging "Read config file..."
	source "${RT_CONF_FILE}" 1>>"${LOG_FILE}" 2>&1
fi

if [ -z "${ZABBIX_AGENT_SERVER}" ]; then
	ZBX_AGENT_SERVER=${ZBX_AGENT_SERVER_DEFAULT}
else
	ZBX_AGENT_SERVER=${ZABBIX_AGENT_SERVER}
fi

if [ -z "${ZABBIX_AGENT_LISTENPORT}" ]; then
	ZBX_AGENT_LISTENPORT=${ZBX_AGENT_LISTENPORT_DEFAULT}
else
	ZBX_AGENT_LISTENPORT=${ZABBIX_AGENT_LISTENPORT}
fi

if [ -z "${ZABBIX_AGENT_HOSTMETA}" ]; then
	ZBX_AGENT_HOSTMETA=${ZBX_AGENT_HOSTMETA_DEFAULT}
else
	ZBX_AGENT_HOSTMETA=${ZABBIX_AGENT_HOSTMETA}
fi

if [ -z "${ZABBIX_AGENT_PSK_NAME}" ]; then
	ZBX_AGENT_PSK_NAME=${ZBX_AGENT_PSK_NAME_DEFAULT}
else
	ZBX_AGENT_PSK_NAME=${ZABBIX_AGENT_PSK_NAME}
fi

if [ ${ZBX_AGENT_PSK_KEY_GENERATE} -eq 1 ]; then
	ZBX_AGENT_PSK_KEY=$(${OPENSSL_BIN} rand -hex 32 2>/dev/null)
else
	if [ -z "${ZABBIX_AGENT_PSK_KEY}" ]; then
		ZBX_AGENT_PSK_KEY=${ZBX_AGENT_PSK_KEY_DEFAULT}
	else
		ZBX_AGENT_PSK_KEY=${ZABBIX_AGENT_PSK_KEY}
	fi
fi

_logging "Starting script '${SCRIPT_DIR}/${SCRIPT_NAME}'"

_logging "Current script configuration:"
_logging "LOG_FILE: ${LOG_FILE}"
_logging "RT_CONF_FILE: ${RT_CONF_FILE}"
_logging "Prepared Zabbix-agent 2 settings:"
_logging "Zabbix version: ${ZBX_VER}"
_logging "ActiveServer: ${ZBX_AGENT_SERVER}"
_logging "Hostmeta: ${ZBX_AGENT_HOSTMETA}"
if [ -n "${ZBX_AGENT_PSK_KEY}" ]; then
	_logging "Use PSK encryption: Yes"
	_logging "PSK Name: ${ZBX_AGENT_PSK_NAME}"
	_logging "PSK Key: ${ZBX_AGENT_PSK_KEY}"
else
	_logging "Use PSK encryption: No"
fi

while true; do
	read -p "Do you wish to install zabbix-agent2 ? " yn
	case $yn in
		[Yy]* ) break;;
	       	[Nn]* ) echo -e "Goodbye ;)"; exit;;
        	* ) echo "Please answer yes or no.";;
	esac
done

_unknown_os() {
	_logging "Unfortunately, your operating system distribution and version are not supported by this script."
	_fail "Please email sleuthhound@gmail.com and let us know if you run into any issues."
}

_unknown_distrib() {
	_logging "Unfortunately, your Linux distribution or distribution version are not supported by this script."
	_fail "Please email sleuthhound@gmail.com and let us know if you run into any issues."
}

_detect_linux_distrib() {
	local DIST=$1
	local REV=$2
	local PSUEDONAME=$3
	_logging "Detecting your Linux distributive..."
	case "${DIST}" in
		Ubuntu)
			case "${REV}" in
			14.04|16.04|17.10|18.04|20.04|22.04)
				_logging "Found ${DIST} ${REV} (${PSUEDONAME})"
				;;
			*)
				_unknown_distrib
				;;
			esac
			;;
		Debian)
			if [ -n "${PSUEDONAME}" ]; then
				_logging "Found ${DIST} ${REV} (${PSUEDONAME})"
			else
				_unknown_distrib
			fi
			;;
		"Red Hat"*)
			_logging "Found ${DIST} ${REV} (${PSUEDONAME})"
			;;
		"CentOS"*)
			_logging "Found ${DIST} ${REV} (${PSUEDONAME})"
			;;
		*)
			_logging "ERROR: Unsupported (${DIST} | ${REV} | ${PSUEDONAME})"
			_unknown_distrib
			;;
	esac
}

OS=$(uname -s)
OS_ARCH=$(uname -m)
_logging "Detecting your OS..."
case "${OS}" in
	Linux*)
		_logging "Found OS Linux (${OS_ARCH})"
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
			EL=$(echo "${REV}" | awk -F'.' '{print $1}')
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
		_logging "ERROR: Unknown OS"
		_unknown_os
		;;
esac

_logging "Checking your privileges... "
CURRENT_USER=$(whoami)
if [[ "${CURRENT_USER}" = "root" ]]; then
	_logging "Your privileges is OK"
else
	_fail "Error: root access is required"
fi

_show_log() {
	if [ -f "/var/log/zabbix/zabbix_agent2.log" ]; then
		_logging "Show zabbix-agent2 log file..."
		tail -n 50 /var/log/zabbix/zabbix_agent2.log
	fi
	_fail "ERROR: Exiting..."
}

AGENT2_INSTALLED=0

case "${DIST}" in
	Ubuntu)
		_logging "Check zabbix-release is installed, please wait..."
		CHECK_ZBX_OLD=$(dpkg -l 2>/dev/null | grep -c [z]abbix-release)
		if [ ${CHECK_ZBX_OLD} -ne 0 ]; then
			_logging "Remove old zabbix-release, please wait..."
			apt-get remove zabbix-release --purge -y 1>>"${LOG_FILE}" 2>&1
		fi
		CHECK_ZBX_OLD=$(dpkg -l 2>/dev/null | grep -c [z]abbix-release)
		if [ ${CHECK_ZBX_OLD} -eq 0 ]; then
			_logging "Download Zabbix SIA release, please wait..."
			${WGET_BIN} "https://repo.zabbix.com/zabbix/${ZBX_VER}/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu${REV}_all.deb" -O "${SCRIPT_DIR}/zabbix-release.deb" 1>>"${LOG_FILE}" 2>&1
			if [ -f "${SCRIPT_DIR}/zabbix-release.deb" ]; then
				_logging "Installing Zabbix SIA repo..."
				dpkg -i "${SCRIPT_DIR}/zabbix-release.deb" 1>>"${LOG_FILE}" 2>&1
				if [ $? -eq 0 ]; then
					_logging "Done, Zabbix SIA repo installed."
					rm -f "${SCRIPT_DIR}/zabbix-release.deb" 1>>"${LOG_FILE}" 2>&1
				else
					rm -f "${SCRIPT_DIR}/zabbix-release.deb" 1>>"${LOG_FILE}" 2>&1
					_fail "ERROR: Zabbix SIA repo not installed."
				fi
				_logging "Update packages cache, please wait..."
				apt-get update -qq 1>>"${LOG_FILE}" 2>&1
				if [ $? -eq 0 ]; then
					_logging "Packages cache updated."
				else
					_fail "ERROR: Packages cache not updated."
				fi
				_logging "Installing zabbix-agent2, please wait..."
				apt-get install zabbix-agent2 -y 1>>"${LOG_FILE}" 2>&1
				if [ $? -eq 0 ]; then
					AGENT2_INSTALLED=1
					systemctl enable --now zabbix-agent2 1>>"${LOG_FILE}" 2>&1
					_logging "Done, zabbix-agent2 installed."
				else
					_fail "ERROR: zabbix-agent2 not installed."
				fi
			else
				_fail "ERROR: File 'zabbix-release_latest%2Bubuntu${REV}_all.deb' not downloadded from Zabbix SIA repo."
			fi
		else
			_fail "ERROR: Old zabbix-release not removed."
		fi
		;;
	Debian)
		_logging "Check zabbix-release is installed, please wait..."
		CHECK_ZBX_OLD=$(dpkg -l 2>/dev/null | grep -c [z]abbix-release)
		if [ ${CHECK_ZBX_OLD} -ne 0 ]; then
			_logging "Remove old zabbix-release, please wait..."
			apt-get remove zabbix-release --purge -y 1>>"${LOG_FILE}" 2>&1
		fi
		CHECK_ZBX_OLD=$(dpkg -l 2>/dev/null | grep -c [z]abbix-release)
		if [ ${CHECK_ZBX_OLD} -eq 0 ]; then
			_logging "Download Zabbix SIA release, please wait..."
			${WGET_BIN} "https://repo.zabbix.com/zabbix/${ZBX_VER}/debian/pool/main/z/zabbix-release/zabbix-release_latest+debian${REV}_all.deb" -O "${SCRIPT_DIR}/zabbix-release.deb" >/dev/null 2>&1
			if [ -f "${SCRIPT_DIR}/zabbix-release.deb" ]; then
				_logging "Installing Zabbix SIA repo..."
				dpkg -i "${SCRIPT_DIR}/zabbix-release.deb" 1>>"${LOG_FILE}" 2>&1
				if [ $? -eq 0 ]; then
					_logging "Done, Zabbix SIA repo installed."
					rm -f "${SCRIPT_DIR}/zabbix-release.deb" 1>>"${LOG_FILE}" 2>&1
				else
					rm -f "${SCRIPT_DIR}/zabbix-release.deb" 1>>"${LOG_FILE}" 2>&1
					_fail "ERROR: Zabbix SIA repo not installed."
				fi
				_logging "Update packages cache, please wait..."
				apt-get update -qq 1>>"${LOG_FILE}" 2>&1
				if [ $? -eq 0 ]; then
					_logging "Packages cache updated."
				else
					_fail "ERROR: Packages cache not updated."
				fi
				_logging "Installing zabbix-agent2, please wait..."
				apt-get install zabbix-agent2 -y 1>>"${LOG_FILE}" 2>&1
				if [ $? -eq 0 ]; then
					AGENT2_INSTALLED=1
					systemctl enable --now zabbix-agent2 1>>"${LOG_FILE}" 2>&1
					_logging "Done, zabbix-agent2 installed."
				else
					_fail "ERROR: zabbix-agent2 not installed."
				fi
			else
				_fail "ERROR: zabbix-release not installed."
			fi
		else
			_fail "ERROR: Old zabbix-release not removed."
		fi
		;;
	"CentOS"*|"Red Hat"*)
		_logging "Check zabbix-release is installed, please wait..."
		yum list installed zabbix-release 1>>"${LOG_FILE}" 2>&1
		if [ $? -eq 0 ]; then
			_logging "Remove old zabbix-release..."
			yum erase zabbix-release -y 1>>"${LOG_FILE}" 2>&1
		fi
		yum list installed zabbix-release 1>>"${LOG_FILE}" 2>&1
		if [ $? -ne 0 ]; then
			_logging "Installing Zabbix SIA repo (el${EL}-${OS_ARCH}), please wait..."
			yum localinstall -y "https://repo.zabbix.com/zabbix/${ZBX_VER}/rhel/${EL}/${OS_ARCH}/zabbix-release-latest.el${EL}.noarch.rpm" 1>>"${LOG_FILE}" 2>&1
			_logging "Run clean repo cache, please wait..."
			yum clean all -y 1>>"${LOG_FILE}" 2>&1
			_logging "Run makecache fast, please wait..."
			yum makecache fast -y 1>>"${LOG_FILE}" 2>&1
			_logging "Installing zabbix-agent2, please wait..."
			yum install -y zabbix-agent2 1>>"${LOG_FILE}" 2>&1
			if [ $? -eq 0 ]; then
				AGENT2_INSTALLED=1
				systemctl enable --now zabbix-agent2 1>>"${LOG_FILE}" 2>&1
				_logging "Done, zabbix-agent2 installed."
			else
				_fail "ERROR: zabbix-agent2 not installed."
			fi
		else
			_fail "ERROR: Old zabbix-release not removed."
		fi
		;;
esac

if [ ${AGENT2_INSTALLED} -eq 1 ]; then
	if [ -f "${ZBX_AGENT_CONFIG_FILE}" ]; then
		if [ ! -f "${ZBX_AGENT_CONFIG_FILE}.done" ]; then
			ZBX_AGENT_NUM=$(ps -ef | grep -c [z]abbix_agent2)
			if [ ${ZBX_AGENT_NUM} -ne 0 ]; then
				systemctl stop zabbix-agent2 1>>"${LOG_FILE}" 2>&1
			fi
			_logging "Settings up zabbix-agent2 (ActiveServer=${ZBX_AGENT_SERVER})..."
			sed -i "s@Server=127.0.0.1@Server=${ZBX_AGENT_SERVER}@g" "${ZBX_AGENT_CONFIG_FILE}"
			sed -i "s@ServerActive=127.0.0.1@ServerActive=${ZBX_AGENT_SERVER}@g" "${ZBX_AGENT_CONFIG_FILE}"
			sed -i "s@Hostname=Zabbix server@Hostname=${ZBX_LOCAL_HOST}@g" "${ZBX_AGENT_CONFIG_FILE}"
			_logging "Settings up zabbix-agent2 (Hostmeta=${ZBX_AGENT_HOSTMETA})..."
			sed -i "s@# HostMetadata=@HostMetadata=${ZBX_AGENT_HOSTMETA}@g" "${ZBX_AGENT_CONFIG_FILE}"
			ZBX_PORT_USE=0
			ZBX_PORT_USE=$(${NETSTAT_BIN} -ltupn | grep -c 10050)
			if [ ${ZBX_PORT_USE} -gt 0 ];  then
				_logging "Settings up zabbix-agent2 (ListenPort=${ZBX_AGENT_LISTENPORT})..."
				sed -i "s@# ListenPort=10050@ListenPort=${ZBX_AGENT_LISTENPORT}@g" "${ZBX_AGENT_CONFIG_FILE}"
			else
				_logging "Settings up zabbix-agent2 (ListenPort=10050)..."
			fi
			if [ -n "${ZBX_AGENT_PSK_KEY}" ]; then
				_logging "Settings up zabbix-agent2 encryption settings (TLSPSKIdentity=${ZBX_AGENT_PSK_NAME})..."
				sed -i "s@# TLSConnect=unencrypted@TLSConnect=psk@g" "${ZBX_AGENT_CONFIG_FILE}"
				sed -i "s@# TLSAccept=unencrypted@TLSAccept=psk@g" "${ZBX_AGENT_CONFIG_FILE}"
				sed -i "s@# TLSPSKIdentity=@TLSPSKIdentity=${ZBX_AGENT_PSK_NAME}@g" "${ZBX_AGENT_CONFIG_FILE}"
				sed -i "s@# TLSPSKFile=@TLSPSKFile=/etc/zabbix/${ZBX_AGENT_PSK_NAME}.key@g" "${ZBX_AGENT_CONFIG_FILE}"
				echo "${ZBX_AGENT_PSK_KEY}" > "/etc/zabbix/${ZBX_AGENT_PSK_NAME}.key"
				chmod 640 "/etc/zabbix/${ZBX_AGENT_PSK_NAME}.key" >/dev/null 2>&1
				chown zabbix:zabbix "/etc/zabbix/${ZBX_AGENT_PSK_NAME}.key" >/dev/null 2>&1
			fi
			_logging "Done, zabbix-agent2 now configured."
			echo "$(date)" > "${ZBX_AGENT_CONFIG_FILE}.done"
			_logging "Restarting zabbix-agent2, please wait..."
			systemctl restart zabbix-agent2 1>>"${LOG_FILE}" 2>&1
			if [ $? -eq 0 ]; then
				sleep 5
				_logging "Done, zabbix-agent2 now restarted."
				ZBX_AGENT_NUM=$(ps -ef | grep -c [z]abbix_agent2)
				if [ ${ZBX_AGENT_NUM} -ne 0 ]; then
					_logging "Done, zabbix-agent2 now running."
				else
					_logging "ERROR: zabbix-agent2 not running, see log file /var/log/zabbix/zabbix_agent2.log"
					_show_log
				fi
			else
				_logging "ERROR: zabbix-agent2 not restarter, see log file /var/log/zabbix/zabbix_agent2.log"
				_show_log
			fi
		else
			_fail "ERROR: Zabbix-agent2 already configured."
		fi
	else
		_fail "ERROR: Zabbix-agent2 config file '${ZBX_AGENT_CONFIG_FILE}' not found."
	fi
fi

_logging "All done."
_duration "${DATE_START}"

_logging "End script '${SCRIPT_DIR}/${SCRIPT_NAME}'. Goodbye ;)"
