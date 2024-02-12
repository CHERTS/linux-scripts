#!/bin/bash

#
# Program: YancexCloud wrapper for psql <yc_psql.sh>
#
# Author: Mikhail Grigorev <sleuthhound at gmail dot com>
#
# Current Version: 1.2
#
# Revision History:
#
#  Version 1.2
#    Added getting password from Vault
#
#  Version 1.1
#    Added dynamic select cluster, database and user via Yandex.Cloud CLI tool
#
#  Version 1.0
#    Initial Release
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# Default settings
DEFAULT_DATABASE="postgres"
DEFAULT_PORT="6432"
DEFAULT_USERNAME="postgres"
# For MacOS use:
# EDB PostgreSQL installer: https://www.enterprisedb.com/downloads/postgres-postgresql-downloads
# or
# Postgres.app installer: https://postgresapp.com/documentation/install.html
#
# For Linux use:
# apt-get install postgres-client
# or
# yum install postgres-client
PSQL_MANUAL_BIN_PATH="/Applications/Postgres.app/Contents/Versions/16/bin"
PSQL_BIN_NAME=psql
# Use usql client, see https://github.com/xo/usql
# For Mac OS use:
# brew tap xo/xo
# brew install --with-odbc usql
#PSQL_MANUAL_BIN_PATH="/usr/local/Cellar/usql/0.17.5/bin"
#PSQL_BIN_NAME=usql
# Last connection history file
YC_LAST_CONN_FILE="$HOME/.yc_psql_last_conn"
# Host template: c-$CLUSTERID.$YC_HOST_SUFFIX
YC_HOST_SUFFIX="rw.mdb.yandexcloud.net"
# Vault path
VAULT_PATH="mycompany/yandexcloud"

# Don't edit this config
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPT_NAME=$(basename "$0")
RET=1
VERSION="1.2"

# Check command exist function
_command_exists() {
	type "$1" &> /dev/null
}

# Detect psql
if _command_exists ${PSQL_BIN_NAME}; then
	PSQL_BIN=$(which ${PSQL_BIN_NAME})
	PSQL_BIN_PATH=$(dirname "${PSQL_BIN}")
else
	PSQL_BIN_PATH=${PSQL_MANUAL_BIN_PATH}
fi

# Detect YandexCloud CLI
if _command_exists yc; then
    YC_BIN=$(which yc)
else
	echo "ERROR: YandexCloud CLI binary not found."
	exit 1
fi

# Detect Vault CLI
if _command_exists vault; then
	VAULT_BIN=$(which vault)
else
	echo "ERROR: Vault binary not found."
	exit 1
fi

echo
echo "Simple wrapper for connecting to PostgreSQL in YandexCloud via ${PSQL_BIN_NAME} v${VERSION}"                                                                                                  
echo

if [ ! -f "${PSQL_BIN_PATH}/${PSQL_BIN_NAME}" ]; then
	echo "ERROR: Not found ${PSQL_BIN_NAME} binary file '${PSQL_BIN_PATH}/${PSQL_BIN_NAME}'"
	echo
	echo "For MacOS use:"
	echo "EDB PostgreSQL installer: https://www.enterprisedb.com/downloads/postgres-postgresql-downloads"
	echo "or"
	echo "Postgres.app installer: https://postgresapp.com/documentation/install.html"
	echo
	echo "For Linux use:"
	echo "apt-get install postgres-client"
	echo "or"
	echo "yum install postgres-client"
	exit 1
fi

# Confirm dialog
_confirm_simple() {
	read -r -p "${1:-Are you sure? [y/N]} " RESPONSE
	case "${RESPONSE}" in
		[yY][eE][sS]|[yY]) 
			true
			;;
		*)
			false
			;;
	esac
}

# Confirm dialog
_confirm() {
    local RET=true
    while $RET; do
        read -r -p "${1:-Are you sure? [y/N]} " RESPONSE
        case "${RESPONSE}" in
            [yY][eE][sS]|[yY])
                RET=true
                break
                ;;
            [nN][oO]|[nN])
                RET=false
                ;;
            *)
                echo "Invalid response"
                ;;
        esac
    done
    $RET
}

