#!/usr/bin/env bash

#
# Program: A script for downloading zabbix-agent packages for all available platforms.
#
# Author: Mikhail Grigorev <sleuthound at gmail dot com>
#
# Current Version: 1.4
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

# Latest agents (4.0/4.4/5.0/5.4/6.0/6.4)
ZBX_VER=6.4
# Zabbix pkg repo
ZBX_URL=https://repo.zabbix.com/zabbix/${ZBX_VER}
# Pre-compiled Zabbix agents
ZBX_PRECOMPILED_AGENTS_URL="https://cdn.zabbix.com/zabbix/binaries/stable"
SCRIPT_DIR=$(dirname "$0")
DOWNLOAD_DIR="${SCRIPT_DIR}/${ZBX_VER}"
ENABLE_DEBUG=0

case ${ZBX_VER} in
	"4.0")
		ZBX_STABLE_VER=4.0.50
		ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
		ZBX_LINUX_MINOR_PKG_VER=1
		# 4.0.50 -> openssl or non-openssl
		ZBX_FULL_WINDOWS_VER=${ZBX_STABLE_VER}
		ZBX_WINDOWS_OPENSSL_PKG=1
		ZBX_WINDOWS_AMD64_PKG=1
		# 4.0.47 -> 7_3 (openssl or non-openssl)
		# 4.0.47 -> 7_2 (openssl or non-openssl)
		# 4.0.45 -> 7_1 (openssl or non-openssl)
		ZBX_AIX_VER=7.3
		ZBX_FULL_AIX_VER=4.0.47
		ZBX_AIX_OPENSSL_PKG=1
		# 4.0.50 -> 13.1 (openssl or non-openssl)
		# 4.0.44 -> 13.0 (openssl or non-openssl)
		# 4.0.38 -> 11.2 (openssl or non-openssl)
		ZBX_FREEBSD_VER=13.1
		ZBX_FULL_FREEBSD_VER=${ZBX_STABLE_VER}
		ZBX_FREEBSD_OPENSSL_PKG=1
		# 4.0.44 -> 6.3 (openssl or non-openssl)
		ZBX_OPENBSD_VER=6.3
		ZBX_FULL_OPENBSD_VER=4.0.44
		ZBX_OPENBSD_OPENSSL_PKG=1
		;;
	"4.4")
		ZBX_STABLE_VER=4.4.10
		ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
		ZBX_LINUX_MINOR_PKG_VER=1
		# 4.0.14 -> openssl or non-openssl
		ZBX_FULL_WINDOWS_VER=${ZBX_STABLE_VER}
		ZBX_WINDOWS_OPENSSL_PKG=1
		ZBX_WINDOWS_AMD64_PKG=1
		# for AIX not build
		ZBX_AIX_VER=""
		ZBX_FULL_AIX_VER=""
		ZBX_AIX_OPENSSL_PKG=1
		# 4.4.1 -> openssl or non-openssl
		ZBX_FREEBSD_VER=11.2
		ZBX_FULL_FREEBSD_VER=${ZBX_STABLE_VER}
		ZBX_FREEBSD_OPENSSL_PKG=1
		# 4.4.1 -> openssl or non-openssl
		ZBX_OPENBSD_VER=6.3
		ZBX_FULL_OPENBSD_VER=${ZBX_STABLE_VER}
		ZBX_OPENBSD_OPENSSL_PKG=1
		;;
        "5.0")
                ZBX_STABLE_VER=5.0.41
                ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
                ZBX_LINUX_MINOR_PKG_VER=1
                # 5.0.41 -> openssl or non-openssl
                ZBX_FULL_WINDOWS_VER=${ZBX_STABLE_VER}
                ZBX_WINDOWS_OPENSSL_PKG=1
                ZBX_WINDOWS_AMD64_PKG=1
		# 5.0.36 -> 7_3 (openssl or non-openssl)
		# 5.0.40 -> 7_2 (openssl or non-openssl)
		# 5.0.34 -> 7_1 (openssl or non-openssl)
                ZBX_AIX_VER=7.3
                ZBX_FULL_AIX_VER=5.0.36
                ZBX_AIX_OPENSSL_PKG=1
		# 5.0.41 -> 13.1 (openssl or non-openssl)
		# 5.0.31 -> 13.0 (openssl or non-openssl)
		# 5.0.20 -> 11.2 (openssl or non-openssl)
                ZBX_FREEBSD_VER=13.1
                ZBX_FULL_FREEBSD_VER=${ZBX_STABLE_VER}
                ZBX_FREEBSD_OPENSSL_PKG=1
		# 5.0.31 -> 6.3 (openssl or non-openssl)
                ZBX_OPENBSD_VER=6.3
                ZBX_FULL_OPENBSD_VER=5.0.31
                ZBX_OPENBSD_OPENSSL_PKG=1
                ;;
        "5.4")
                ZBX_STABLE_VER=5.4.12
                ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
                ZBX_LINUX_MINOR_PKG_VER=1
                # 5.4.12 -> openssl or non-openssl
                ZBX_FULL_WINDOWS_VER=${ZBX_STABLE_VER}
                ZBX_WINDOWS_OPENSSL_PKG=1
                ZBX_WINDOWS_AMD64_PKG=1
                # 5.4.6 -> openssl only
                ZBX_AIX_VER=7.2
                ZBX_FULL_AIX_VER=5.4.6
                ZBX_AIX_OPENSSL_PKG=1
                # 5.4.12 -> openssl or non-openssl
                ZBX_FREEBSD_VER=13.0
                ZBX_FULL_FREEBSD_VER=${ZBX_STABLE_VER}
                ZBX_FREEBSD_OPENSSL_PKG=1
                # 5.4.12 -> openssl or non-openssl
                ZBX_OPENBSD_VER=6.3
                ZBX_FULL_OPENBSD_VER=${ZBX_STABLE_VER}
                ZBX_OPENBSD_OPENSSL_PKG=1
                ;;
        "6.0")
                ZBX_STABLE_VER=6.0.26
                ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
                ZBX_LINUX_MINOR_PKG_VER=1
                # 6.0.26 -> openssl or non-openssl
                ZBX_FULL_WINDOWS_VER=${ZBX_STABLE_VER}
                ZBX_WINDOWS_OPENSSL_PKG=1
                ZBX_WINDOWS_AMD64_PKG=1
		# 6.0.20 -> 7_3 (openssl or non-openssl)
		# 6.0.24 -> 7_2 (openssl or non-openssl)
		# 6.0.17 -> 7_1 (openssl or non-openssl)
                ZBX_AIX_VER=7.3
                ZBX_FULL_AIX_VER=6.0.20
                ZBX_AIX_OPENSSL_PKG=1
		# 6.0.26 -> 13.1 (openssl or non-openssl)
		# 6.0.13 -> 13.0 (openssl or non-openssl)
                ZBX_FREEBSD_VER=13.1
                ZBX_FULL_FREEBSD_VER=${ZBX_STABLE_VER}
                ZBX_FREEBSD_OPENSSL_PKG=1
		# 6.0.13 -> 6.3 (openssl or non-openssl)
                ZBX_OPENBSD_VER=6.3
                ZBX_FULL_OPENBSD_VER=6.0.13
                ZBX_OPENBSD_OPENSSL_PKG=1
                ;;
        "6.4")
                ZBX_STABLE_VER=6.4.11
                ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
                ZBX_LINUX_MINOR_PKG_VER=1
                # 6.4.11 -> openssl or non-openssl
                ZBX_FULL_WINDOWS_VER=${ZBX_STABLE_VER}
                ZBX_WINDOWS_OPENSSL_PKG=1
                ZBX_WINDOWS_AMD64_PKG=1
		# 6.4.5 -> 7_3 (openssl or non-openssl)
		# 6.4.9 -> 7_2 (openssl or non-openssl)
		# 6.4.2 -> 7_1 (openssl or non-openssl)
                ZBX_AIX_VER=7.3
                ZBX_FULL_AIX_VER=6.4.5
                ZBX_AIX_OPENSSL_PKG=1
		# 6.4.11 -> 13.1 (openssl or non-openssl)
                ZBX_FREEBSD_VER=13.1
                ZBX_FULL_FREEBSD_VER=${ZBX_STABLE_VER}
                ZBX_FREEBSD_OPENSSL_PKG=1
                # ?.?.? -> openssl or non-openssl
                ZBX_OPENBSD_VER=""
                ZBX_FULL_OPENBSD_VER=""
                ZBX_OPENBSD_OPENSSL_PKG=1
                ;;
	*)
		echo "ERROR: Unsupperted Zabbix version ${ZBX_VER}."
		exit 1;
		;;
