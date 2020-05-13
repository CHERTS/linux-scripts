#!/usr/bin/env bash

#
# Program: A script for downloading zabbix-agent packages for all available platforms.
#
# Author: Mikhail Grigorev <sleuthound at gmail dot com>
#
# Current Version: 1.2
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

# Latest agents (3.4 or 4.0 or 4.4 or 5.0)
ZBX_VER=5.0
# Zabbix pkg repo
ZBX_URL=http://repo.zabbix.com/zabbix/${ZBX_VER}
# Pre-compiled Zabbix agents
ZBX_PRECOMPILED_AGENTS_URL="https://www.zabbix.com/downloads"
SCRIPT_DIR=$(dirname "$0")
DOWNLOAD_DIR="${SCRIPT_DIR}/${ZBX_VER}"
ENABLE_DEBUG=0

case ${ZBX_VER} in
	"3.4")
		ZBX_STABLE_VER=3.4.15
		ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
		ZBX_LINUX_MINOR_PKG_VER=1
		# 3.4.0 -> non-openssl
		ZBX_FULL_WINDOWS_VER=3.4.0
		ZBX_WINDOWS_OPENSSL_PKG=0
		ZBX_WINDOWS_AMD64_PKG=0
		# 3.4.0 -> 7_1 (non-openssl)
		ZBX_AIX_VER=7_1
		ZBX_FULL_AIX_VER=3.4.0
		ZBX_AIX_OPENSSL_PKG=0
		# 3.4.15 -> 11.2 (openssl or non-openssl)
		# 3.4.0 -> 11.1 (non-openssl)
		ZBX_FREEBSD_VER=11.2
		ZBX_FULL_FREEBSD_VER=${ZBX_STABLE_VER}
		ZBX_FREEBSD_OPENSSL_PKG=1
		# 3.4.15 -> 6.3 (openssl or non-openssl)
		# 3.4.0 -> 5_9 or 6_1 (non-openssl)
		ZBX_OPENBSD_VER=6.3
		ZBX_FULL_OPENBSD_VER=${ZBX_STABLE_VER}
		ZBX_OPENBSD_OPENSSL_PKG=0
		;;
	"4.0")
		ZBX_STABLE_VER=4.0.18
		ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
		ZBX_LINUX_MINOR_PKG_VER=1
		# 4.0.14 -> openssl or non-openssl
		ZBX_FULL_WINDOWS_VER=${ZBX_STABLE_VER}
		ZBX_WINDOWS_OPENSSL_PKG=1
		ZBX_WINDOWS_AMD64_PKG=1
		# 4.0.7 -> 7_2 (openssl or non-openssl)
		# 4.0.7 -> 6_1 (openssl)
		# 4.0.1 -> 6_1 (non-openssl)
		ZBX_AIX_VER=7.2
		ZBX_FULL_AIX_VER=4.0.7
		ZBX_AIX_OPENSSL_PKG=1
		# 4.0.14 -> openssl or non-openssl
		ZBX_FREEBSD_VER=11.2
		ZBX_FULL_FREEBSD_VER=${ZBX_STABLE_VER}
		ZBX_FREEBSD_OPENSSL_PKG=1
		# 4.0.14 -> openssl or non-openssl
		ZBX_OPENBSD_VER=6.3
		ZBX_FULL_OPENBSD_VER=${ZBX_STABLE_VER}
		ZBX_OPENBSD_OPENSSL_PKG=1
		;;
	"4.4")
		ZBX_STABLE_VER=4.4.8
		ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
		ZBX_LINUX_MINOR_PKG_VER=1
		# 4.0.14 -> openssl or non-openssl
		ZBX_FULL_WINDOWS_VER=${ZBX_STABLE_VER}
		ZBX_WINDOWS_OPENSSL_PKG=1
		ZBX_WINDOWS_AMD64_PKG=1
		# for AIX not build
		ZBX_AIX_VER=7.2
		ZBX_FULL_AIX_VER=4.2.1
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
                ZBX_STABLE_VER=5.0.0
                ZBX_LINUX_FULL_VER=${ZBX_STABLE_VER}
                ZBX_LINUX_MINOR_PKG_VER=1
                # 5.0.0 -> openssl or non-openssl
                ZBX_FULL_WINDOWS_VER=${ZBX_STABLE_VER}
                ZBX_WINDOWS_OPENSSL_PKG=1
                ZBX_WINDOWS_AMD64_PKG=1
                # for AIX not build
                ZBX_AIX_VER=7.2
                ZBX_FULL_AIX_VER=4.2.1
                ZBX_AIX_OPENSSL_PKG=1
                # 5.0.0 -> openssl or non-openssl
                ZBX_FREEBSD_VER=11.2
                ZBX_FULL_FREEBSD_VER=${ZBX_STABLE_VER}
                ZBX_FREEBSD_OPENSSL_PKG=1
                # 5.0.0 -> openssl or non-openssl
                ZBX_OPENBSD_VER=6.3
                ZBX_FULL_OPENBSD_VER=${ZBX_STABLE_VER}
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

if _command_exists wget ; then
	WGET_BIN=$(which wget)
else
	echo "ERROR: Command 'wget' not found."
	exit 1
fi