_connect_last_pg() {
	local PROFILE=${1:-""}
	local CLUSTER=${2:-""}
	local CLUSTERID=${3:-""}
	local PORT=${4:-"${DEFAULT_PORT}"}
	local USERNAME=${5:-"${DEFAULT_USERNAME}"}
	local DATABASE=${6:-"${DEFAULT_DATABASE}"}

	local SERVICE_NAME="${CLUSTER//_/-}-pg"
	local VAULT_SERVICE_PREFIX="${VAULT_PATH}/${PROFILE}/${SERVICE_NAME}"
	echo "Getting PostgreSQL password from Vault path '${VAULT_SERVICE_PREFIX}'..."
	if [[ "${USERNAME}" == "${CLUSTER}" ]]; then
	    local PG_PASSWD=$(vault kv get -field=password "${VAULT_SERVICE_PREFIX}" 2>/dev/null)
	else
    	local PG_PASSWD=$(vault kv get -field=password_${USERNAME} "${VAULT_SERVICE_PREFIX}" 2>/dev/null)
	fi

	if [ -n "${PG_PASSWD}" ]; then
    	echo "Password found in Vault."
	    export PGPASSWORD=${PG_PASSWD}
	fi

	if [ -n "${CLUSTERID}" ]; then
		echo "Connecting to Cluster ID: ${CLUSTERID}"
		if [[ "${PSQL_BIN_NAME}" == "usql" ]]; then
			${PSQL_BIN_PATH}/${PSQL_BIN_NAME} "postgres://${USERNAME}@c-${CLUSTERID}.${YC_HOST_SUFFIX}:${PORT}/${DATABASE}"
		else
			${PSQL_BIN_PATH}/${PSQL_BIN_NAME} -h "c-${CLUSTERID}.${YC_HOST_SUFFIX}" -p ${PORT} -U ${USERNAME} ${DATABASE}
		fi
		RET=$?
	else
		echo "Last connection info not found. Exit."
		rm -f "${YC_LAST_CONN_FILE}" >/dev/null 2>&1
		exit 1
	fi

	if [ ${RET} -eq 0 ]; then
		echo "Bay."
	else
		echo "An error occurred while connecting with the last saved connection config."
		_confirm "Would you really like to remove last connection config? [y/N]" && rm -f "${YC_LAST_CONN_FILE}" >/dev/null 2>&1
	fi

	if [ ${RET} -ne 0 ]; then
		echo
		echo -n "Press <return> to continue..."
		read dummy
	fi
}

_connect_pg() {
	CLUSTERID=${1:-"xxxxxx"}
	PORT=${2:-"${DEFAULT_PORT}"}
	USERNAME=${3:-"${DEFAULT_USERNAME}"}
	DATABASE=${4:-"${DEFAULT_DATABASE}"}

	if [[ "${PSQL_BIN_NAME}" == "usql" ]]; then
		${PSQL_BIN_PATH}/${PSQL_BIN_NAME} "postgres://${USERNAME}@c-${CLUSTERID}.${YC_HOST_SUFFIX}:${PORT}/${DATABASE}"
	else
		${PSQL_BIN_PATH}/${PSQL_BIN_NAME} -h "c-${CLUSTERID}.${YC_HOST_SUFFIX}" -p ${PORT} -U ${USERNAME} ${DATABASE}
	fi

	RET=$?

	if [ ${RET} -eq 0 ]; then
		echo "Write last connection config..."
		(cat<<-EOF
		PG_PROFILE=${YC_PROFILE}
		PG_CLUSTER=${YC_CLUSTER}
		PG_CLUSTERID=${CLUSTERID}
		PG_PORT=${PORT}
		PG_USERNAME=${USERNAME}
		PG_DATABASE=${DATABASE}
		EOF
		)>"${YC_LAST_CONN_FILE}"
		echo "Done. Bay."
	fi

	if [ ${RET} -ne 0 ]; then
		echo
		echo -n "Press <return> to continue..."
		read dummy
	fi
}

# Check the command line
if [ $# -ne 0 -a $# -ne 1 ]; 
then
	echo "Usage: $0 [wait]"
	exit 127
fi

if [ -f "${YC_LAST_CONN_FILE}" ]; then
	source "${YC_LAST_CONN_FILE}"
	echo "Note: Found last connection config:"
	echo "Note: PROFILE: ${PG_PROFILE}"
	echo "Note: CLUSTER: ${PG_CLUSTER}"
	echo "Note: CLUSTERID: ${PG_CLUSTERID}"
	echo "Note: PORT: ${PG_PORT}"
	echo "Note: USERNAME: ${PG_USERNAME}"
	echo "Note: DATABASE: ${PG_DATABASE}"
	echo "Note: Select CONNECT string on the next step to"
	echo "Note: load configuration or select new cluster name."
	echo
fi

YC_CLI_PROFILES=($(${YC_BIN} config profile list 2>/dev/null | tr -d " ACTIVE"))

if [ -f "${YC_LAST_CONN_FILE}" ]; then
    YC_CLI_FULL_PROFILES=(${YC_CLI_PROFILES[@]} "CONNECT" "Quit")
else
    YC_CLI_FULL_PROFILES=(${YC_CLI_PROFILES[@]} "Quit")
fi

echo "Select Yandex.Cloud CLI profile:"
shopt -s extglob;   
select PROFILE in "${YC_CLI_FULL_PROFILES[@]}"; do
	case ${PROFILE} in
		+([a-z\_]))
			${YC_BIN} config profile activate "${PROFILE}" 2>/dev/null
			if [ $? -eq 0 ]; then
				YC_PROFILE=${PROFILE}
				break
			else
				echo "ERROR: Profile '${PROFILE}' not ready to use. Exit"
				exit 1
			fi
			;;
		"CONNECT")
			YC_PROFILE=""
			CLUSTERID=""
			break
			;;
		"Quit")
			echo "Exit"
			exit 0
			;;
		*)
			echo "Not available"
			;;
	esac
