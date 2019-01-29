#!/bin/bash

#
# For incrise SSD disk performance for transaction-based applications/databases, the following configuration is recommended
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

DEV_ID=$1

if [ -z "${DEV_ID}" ]; then
        echo "ERROR: Disk ID not set."
        echo ""
        echo "Usage: $0 DISKID"
        exit 1
fi

DEV_NAME=$(ls -al /dev/disk/by-id/ | grep "${DEV_ID} " | grep "/sd" | awk '{split($11,arr,"/"); print arr[3]}')

if [ -n "${DEV_NAME}" ]; then
	echo "Device: ${DEV_NAME}"
	echo "Set scheduler = deadline"
	echo "deadline" > /sys/block/${DEV_NAME}/queue/scheduler
	echo "Set nr_requests = 2048"
	echo "2048" > /sys/block/${DEV_NAME}/queue/nr_requests
	MAX_HW_SECTORS_KB=$(cat /sys/block/${DEV_NAME}/queue/max_hw_sectors_kb)
	if [ ${MAX_HW_SECTORS_KB} -gt 1024 ]; then
		echo "Set max_sectors_kb = 1024"
		echo "1024" > /sys/block/${DEV_NAME}/queue/max_sectors_kb
	fi
	echo "Set queue_depth = 768"
	echo "768" > /sys/block/${DEV_NAME}/device/queue_depth
	echo "Set rq_affinity = 2"
	echo "2" > /sys/block/${DEV_NAME}/queue/rq_affinity
	echo "Set rotational = 0"
	echo "0" > /sys/block/${DEV_NAME}/queue/rotational
	echo "Set add_random = 0"
	echo "0" > /sys/block/${DEV_NAME}/queue/add_random
	echo "Set nomerges = 0"
	echo "0" > /sys/block/${DEV_NAME}/queue/nomerges
	echo "Set Read-Ahead = 0 sectors"
	blockdev --setra 0 /dev/${DEV_NAME}
fi
