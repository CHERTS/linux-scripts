#!/usr/bin/env bash

#
# Program: Automatic creating alternative zabbix-agent <create_zabbix_agent_alt.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
# 
# Current Version: 1.0.0
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

ZBX_SERVERS_LIST=127.0.0.1,zabbix.myserver.org
ZBX_SERVERS_LIST_ACTIVE=zabbix.myserver.org:11311
ZBX_AGENT_LOCAL_PORT=11311

ZBX_AGENT_PREFIX="alt"
ZBX_DEFAULT_USER=zabbix
ZBX_DEFAULT_GROUP=zabbix
ZBX_DEFAULT_HOME_DIR=/var/lib/zabbix

ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR=/etc/init.d
ZBX_DEFAULT_AIX_STARTUP_SCRIPT_DIR=/etc/rc.d/init.d
ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR=/usr/lib/systemd/system
ZBX_DEFAULT_LINUX_SYSTEMD_UNIT=zabbix-agent

_command_exists() {
	type "$1" &> /dev/null
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

if _command_exists printf ; then
	PRINTF_BIN=$(which printf)
	if [ ! -f "${PRINTF_BIN}" ]; then
		PRINTF_BIN="printf"
	fi
else
	echo "ERROR: Command 'printf' not found."
	exit 1
fi

if [[ "$(uname -s)" = "AIX" ]]; then
	ECHO_BIN="echo"
else
	if _command_exists echo ; then
        	ECHO_BIN=$(which echo)
	        if [ ! -f "${ECHO_BIN}" ]; then
        	        ECHO_BIN="echo"
	        fi
	else
        	${PRINTF_BIN} "%s" "Error: Command \"echo\" not found."
	        exit 1
	fi
fi

if _command_exists tr ; then
	TR_BIN=$(which tr)
else
	${ECHO_BIN} "Error: Command 'tr' not found."
	exit 1
fi

if _command_exists sed ; then
	SED_BIN=$(which sed)
else
	${ECHO_BIN} "Error: Command 'sed' not found."
	exit 1
fi

if _command_exists grep ; then
	GREP_BIN=$(which grep)
else
	${ECHO_BIN} "Error: Command 'grep' not found."
	exit 1
fi

if _command_exists awk ; then
	AWK_BIN=$(which awk)
else
	${ECHO_BIN} "Error: Command 'awk' not found."
	exit 1
fi

_aix_version() {
	oslevel -s | awk -F- '{printf "AIX %.1f - Technology Level %d - Service Pack %d\n",$1/1000,$2,$3}'
}

_detect_linux_distrib() {
	local DIST=$1
	local REV=$2
	local PSUEDONAME=$3
	echo -n "Detecting your Linux distrib: "
	case "${DIST}" in
		Ubuntu)
			echo -n "${DIST} ${REV}"
			case "${REV}" in
			14.04|16.04|18.04|19.10|20.04)
				echo " (${PSUEDONAME})"
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
				echo " (${PSUEDONAME})"
				;;
			*)
				_unknown_distrib
				;;
			esac
			;;
		"Red Hat"*)
			echo "${DIST} ${REV} (${PSUEDONAME})"
			;;
		CentOS)
			echo "${DIST} ${REV} (${PSUEDONAME})"
			;;
		*)
			echo "Unsupported (${DIST} | ${REV} | ${PSUEDONAME})"
			_unknown_distrib
			;;
	esac
}