esac

_command_exists() {
	type "$1" &> /dev/null
}

if _command_exists tr; then
	TR_BIN=$(which tr)
else
	echo "Command 'tr' not found."
	exit 1
fi

# Checking the availability of necessary utilities
COMMAND_EXIST_ARRAY=(DU SED AWK CUT RM CAT WC GREP DIRNAME LS MV FIND WGET CHOWN CP)
for ((i=0; i<${#COMMAND_EXIST_ARRAY[@]}; i++)); do
	__CMDVAR=${COMMAND_EXIST_ARRAY[$i]}
	CMD_FIND=$(echo "${__CMDVAR}" | ${TR_BIN} '[:upper:]' '[:lower:]')
	if _command_exists ${CMD_FIND} ; then
		eval $__CMDVAR'_BIN'="'$(which ${CMD_FIND})'"
		hash "${CMD_FIND}" >/dev/null 2>&1
	else
		echo "Command '${CMD_FIND}' not found."
		exit 1
	fi
done

_wget_zbx() {
	local ZBX_PACKAGE_NAME=$1
	local ZBX_PACKAGE_MINOR_VER=$2
	local ZBX_PLATFORM_VENDOR=$3
	local ZBX_PLATFORM_VER=${4:-"11"}
	local ZBX_X86_X64=$5
	local ZBX_OPENSSL=${6:-"0"}
	case "$ZBX_PLATFORM_VENDOR" in
		rhel)
			ZBX_PKG_EXT="rpm"
			;;
		debian|ubuntu)
			ZBX_PKG_EXT="deb"
			;;
		aix|openbsd|freebsd)
			ZBX_PKG_EXT="tar.gz"
			;;
		windows)
			ZBX_PKG_EXT="zip"
			;;
		*)
			echo "This OS is not supported, please, contact the developer by sleuthhound@programs74.ru"
			exit 1
			;;
	esac
	ZBX_MAJOR_VER=$(echo -n ${ZBX_VER} | awk -F'.' '{print $1}')
	ZBX_MINOR_VER=$(echo -n ${ZBX_VER} | awk -F'.' '{print $2}')
	case "${ZBX_PLATFORM_VENDOR}" in
		rhel)
			ZBX_SUBDIR=$(echo ${ZBX_PLATFORM_VER} | cut -d'l' -f2)
			if [ ${ZBX_MAJOR_VER} -lt 6 ]; then
				ZBX_PACKAGE_MINOR_NAME=${ZBX_PACKAGE_MINOR_VER}
			else
				ZBX_PACKAGE_MINOR_NAME="release${ZBX_PACKAGE_MINOR_VER}"
			fi
			if [[ "${ZBX_SUBDIR}" = "6" ]]; then
				ZBX_X86_X64_FIX=$(echo ${ZBX_X86_X64} | sed "s/i386/i686/g")
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}-${ZBX_LINUX_FULL_VER}-${ZBX_PACKAGE_MINOR_NAME}.${ZBX_PLATFORM_VER}.${ZBX_X86_X64_FIX}.${ZBX_PKG_EXT}"
			else
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}-${ZBX_LINUX_FULL_VER}-${ZBX_PACKAGE_MINOR_NAME}.${ZBX_PLATFORM_VER}.${ZBX_X86_X64}.${ZBX_PKG_EXT}"
			fi
			ZBX_FULL_URL="${ZBX_URL}/${ZBX_PLATFORM_VENDOR}/${ZBX_SUBDIR}/${ZBX_X86_X64}"
			;;
		debian|ubuntu)
			if [ ${ZBX_MAJOR_VER} -eq 4 ]; then
				case "${ZBX_PLATFORM_VER}" in
				16.04)
					PKG_OS="xenial"
					;;
				18.04)
					PKG_OS="bionic"
					;;
				20.04)
					PKG_OS="focal"
					;;
				9)
					PKG_OS="stretch"
					;;
				10)
					PKG_OS="buster"
					;;
				*)
					PKG_OS=${ZBX_PLATFORM_VER}
					;;
				esac
			elif [ ${ZBX_MAJOR_VER} -eq 5 ] && [ ${ZBX_MINOR_VER} -eq 0 ]; then
				case "${ZBX_PLATFORM_VER}" in
				16.04)
					PKG_OS="xenial"
					;;
				18.04)
					PKG_OS="bionic"
					;;
				20.04)
					PKG_OS="focal"
					;;
				22.04)
					PKG_OS=${ZBX_PLATFORM_VENDOR}${ZBX_PLATFORM_VER}
					;;
				9)
					PKG_OS="stretch"
					;;
				10|11)
					PKG_OS=${ZBX_PLATFORM_VENDOR}${ZBX_PLATFORM_VER}
					;;
				*)
					PKG_OS=${ZBX_PLATFORM_VER}
					;;
				esac
			else
				PKG_OS=${ZBX_PLATFORM_VENDOR}${ZBX_PLATFORM_VER}
			fi
			ZBX_SUBDIR="pool/main/z/zabbix"
			ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}_${ZBX_LINUX_FULL_VER}-${ZBX_PACKAGE_MINOR_VER}+${PKG_OS}_${ZBX_X86_X64}.${ZBX_PKG_EXT}"
			ZBX_FULL_URL="${ZBX_URL}/${ZBX_PLATFORM_VENDOR}/${ZBX_SUBDIR}"
			;;
		windows)
			ZBX_PKG_PREFIX="-"
			ZBX_PKG_NAME_PREFIX="-"
			ZBX_WIN_ARCH="${ZBX_PKG_PREFIX}${ZBX_X86_X64}"
			if [[ "${ZBX_PACKAGE_MINOR_VER}" == "3.4.0" ]]; then
				ZBX_PKG_PREFIX="."
				ZBX_PKG_NAME_PREFIX="_"
				ZBX_WIN_ARCH=""
			fi
			ZBX_FULL_URL="${ZBX_PRECOMPILED_AGENTS_URL}/${ZBX_VER}/${ZBX_PACKAGE_MINOR_VER}"
			if [ ${ZBX_OPENSSL} -eq 1 ]; then
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}${ZBX_PKG_NAME_PREFIX}${ZBX_PACKAGE_MINOR_VER}${ZBX_PKG_PREFIX}${ZBX_PLATFORM_VENDOR}${ZBX_WIN_ARCH}${ZBX_PKG_PREFIX}openssl.${ZBX_PKG_EXT}"
			else
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}${ZBX_PKG_NAME_PREFIX}${ZBX_PACKAGE_MINOR_VER}${ZBX_PKG_PREFIX}${ZBX_PLATFORM_VENDOR}${ZBX_WIN_ARCH}.${ZBX_PKG_EXT}"
			fi
			;;
		aix|openbsd|freebsd)
			ZBX_FULL_URL="${ZBX_PRECOMPILED_AGENTS_URL}/${ZBX_VER}/${ZBX_PACKAGE_MINOR_VER}/"
			ZBX_PKG_PREFIX="-"
			ZBX_PKG_NAME_PREFIX="-"
			if [[ "${ZBX_PLATFORM_VENDOR}" == "aix" ]]; then
				ZBX_PKG_PREFIX="-"
				ZBX_PKG_NAME_PREFIX="-"
			fi
			if [[ "${ZBX_FULL_FREEBSD_VER}" == "3.4.0" ]]; then
				ZBX_PKG_PREFIX="."
				ZBX_PKG_NAME_PREFIX="_"
			fi
			if [[ "${ZBX_FULL_OPENBSD_VER}" == "3.4.0" ]]; then
				ZBX_PKG_PREFIX="."
				ZBX_PKG_NAME_PREFIX="_"
			fi
			if [ ${ZBX_OPENSSL} -eq 1 ]; then
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}${ZBX_PKG_NAME_PREFIX}${ZBX_PACKAGE_MINOR_VER}${ZBX_PKG_PREFIX}${ZBX_PLATFORM_VENDOR}${ZBX_PKG_PREFIX}${ZBX_PLATFORM_VER}${ZBX_PKG_PREFIX}${ZBX_X86_X64}${ZBX_PKG_PREFIX}openssl.${ZBX_PKG_EXT}"
			else
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}${ZBX_PKG_NAME_PREFIX}${ZBX_PACKAGE_MINOR_VER}${ZBX_PKG_PREFIX}${ZBX_PLATFORM_VENDOR}${ZBX_PKG_PREFIX}${ZBX_PLATFORM_VER}${ZBX_PKG_PREFIX}${ZBX_X86_X64}.${ZBX_PKG_EXT}"
			fi
			;;
		*)
			ZBX_SUBDIR=""
			ZBX_FULL_PKG_NAME="zabbix.tar.gz"
			ZBX_FULL_URL="${ZBX_URL}/${ZBX_PLATFORM_VENDOR}/${ZBX_SUBDIR}"
			;;
	esac
	if [ ! -d "${DOWNLOAD_DIR}" ]; then
		mkdir "${DOWNLOAD_DIR}">/dev/null 2>&1
	fi
	if [ ${ENABLE_DEBUG} -eq 1 ]; then
		echo -n "Downloading '${ZBX_FULL_URL}/${ZBX_FULL_PKG_NAME}'... "
	else
		echo -n "Downloading '${ZBX_FULL_PKG_NAME}'... "
	fi
	if [ -f "${DOWNLOAD_DIR}/${ZBX_FULL_PKG_NAME}" ]; then
		rm -f "${DOWNLOAD_DIR}/${ZBX_FULL_PKG_NAME}" >/dev/null 2>&1
	fi
	${WGET_BIN} "${ZBX_FULL_URL}/${ZBX_FULL_PKG_NAME}" -O "${DOWNLOAD_DIR}/${ZBX_FULL_PKG_NAME}" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		if [ -f "${DOWNLOAD_DIR}/${ZBX_FULL_PKG_NAME}" ]; then
			PKG_SIZE=$(${DU_BIN} -b "${DOWNLOAD_DIR}/${ZBX_FULL_PKG_NAME}" 2>/dev/null | ${AWK_BIN} '{print $1}')
			if [ ${PKG_SIZE} -ne 0 ]; then
				echo "OK"
			else
				echo "Error | Size_0"
			fi
		else
			echo "Error | Not_found"
		fi
	else
		echo "Error | Not_download"
	fi
}