done
shopt -u extglob;

if [ -z "${YC_PROFILE}" ];
then
    if [ -f "${YC_LAST_CONN_FILE}" ]; then
        source "${YC_LAST_CONN_FILE}"
        _connect_last_pg "${PG_PROFILE}" "${PG_CLUSTER}" "${PG_CLUSTERID}" "${PG_PORT}" "${PG_USERNAME}" "${PG_DATABASE}"
        exit ${RET}
    else
		YC_PROFILE="default"
    fi
fi

echo "Getting cluster list, please wait..."
YC_PG_CLUSTERS=($(${YC_BIN} managed-postgresql cluster list --profile "${YC_PROFILE}" --format json 2>/dev/null | jq '.[].name' 2>/dev/null | tr -d \"))

if [ ${#YC_PG_CLUSTERS[@]} -eq 0 ]; then
	echo "ERROR: No clusters were found in the '${YC_PROFILE}' profile."
	echo "ERROR: Setup your profile and restart the utility."
	exit 1
fi

echo "Select cluster:"
shopt -s extglob;   
select CLUSTER in "${YC_PG_CLUSTERS[@]}" "Quit"; do
	case ${CLUSTER} in
		+([a-z\_]))
			echo "Cluster '${CLUSTER}' selected"
			YC_CLUSTER=${CLUSTER}
			echo "Getting cluster id and database list, please wait..."
			CLUSTERID=$(${YC_BIN} managed-postgresql cluster list --profile "${YC_PROFILE}" --format json 2>/dev/null | jq '.[] | if .name=='\"${CLUSTER}\"' then .id else empty end' 2>/dev/null | tr -d \")
			break
			;;
		"Quit")
			echo "Exit"
			exit 0
			;;
		*)
			echo "Not available"
			;;
	esac
done
shopt -u extglob;

YC_PG_DATABASES=($(${YC_BIN} managed-postgresql database list --profile "${YC_PROFILE}" --cluster-id ${CLUSTERID} --format json 2>/dev/null | jq '.[].name' 2>/dev/null | tr -d \"))

echo "Select database:"
shopt -s extglob;   
select DB in "${YC_PG_DATABASES[@]}" "Quit"; do
	case ${DB} in
		+([a-z\_]))
			echo "Database '${DB}' selected"
			DATABASE=${DB}
			break
			;;
		"Quit")
			echo "Exit"
			exit 0
			;;
		*)
			echo "Not available"
			;;
	esac
done
shopt -u extglob;

if [ -z "${DATABASE}" ];
then
	DATABASE="${DEFAULT_DATABASE}"
fi

echo -n "Port [${DEFAULT_PORT}]: "
read PORT

if [ -z "${PORT}" ];
then
	PORT="${DEFAULT_PORT}"
fi

YC_PG_USERS=($(${YC_BIN} managed-postgresql user list --profile "${YC_PROFILE}" --cluster-id ${CLUSTERID} --format json 2>/dev/null | jq 'map(select(.login == true and .name != "postgres_exporter"))' | jq '.[].name' 2>/dev/null | tr -d \"))

echo "Select user:"
shopt -s extglob;   
select USER in "${YC_PG_USERS[@]}" "Quit"; do
	case ${USER} in
		+([a-z\_]))
			echo "User '${USER}' selected"
			USERNAME=${USER}
			break
			;;
		"Quit")
			echo "Exit"
			exit 0
			;;
		*)
			echo "Not available"
		;;
	esac
done
shopt -u extglob;

if [ -z "${USERNAME}" ];
then
	USERNAME="${DEFAULT_USERNAME}"
fi

echo

SERVICE_NAME="${YC_CLUSTER//_/-}-pg"
VAULT_SERVICE_PREFIX="${VAULT_PATH}/${YC_PROFILE}/${SERVICE_NAME}"
echo "Getting PostgreSQL password from Vault path '${VAULT_SERVICE_PREFIX}'..."
if [[ "${USERNAME}" == "${YC_CLUSTER}" ]]; then
	PG_PASSWD=$(vault kv get -field=password "${VAULT_SERVICE_PREFIX}" 2>/dev/null)
else
	PG_PASSWD=$(vault kv get -field=password_${USERNAME} "${VAULT_SERVICE_PREFIX}" 2>/dev/null)
fi

if [ -n "${PG_PASSWD}" ]; then
	echo "Password found in Vault."
	export PGPASSWORD=${PG_PASSWD}
fi

_connect_pg "${CLUSTERID}" "${PORT}" "${USERNAME}" "${DATABASE}"

exit ${RET}
