#!/usr/bin/env bash

#
# Program: Calculating swap usage <show-swap-usage.sh>
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
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# Requirements:
#   Requires mktemp
#
# Installation:
#   Copy the shell script to a suitable location
#
# Tested platforms:
#  -- Debian 8 using /bin/bash
#  -- Debian 9 using /bin/bash
#  -- Ubuntu 16.04.3 using /bin/bash
#  -- Oracle Linux Server 6.1 using /bin/bash
#
# Usage:
# ./show-swap-usage.sh <sorting by {pid|kB|name} [default: kB]>
#
# Example:
# ./show-swap-usage.sh
# or
# ./show-swap-usage.sh pid
#

SCRIPT_NAME=`basename $0`;
SORT="kb";
[ "$1" != "" ] && { SORT="$1"; }

[ ! -x `which mktemp` ] && { echo "ERROR: mktemp is not available!"; exit 1; }
MKTEMP=`which mktemp`;
TMP=`${MKTEMP} -d`;
[ ! -d "${TMP}" ] && { echo "ERROR: Unable to create temp dir!"; exit 1; }

[ $EUID -ne 0 ] && { echo "ERROR: $SCRIPT_NAME must be run as root" 1>&2; exit 1; }

>${TMP}/${SCRIPT_NAME}.pid;
>${TMP}/${SCRIPT_NAME}.kb;
>${TMP}/${SCRIPT_NAME}.name;

SUM=0;
OVERALL=0;
echo "${OVERALL}" > ${TMP}/${SCRIPT_NAME}.overal;

echo -n "Calculating swap usage, please wait..."
for DIR in `find /proc/ -maxdepth 1 -type d -regex "^/proc/[0-9]+"`;
do
    PID=`echo $DIR | cut -d / -f 3`
    PROGNAME=`ps -p $PID -o comm --no-headers`
    for SWAP in `grep Swap $DIR/smaps 2>/dev/null| awk '{ print $2 }'`
    do
        let SUM=$SUM+$SWAP
    done

    if (( $SUM > 0 ));
    then
        echo -n ".";
        echo -e "${PID}\t${SUM}\t${PROGNAME}" >> ${TMP}/${SCRIPT_NAME}.pid;
        echo -e "${SUM}\t${PID}\t${PROGNAME}" >> ${TMP}/${SCRIPT_NAME}.kb;
        echo -e "${PROGNAME}\t${SUM}\t${PID}" >> ${TMP}/${SCRIPT_NAME}.name;
    fi
    let OVERALL=$OVERALL+$SUM
    SUM=0
done
echo "Done"
echo "${OVERALL}" > ${TMP}/${SCRIPT_NAME}.overal;
echo;
echo "========================================";
case "${SORT}" in
    name )
        echo -e "name\tkB\tpid";
        echo "========================================";
        cat ${TMP}/${SCRIPT_NAME}.name|sort -r;
        ;;

    kb )
        echo -e "kB\tpid\tname";
        echo "========================================";
        cat ${TMP}/${SCRIPT_NAME}.kb|sort -rh;
        ;;

    pid | * )
        echo -e "pid\tkB\tname";
        echo "========================================";
        cat ${TMP}/${SCRIPT_NAME}.pid|sort -rh;
        ;;
esac
echo "========================================";
echo "Total swapped memory: ${OVERALL} kB";
echo "========================================";
rm -fR "${TMP}/";