_wget_windows_ver() {
	if [ ${ZBX_WINDOWS_AMD64_PKG} -eq 1 ]; then
		_wget_zbx "zabbix_agent" "${ZBX_FULL_WINDOWS_VER}" "windows" "" "amd64" "${ZBX_WINDOWS_OPENSSL_PKG}"
	fi
	_wget_zbx "zabbix_agent" "${ZBX_FULL_WINDOWS_VER}" "windows" "" "i386" "${ZBX_WINDOWS_OPENSSL_PKG}"
}

ZBX_MAJOR_VER=$(echo -n ${ZBX_VER} | awk -F'.' '{print $1}')

# Download Zabbix for Windows
_wget_windows_ver

# Download Zabbix for AIX
if [ -n "${ZBX_AIX_VER}" ]; then
	_wget_zbx "zabbix_agent" "${ZBX_FULL_AIX_VER}" "aix" "${ZBX_AIX_VER}" "powerpc" "${ZBX_AIX_OPENSSL_PKG}"
fi

# Download Zabbix for OpenBSD
if [ -n "${ZBX_OPENBSD_VER}" ]; then
	_wget_zbx "zabbix_agent" "${ZBX_FULL_OPENBSD_VER}" "openbsd" "${ZBX_OPENBSD_VER}" "amd64" "${ZBX_OPENBSD_OPENSSL_PKG}"
	_wget_zbx "zabbix_agent" "${ZBX_FULL_OPENBSD_VER}" "openbsd" "${ZBX_OPENBSD_VER}" "i386" "${ZBX_OPENBSD_OPENSSL_PKG}"