_wget_zbx() {
	local ZBX_PACKAGE_NAME=$1
	local ZBX_PACKAGE_MINOR_VER=$2
	local ZBX_PLATFORM_VENDOR=$3
	local ZBX_PLATFORM_VER=${4:-"stretch"}
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
	case "$ZBX_PLATFORM_VENDOR" in
		rhel)
			ZBX_SUBDIR=$(echo ${ZBX_PLATFORM_VER} | cut -d'l' -f2)
			if [[ "${ZBX_SUBDIR}" = "6" ]]; then
				ZBX_X86_X64_FIX=$(echo ${ZBX_X86_X64} | sed "s/i386/i686/g")
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}-${ZBX_LINUX_FULL_VER}-${ZBX_PACKAGE_MINOR_VER}.${ZBX_PLATFORM_VER}.${ZBX_X86_X64_FIX}.${ZBX_PKG_EXT}"
			else
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}-${ZBX_LINUX_FULL_VER}-${ZBX_PACKAGE_MINOR_VER}.${ZBX_PLATFORM_VER}.${ZBX_X86_X64}.${ZBX_PKG_EXT}"
			fi
			ZBX_FULL_URL="${ZBX_URL}/${ZBX_PLATFORM_VENDOR}/${ZBX_SUBDIR}/${ZBX_X86_X64}"
			;;
		debian|ubuntu)
			ZBX_SUBDIR="pool/main/z/zabbix"
			ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}_${ZBX_LINUX_FULL_VER}-${ZBX_PACKAGE_MINOR_VER}+${ZBX_PLATFORM_VER}_${ZBX_X86_X64}.${ZBX_PKG_EXT}"
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
			ZBX_FULL_URL="${ZBX_PRECOMPILED_AGENTS_URL}/${ZBX_PACKAGE_MINOR_VER}"
			if [ ${ZBX_OPENSSL} -eq 1 ]; then
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}${ZBX_PKG_NAME_PREFIX}${ZBX_PACKAGE_MINOR_VER}${ZBX_PKG_PREFIX}${ZBX_PLATFORM_VENDOR}${ZBX_WIN_ARCH}${ZBX_PKG_PREFIX}openssl.${ZBX_PKG_EXT}"
			else
				ZBX_FULL_PKG_NAME="${ZBX_PACKAGE_NAME}${ZBX_PKG_NAME_PREFIX}${ZBX_PACKAGE_MINOR_VER}${ZBX_PKG_PREFIX}${ZBX_PLATFORM_VENDOR}${ZBX_WIN_ARCH}.${ZBX_PKG_EXT}"
			fi
			;;
		aix|openbsd|freebsd)
			ZBX_FULL_URL="${ZBX_PRECOMPILED_AGENTS_URL}/${ZBX_PACKAGE_MINOR_VER}/"
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
			echo "OK"
		else
			echo "Not found"
		fi
	else
		echo "Error"
	fi
}

_wget_windows_ver() {
	if [ ${ZBX_WINDOWS_AMD64_PKG} -eq 1 ]; then
		_wget_zbx "zabbix_agent" "${ZBX_FULL_WINDOWS_VER}" "windows" "" "amd64" "${ZBX_WINDOWS_OPENSSL_PKG}"
	fi
	_wget_zbx "zabbix_agent" "${ZBX_FULL_WINDOWS_VER}" "windows" "" "i386" "${ZBX_WINDOWS_OPENSSL_PKG}"
}

# Download Zabbix for Windows
_wget_windows_ver

# Download Zabbix for AIX
_wget_zbx "zabbix_agent" "${ZBX_FULL_AIX_VER}" "aix" "${ZBX_AIX_VER}" "powerpc" "${ZBX_AIX_OPENSSL_PKG}"

# Download Zabbix for OpenBSD
_wget_zbx "zabbix_agent" "${ZBX_FULL_OPENBSD_VER}" "openbsd" "${ZBX_OPENBSD_VER}" "amd64" "${ZBX_OPENBSD_OPENSSL_PKG}"
_wget_zbx "zabbix_agent" "${ZBX_FULL_OPENBSD_VER}" "openbsd" "${ZBX_OPENBSD_VER}" "i386" "${ZBX_OPENBSD_OPENSSL_PKG}"

# Download Zabbix for FreeBSD
_wget_zbx "zabbix_agent" "${ZBX_FULL_FREEBSD_VER}" "freebsd" "${ZBX_FREEBSD_VER}" "amd64" "${ZBX_FREEBSD_OPENSSL_PKG}"
_wget_zbx "zabbix_agent" "${ZBX_FULL_FREEBSD_VER}" "freebsd" "${ZBX_FREEBSD_VER}" "i386" "${ZBX_FREEBSD_OPENSSL_PKG}"

# Download Zabbix for RedHat/OracleLinux/CentOS 5
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "x86_64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "x86_64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "x86_64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el5" "i386"

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

# Download Zabbix for RedHat/OracleLinux/CentOS 8
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el8" "x86_64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el8" "x86_64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "rhel" "el8" "x86_64"

# Download Zabbix for Debian 9 (Stretch)
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "stretch" "amd64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "stretch" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "stretch" "amd64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "stretch" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "stretch" "amd64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "stretch" "i386"

# Download Zabbix for Debian 10 (Buster)
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "buster" "amd64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "buster" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "buster" "amd64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "buster" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "buster" "amd64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "debian" "buster" "i386"

# Download Zabbix for Debian Ubuntu 16.04 (Xenial)
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "xenial" "amd64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "xenial" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "xenial" "amd64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "xenial" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "xenial" "amd64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "xenial" "i386"

# Download Zabbix for Debian Ubuntu 18.04 (Bionic)
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "bionic" "amd64"
_wget_zbx "zabbix-agent" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "bionic" "i386"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "bionic" "amd64"
_wget_zbx "zabbix-sender" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "bionic" "i386"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "bionic" "amd64"
_wget_zbx "zabbix-get" "${ZBX_LINUX_MINOR_PKG_VER}" "ubuntu" "bionic" "i386"