PLATFORM="unknown"
OS=$(uname -s)
OS_ARCH=$(uname -m)
${ECHO_BIN} -n "Detecting your OS: "
case "${OS}" in
	Linux*)
		${ECHO_BIN} "Linux (${OS_ARCH})"
		PLATFORM="linux"
		DISTROBASEDON="Unknown"
		DIST="Unknown"
		PSUEDONAME="Unknown"
		REV="Unknown"
		if [ -f "/etc/redhat-release" ]; then
			DISTROBASEDON="RedHat"
			DIST=$(cat /etc/redhat-release | ${SED_BIN} s/\ release.*//)
			PSUEDONAME=$(cat /etc/redhat-release | ${SED_BIN} s/.*\(// | ${SED_BIN} s/\)//)
			REV=$(cat /etc/redhat-release | ${SED_BIN} s/.*release\ // | ${SED_BIN} s/\ .*//)
		elif [ -f "/etc/SuSE-release" ]; then
			DISTROBASEDON="SUSE"
			DIST="SuSE"
			PSUEDONAME=$(cat /etc/SuSE-release | ${TR_BIN} "\n" ' '| ${SED_BIN} s/VERSION.*//)
			REV=$(cat /etc/SuSE-release | ${TR_BIN} "\n" ' ' | ${SED_BIN} s/.*=\ //)
		elif [ -f "/etc/mandrake-release" ]; then
			DISTROBASEDON="Mandrake"
			DIST="Mandrake"
			PSUEDONAME=$(cat /etc/mandrake-release | ${SED_BIN} s/.*\(// | ${SED_BIN} s/\)//)
			REV=$(cat /etc/mandrake-release | ${SED_BIN} s/.*release\ // | ${SED_BIN} s/\ .*//)
		elif [ -f "/etc/debian_version" ]; then
			if [ -f "/etc/lsb-release" ]; then
				DISTROBASEDON="Debian"
				DIST=$(cat /etc/lsb-release | ${GREP_BIN} '^DISTRIB_ID' | ${AWK_BIN} -F=  '{ print $2 }')
				PSUEDONAME=$(cat /etc/lsb-release | ${GREP_BIN} '^DISTRIB_CODENAME' | ${AWK_BIN} -F=  '{ print $2 }')
				REV=$(cat /etc/lsb-release | ${GREP_BIN} '^DISTRIB_RELEASE' | ${AWK_BIN} -F=  '{ print $2 }')
			elif [ -f "/etc/os-release" ]; then
				DISTROBASEDON="Debian"
				DIST=$(cat /etc/os-release | ${GREP_BIN} '^NAME' | ${AWK_BIN} -F=  '{ print $2 }' | ${GREP_BIN} -oP '(?<=\")(\w+)(?=\ )')
				PSUEDONAME=$(cat /etc/os-release | ${GREP_BIN} '^VERSION=' | ${AWK_BIN} -F= '{ print $2 }' | ${GREP_BIN} -oP '(?<=\()(\w+)(?=\))')
				REV=$(${SED_BIN} 's/\..*//' /etc/debian_version)
			fi
		fi
		_detect_linux_distrib "${DIST}" "${REV}" "${PSUEDONAME}"
		;;
	AIX|Darwin)
		_aix_version
		PLATFORM="aix"
		;;
	*)
		${ECHO_BIN} "Unknown"
		_unknown_os
		;;
esac

echo -n "Checking your privileges... "
CURRENT_USER=$(whoami)
if [[ "${CURRENT_USER}" = "root" ]]; then
	echo "OK"
else
	echo "Error: root access is required"
	exit 1
fi

# Checking the availability of necessary utilities
echo -n "Checking the availability of necessary utilities... "
if [[ "${PLATFORM}" = "aix" ]]; then
	COMMAND_EXIST_ARRAY=(LS DATE CP MV ID GROUPS WHOAMI PS TAIL CUT RM XARGS CAT WC DIRNAME USERMOD CHMOD CHOWN HEAD LSUSER LSGROUP)
else
	COMMAND_EXIST_ARRAY=(LS DATE CP MV ID GROUPS WHOAMI PS TAIL CUT RM XARGS CAT WC DIRNAME USERMOD CHMOD CHOWN HEAD)
fi
for ((i=0; i<${#COMMAND_EXIST_ARRAY[@]}; i++)); do
	__CMDVAR=${COMMAND_EXIST_ARRAY[$i]}
	CMD_FIND=$(${ECHO_BIN} "${__CMDVAR}" | ${TR_BIN} '[:upper:]' '[:lower:]')
	if _command_exists ${CMD_FIND} ; then
		eval $__CMDVAR'_BIN'="'$(which ${CMD_FIND})'"
		hash "${CMD_FIND}"
	else
		echo "Error: Command '${CMD_FIND}' not found."
		exit 1
	fi
done
${ECHO_BIN} "OK"

if [[ "${PLATFORM}" = "linux" ]]; then
	if _command_exists strings ; then
		OS_INIT_SYSTEM=$(strings /sbin/init | ${AWK_BIN} 'match($0, /(upstart|systemd|sysvinit)/) { print toupper(substr($0, RSTART, RLENGTH));exit; }')
	else
		OS_INIT=$(${LS_BIN} -l $(which init) | ${GREP_BIN} -c "systemd")
		if [ ${OS_INIT} -eq 1 ]; then
			OS_INIT_SYSTEM="SYSTEMD"
		else
			OS_INIT_SYSTEM="OTHER"
		fi
	fi
fi

if [ -f "/etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.conf" ]; then
	${ECHO_BIN} "Error: Found alternative zabbix config /etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.conf"
	exit 1
fi

if [ -f "/etc/init.d/zabbix-agent-${ZBX_AGENT_PREFIX}"  ]; then
	${ECHO_BIN} "Error: Found alternative zabbix init.d script /etc/init.d/zabbix-agent-${ZBX_AGENT_PREFIX}"
	exit 1
fi

if [ ! -d "/etc/zabbix" ]; then
	${ECHO_BIN} "Error: Config directory for zabbix-agent not found."
	exit 1
fi

if [ ! -f "/etc/zabbix/zabbix_agentd.conf" ]; then
	${ECHO_BIN} "Error: Standart config file for zabbix-agent not found."
	exit 1
fi

${ECHO_BIN} -n "Creating zabbix-agent-${ZBX_AGENT_PREFIX} config file... "
if [[ "${PLATFORM}" = "linux" ]]; then
(cat <<-EOF
PidFile=/var/run/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.pid
LogFile=/var/log/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.log
LogFileSize=5
Server=${ZBX_SERVERS_LIST}
ServerActive=${ZBX_SERVERS_LIST_ACTIVE}
ListenPort=${ZBX_AGENT_LOCAL_PORT}
HostMetadata=Linux
Include=/etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.d/*.conf
EOF
) > "/etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.conf"
elif [[ "${PLATFORM}" = "aix" ]]; then
(cat <<-EOF
PidFile=/var/run/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.pid
LogFile=/var/log/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.log
LogFileSize=5
Server=${ZBX_SERVERS_LIST}
ServerActive=${ZBX_SERVERS_LIST_ACTIVE}
ListenPort=${ZBX_AGENT_LOCAL_PORT}
HostMetadata=AIX
Include=/etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.d/*.conf
EOF
) > "/etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.conf"
else
(cat <<-EOF
PidFile=/var/run/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.pid
LogFile=/var/log/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.log
LogFileSize=5
Server=${ZBX_SERVERS_LIST}
ServerActive=${ZBX_SERVERS_LIST_ACTIVE}
ListenPort=${ZBX_AGENT_LOCAL_PORT}
Include=/etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.d/*.conf
EOF
) > "/etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.conf"
fi
if [ $? -eq 0 ]; then
	${ECHO_BIN} "OK"
else
	${ECHO_BIN} "Error"
	exit 1
fi

${ECHO_BIN} -n "Creating zabbix-agent-${ZBX_AGENT_PREFIX}.d directory... "
mkdir "/etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.d" >/dev/null 2>&1
if [ $? -eq 0 ]; then
	${ECHO_BIN} "OK"
else
	${ECHO_BIN} "Error"
	exit 1
fi

if [ ! -d "/var/run/zabbix" ]; then
	${ECHO_BIN} -n "Creating zabbix pid file directory... "
	mkdir "/var/run/zabbix" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		${ECHO_BIN} "OK"
	else
		${ECHO_BIN} "Error"
		exit 1
	fi
	chown ${ZBX_DEFAULT_USER}:${ZBX_DEFAULT_GROUP} "/var/run/zabbix" >/dev/null 2>&1
fi

if [ ! -d "/var/log/zabbix" ]; then
	${ECHO_BIN} -n "Creating zabbix log file directory... "
	mkdir "/var/log/zabbix" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		${ECHO_BIN} "OK"
	else
		${ECHO_BIN} "Error"
		exit 1
	fi
	chown ${ZBX_DEFAULT_USER}:${ZBX_DEFAULT_GROUP} "/var/log/zabbix" >/dev/null 2>&1
fi

if [[ "${PLATFORM}" = "linux" ]]; then
	if [ -f "/etc/logrotate.d/zabbix-agent" ]; then
		${ECHO_BIN} -n "Creating zabbix logrotate rule... "
		cat "/etc/logrotate.d/zabbix-agent" | sed "s@zabbix_agentd.log@zabbix_agentd_${ZBX_AGENT_PREFIX}.log@g" > "/etc/logrotate.d/zabbix-agent-${ZBX_AGENT_PREFIX}"
		if [ $? -eq 0 ]; then
			${ECHO_BIN} "OK"
		else
			${ECHO_BIN} "Error"
			exit 1
		fi
	fi
fi

if [[ "${PLATFORM}" = "linux" ]]; then
	if [ -f "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent" ]; then
		${ECHO_BIN} -n "Creating zabbix init script... "
		cat "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent" | sed "s@zabbix_agentd.conf@zabbix_agentd_${ZBX_AGENT_PREFIX}.conf@g" > "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
		if [ $? -eq 0 ]; then
			${ECHO_BIN} "OK"
		else
			${ECHO_BIN} "Error"
		fi
		chmod a+x "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}" >/dev/null 2>&1
		${ECHO_BIN} -n "Adding zabbix to startup... "
		EXIT_CODE=1
		case "${DIST}" in
			Ubuntu|Debian)
				sed -i "s@zabbix-agent@zabbix-agent-${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				sed -i "s@NAME=zabbix_agentd@NAME=zabbix_agentd_${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				sed -i "s@DAEMON=/usr/sbin/\$NAME@DAEMON=/usr/sbin/zabbix_agentd@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				sed -i "s@Zabbix agent@Zabbix agent ${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				sed -i "s@RETRY=15@RETRY=15\nOPTS=\"-c /etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.conf\"@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				sed -i "s@--exec \$DAEMON@--exec \$DAEMON -- \$OPTS@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
					systemctl daemon-reload
					systemctl enable ${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service >/dev/null 2>&1
					EXIT_CODE=$?
				else
					update-rc.d zabbix-agent-${ZBX_AGENT_PREFIX} defaults >/dev/null 2>&1
					EXIT_CODE=$?
				fi
				;;
			"Red Hat"*)
				sed -i "s@Zabbix agent daemon@Zabbix agent daemon ${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				sed -i "s@zabbix-agent@zabbix-agent-${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
					systemctl daemon-reload
					systemctl enable ${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service >/dev/null 2>&1
					EXIT_CODE=$?
				else
					chkconfig --add zabbix-agent-${ZBX_AGENT_PREFIX} >/dev/null 2>&1
					EXIT_CODE=$?
					chkconfig --level 2345 zabbix-agent-${ZBX_AGENT_PREFIX} on >/dev/null 2>&1
				fi
				;;
			CentOS)
				sed -i "s@Zabbix agent daemon@Zabbix agent daemon ${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				sed -i "s@zabbix-agent@zabbix-agent-${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
				if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
					systemctl daemon-reload
					systemctl enable ${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service >/dev/null 2>&1
					EXIT_CODE=$?
				else
					chkconfig --add zabbix-agent-${ZBX_AGENT_PREFIX} >/dev/null 2>&1
					EXIT_CODE=$?
					chkconfig --level 2345 zabbix-agent-${ZBX_AGENT_PREFIX} on >/dev/null 2>&1
				fi
				;;
		esac
		if [ ${EXIT_CODE} -eq 0 ]; then
			${ECHO_BIN} "OK"
		else
			${ECHO_BIN} "Error"
		fi
	elif [ -f "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}.service" ]; then
		${ECHO_BIN} -n "Creating zabbix systemd unit script... "
		cat "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}.service" | sed "s@zabbix_agentd.conf@zabbix_agentd_${ZBX_AGENT_PREFIX}.conf@g" > "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
		if [ $? -eq 0 ]; then
			${ECHO_BIN} "OK"
		else
			${ECHO_BIN} "Error"
		fi
		${ECHO_BIN} -n "Adding zabbix to startup... "
		EXIT_CODE=1
		case "${DIST}" in
			Ubuntu|Debian)
				sed -i "s@Zabbix Agent@Zabbix Agent ${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
				sed -i "s@zabbix-agent@zabbix-agent-${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
				sed -i "s@zabbix_agentd.pid@zabbix_agentd_${ZBX_AGENT_PREFIX}.pid@g" "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
				;;
			"Red Hat"*)
				sed -i "s@Zabbix Agent@Zabbix Agent ${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
				sed -i "s@zabbix-agent@zabbix-agent-${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
				sed -i "s@zabbix_agentd.pid@zabbix_agentd_${ZBX_AGENT_PREFIX}.pid@g" "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
				;;
			CentOS)
				sed -i "s@Zabbix Agent@Zabbix Agent ${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
				sed -i "s@zabbix-agent@zabbix-agent-${ZBX_AGENT_PREFIX}@g" "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
				sed -i "s@zabbix_agentd.pid@zabbix_agentd_${ZBX_AGENT_PREFIX}.pid@g" "${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT_DIR}/${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service"
				;;
		esac
		systemctl daemon-reload
		systemctl enable ${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service >/dev/null 2>&1
		EXIT_CODE=$?
		if [ ${EXIT_CODE} -eq 0 ]; then
			${ECHO_BIN} "OK"
		else
			${ECHO_BIN} "Error"
		fi
	else
		${ECHO_BIN} "Warning: Zabbix-agent sysv init or systemd unit script not found."
	fi
elif [[ "${PLATFORM}" = "aix" ]]; then
	if [ ! -f "${ZBX_DEFAULT_AIX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}" ]; then
		${ECHO_BIN} -n "Creating zabbix init script... "
		(cat <<-EOF
#!/bin/sh
##########################################################
###### Zabbix agent ${ZBX_AGENT_PREFIX} daemon init script
##########################################################
test -x /sbin/zabbix_agentd || exit 5
case "\$1" in
start)
        echo "Starting zabbix_agent_${ZBX_AGENT_PREFIX}..."
        /sbin/zabbix_agentd -c /etc/zabbix/zabbix_agentd_${ZBX_AGENT_PREFIX}.conf
        ;;
stop)
        echo "Stopping zabbix_agent_${ZBX_AGENT_PREFIX}..."
        kill -TERM \$(cat /var/run/zabbix/zabbix_agentd.pid)
        ;;
restart)
        echo "Restarting zabbix_agent_${ZBX_AGENT_PREFIX}..."
        \$0 stop
        sleep 3
        \$0 start
        ;;
*)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;
esac
		EOF
		) > "${ZBX_DEFAULT_AIX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}"
		if [ $? -eq 0 ]; then
			${ECHO_BIN} "OK"
			chmod a+x "${ZBX_DEFAULT_AIX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}" >/dev/null 2>&1
			ln -s "${ZBX_DEFAULT_AIX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}" "/etc/rc.d/rc2.d/S95zabbix-agent-${ZBX_AGENT_PREFIX}" >/dev/null 2>&1
			ln -s "${ZBX_DEFAULT_AIX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}" "/etc/rc.d/rc2.d/K95zabbix-agent-${ZBX_AGENT_PREFIX}" >/dev/null 2>&1
		else
			${ECHO_BIN} "Error"
		fi
	fi
fi

if [ ! -d "${ZBX_DEFAULT_HOME_DIR}" ]; then
	${ECHO_BIN} -n "Creating zabbix home directory... "
	mkdir "${ZBX_DEFAULT_HOME_DIR}" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		${ECHO_BIN} "OK"
	else
		${ECHO_BIN} "Error"
	fi
fi

if [ -d "${ZBX_DEFAULT_HOME_DIR}" ]; then
	if [[ "${PLATFORM}" = "linux" ]]; then
		ZBX_HOME_DIR_CHECK=$(getent passwd "${ZBX_DEFAULT_USER}" | ${CUT_BIN} -d':' -f 6)
	elif [[ "${PLATFORM}" = "aix" ]]; then
		ZBX_HOME_DIR_CHECK=$(${LSUSER_BIN} -a home ${ZBX_DEFAULT_USER} | ${CUT_BIN} -d'=' -f 2)
	else
		ZBX_HOME_DIR_CHECK=${ZBX_DEFAULT_HOME_DIR}
	fi
	if [[ "${PLATFORM}" = "linux" ]]; then
		if [ -n "${ZBX_HOME_DIR_CHECK}" ]; then
			ZBX_HOME_DIR_CHECK="$(${ECHO_BIN} "${ZBX_HOME_DIR_CHECK}" | ${SED_BIN} 's/\/$//')"
			ZBX_DEFAULT_HOME_DIR="$(${ECHO_BIN} "${ZBX_DEFAULT_HOME_DIR}" | ${SED_BIN} 's/\/$//')"
			if [ "${ZBX_HOME_DIR_CHECK}" != "${ZBX_DEFAULT_HOME_DIR}" ]; then
				${ECHO_BIN} -n "Set home directory for user \"${ZBX_DEFAULT_USER}\"... "
				usermod -d "${ZBX_DEFAULT_HOME_DIR}" ${ZBX_DEFAULT_USER}  >/dev/null 2>&1
				if [ $? -eq 0 ]; then
					${ECHO_BIN} "OK"
				else
					${ECHO_BIN} "Error: Home dir not set"
				fi
			fi
		fi
	fi
	${ECHO_BIN} -n "Set home directory permitions... "
	chown -R ${ZBX_DEFAULT_USER}:${ZBX_DEFAULT_GROUP} "${ZBX_DEFAULT_HOME_DIR}"  >/dev/null 2>&1
	chmod -R 775 "${ZBX_DEFAULT_HOME_DIR}"  >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		${ECHO_BIN} "OK"
	else
		${ECHO_BIN} "Error"
	fi
fi

_zabbix_agent_start_stop() {
	local DBS_ZBX_AGENT_COMMAND=${1:-"restart"}
	local EXIT_CODE=1
	local ERR_MSG=""
	local ZBX_AGENT_CNT=0
	case "${DBS_ZBX_AGENT_COMMAND}" in
		stop)
			${ECHO_BIN} -n "Stoping zabbix-agent-${ZBX_AGENT_PREFIX}... "
			;;
		start)
			${ECHO_BIN} -n "Starting zabbix-agent-${ZBX_AGENT_PREFIX}... "
			;;
		restart)
			${ECHO_BIN} -n "Restarting zabbix-agent-${ZBX_AGENT_PREFIX}... "
			;;
		*)
			${ECHO_BIN} "Func: ${FUNCNAME[0]}: Unknown command"
			return 1
		;;
	esac
	if [[ "${PLATFORM}" = "linux" ]]; then
		if [[ "${OS_INIT_SYSTEM}" = "SYSTEMD" ]]; then
			systemctl start ${ZBX_DEFAULT_LINUX_SYSTEMD_UNIT}-${ZBX_AGENT_PREFIX}.service >/dev/null 2>&1
			EXIT_CODE=$?
		else
			if [ -f "${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}" ]; then
				${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX} ${DBS_ZBX_AGENT_COMMAND} >/dev/null 2>&1
				EXIT_CODE=$?
			else
				ERR_MSG="NotFoundStartupScript"
			fi
		fi
	elif [[ "${PLATFORM}" = "aix" ]]; then
		if [ -f "${ZBX_DEFAULT_AIX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX}" ]; then
			${ZBX_DEFAULT_AIX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX} ${DBS_ZBX_AGENT_COMMAND} >/dev/null 2>&1
			EXIT_CODE=$?
		else
			ERR_MSG="NotFoundStartupScript"
		fi
	else
		${ZBX_DEFAULT_LINUX_STARTUP_SCRIPT_DIR}/zabbix-agent-${ZBX_AGENT_PREFIX} ${DBS_ZBX_AGENT_COMMAND} >/dev/null 2>&1
		EXIT_CODE=$?
	fi
	if [ ${EXIT_CODE} -eq 0 ]; then
		ZBX_AGENT_CNT=$(ps -ef | ${GREP_BIN} -c "[z]abbix_agentd_${ZBX_AGENT_PREFIX}")
		if [ ${ZBX_AGENT_CNT} -gt 0 ]; then
			${ECHO_BIN} "OK"
		else
			${ECHO_BIN} "NotRunning"
		fi
	else
		if [ -n "${ERR_MSG}" ]; then
			${ECHO_BIN} "Error: ${ERR_MSG}"
		else
			${ECHO_BIN} "Error"
		fi
	fi
}

ZBX_AGENT_CNT=$(ps -ef | grep -c "[z]abbix_agentd_${ZBX_AGENT_PREFIX}")
if [ ${ZBX_AGENT_CNT} -gt 0 ]; then
	_zabbix_agent_start_stop "start"
else
	_zabbix_agent_start_stop "restart"
fi