fi

# Download Zabbix for FreeBSD
_wget_zbx "zabbix_agent" "${ZBX_FULL_FREEBSD_VER}" "freebsd" "${ZBX_FREEBSD_VER}" "amd64" "${ZBX_FREEBSD_OPENSSL_PKG}"
_wget_zbx "zabbix_agent" "${ZBX_FULL_FREEBSD_VER}" "freebsd" "${ZBX_FREEBSD_VER}" "i386" "${ZBX_FREEBSD_OPENSSL_PKG}"

if [ ${ZBX_MAJOR_VER} -lt 6 ]; then
	# Download Zabbix for RedHat/OracleLinux/CentOS 5
	_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "x86_64"
	_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "i386"
	_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "x86_64"
	_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "i386"
	_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "x86_64"
	_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "i386"
fi

# Download Zabbix for RedHat/OracleLinux/CentOS 6
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el6" "x86_64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el6" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el6" "x86_64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el6" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el6" "x86_64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el6" "i386"

# Download Zabbix for RedHat/OracleLinux/CentOS 7
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el7" "x86_64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el7" "x86_64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el7" "x86_64"

if [ ${ZBX_MAJOR_VER} -ge 6 ]; then
	# Download Zabbix for RedHat/OracleLinux/CentOS 8
	_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el8" "x86_64"
	_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el8" "x86_64"
	_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el8" "x86_64"

	# Download Zabbix for RedHat/OracleLinux/CentOS 9
	_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el9" "x86_64"
	_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el9" "x86_64"
	_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el9" "x86_64"
