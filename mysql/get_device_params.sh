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
	echo "/sys/block/${DEV_NAME}/queue/scheduler: $(cat /sys/block/${DEV_NAME}/queue/scheduler)"
	echo "/sys/block/${DEV_NAME}/queue/nr_requests: $(cat /sys/block/${DEV_NAME}/queue/nr_requests)"
	echo "/sys/block/${DEV_NAME}/queue/max_sectors_kb: $(cat /sys/block/${DEV_NAME}/queue/max_sectors_kb)"
	echo "/sys/block/${DEV_NAME}/device/queue_depth: $(cat /sys/block/${DEV_NAME}/device/queue_depth)"
	echo "/sys/block/${DEV_NAME}/queue/rq_affinity: $(cat /sys/block/${DEV_NAME}/queue/rq_affinity)"
	echo "/sys/block/${DEV_NAME}/queue/rotational: $(cat /sys/block/${DEV_NAME}/queue/rotational)"
	echo "/sys/block/${DEV_NAME}/queue/add_random: $(cat /sys/block/${DEV_NAME}/queue/add_random)"
	echo "/sys/block/${DEV_NAME}/queue/nomerges: $(cat /sys/block/${DEV_NAME}/queue/nomerges)"
	echo "Read-Ahead: $(blockdev --getra /dev/${DEV_NAME})"
fi