fi

# Download Zabbix for Debian 9 (Stretch)
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "9" "amd64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "9" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "9" "amd64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "9" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "9" "amd64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "9" "i386"

# Download Zabbix for Debian 10 (Buster)
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "10" "amd64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "10" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "10" "amd64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "10" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "10" "amd64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "10" "i386"

if [ ${ZBX_MAJOR_VER} -ge 5 ]; then
	# Download Zabbix for Debian 11 (Bullseye)
	_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "11" "amd64"
	_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "11" "amd64"
	_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "11" "amd64"
fi

if [ ${ZBX_MAJOR_VER} -ge 6 ]; then
	# Download Zabbix for Debian 12 (Bookworm)
	_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "12" "amd64"
	_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "12" "amd64"
	_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "12" "amd64"
fi

# Download Zabbix for Ubuntu 16.04 (Xenial)
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "16.04" "amd64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "16.04" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "16.04" "amd64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "16.04" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "16.04" "amd64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "16.04" "i386"

# Download Zabbix for Ubuntu 18.04 (Bionic)
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "18.04" "amd64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "18.04" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "18.04" "amd64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "18.04" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "18.04" "amd64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "18.04" "i386"

# Download Zabbix for Ubuntu 20.04 (Focal)
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "20.04" "amd64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "20.04" "amd64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "20.04" "amd64"

if [ ${ZBX_MAJOR_VER} -ge 6 ]; then
	# Download Zabbix for Ubuntu 22.04 (Jammy)
	_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "22.04" "amd64"
	_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "22.04" "amd64"
	_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "22.04" "amd64"
fi
