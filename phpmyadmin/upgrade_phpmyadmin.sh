#!/usr/bin/env bash
#
# Program: Upgrade phpMyAdmin and migrate old settings to new version <upgrade_phpmyadmin.sh>
#
# Author: Mikhail Grigorev < sleuthhound at gmail dot com >
# 
# Current Version: 1.0.1
#
# Revision History:
#
#  Version 1.0.1
#    Added checking exist wget util
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

MYADMIN_VER="4.9.1"
MYADMIN_DST_DIR=/var/www/apps
MYADMIN_SUBDIR=phpmyadmin
WWW_USER=apps
WWW_GROUP=apps

_command_exists() {
	type "$1" &> /dev/null
}

if _command_exists wget ; then
        WGET_BIN=$(which wget)
else
        echo "ERROR: 'wget' not found."
        exit 1
fi

if [ ! -d "${MYADMIN_DST_DIR}" ]; then
	echo "ERROR: Directory '${MYADMIN_DST_DIR}' not exist."
	exit 1
fi

cd "${MYADMIN_DST_DIR}"

echo -n "Downloading new version (v${MYADMIN_VER}) of phpMyAdmin... "
wget "https://files.phpmyadmin.net/phpMyAdmin/${MYADMIN_VER}/phpMyAdmin-${MYADMIN_VER}-all-languages.zip" >/dev/null 2>&1
if [ $? -eq 0 ]; then
	if [ -f "phpMyAdmin-${MYADMIN_VER}-all-languages.zip" ]; then
		echo "OK"
	else
		echo "ERR #1"
		exit 1
	fi
else
	echo "ERR #2"
	exit 1
fi

if [ -d "phpMyAdmin-${MYADMIN_VER}-all-languages" ]; then
	rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages" 2>/dev/null
fi

if [ -f "phpMyAdmin-${MYADMIN_VER}-all-languages.zip" ]; then
	echo -n "Extracting new version of phpMyAdmin... "
	unzip -q "phpMyAdmin-${MYADMIN_VER}-all-languages.zip" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "OK"
	else
		echo "ERR"
		exit 1
	fi
	if [ -d "phpMyAdmin-${MYADMIN_VER}-all-languages" ]; then
		if [ -d "${MYADMIN_SUBDIR}" ]; then
			echo -n "Copying old phpMyAdmin settings to a new directory... "
			cp -- "${MYADMIN_SUBDIR}/config.inc.php" "phpMyAdmin-${MYADMIN_VER}-all-languages" 2>/dev/null
			if [ $? -eq 0 ]; then
				echo "OK"
			else
				echo "ERR"
			fi
		fi
		echo -n "Set owner ${WWW_USER}:${WWW_GROUP}... "
		chown -R ${WWW_USER}:${WWW_GROUP} "phpMyAdmin-${MYADMIN_VER}-all-languages" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "OK"
		else
			echo "ERR"
		fi
		echo -n "Removing unnecessary languages and additional files... "
		rm -f "phpMyAdmin-${MYADMIN_VER}-all-languages/CONTRIBUTING.md" 2>/dev/null
		rm -f "phpMyAdmin-${MYADMIN_VER}-all-languages/RELEASE-DATE-${MYADMIN_VER}" 2>/dev/null
		rm -f "phpMyAdmin-${MYADMIN_VER}-all-languages/README" 2>/dev/null
		rm -f "phpMyAdmin-${MYADMIN_VER}-all-languages/LICENSE" 2>/dev/null
		rm -f "phpMyAdmin-${MYADMIN_VER}-all-languages/ChangeLog" 2>/dev/null
		rm -f "phpMyAdmin-${MYADMIN_VER}-all-languages/DCO" 2>/dev/null
		rm -f "phpMyAdmin-${MYADMIN_VER}-all-languages/composer.json" 2>/dev/null
		rm -f "phpMyAdmin-${MYADMIN_VER}-all-languages/composer.lock" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/examples" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/az" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/ar" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/be" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/bg" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/bn" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/ca" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/cs" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/da" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/de" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/el" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/es" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/et" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/fi" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/fr" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/gl" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/he" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/hu" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/hy" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/ia" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/id" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/it" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/ja" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/jo" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/lt" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/nb" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/nl" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/pl" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/pt" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/pt_BR" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/ro" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/si" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/sk" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/sl" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/sq" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/sr@latin" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/sv" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/tr" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/uk" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/vi" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/zh_CN" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/zh_TW" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/ko" 2>/dev/null
		rm -rf "phpMyAdmin-${MYADMIN_VER}-all-languages/locale/kk" 2>/dev/null
		echo "OK"
		if [ -d "${MYADMIN_SUBDIR}_old" ]; then
			rm -rf "${MYADMIN_SUBDIR}_old" 2>/dev/null
		fi
		if [ -d "${MYADMIN_SUBDIR}" ]; then
			echo -n "Move older '${MYADMIN_SUBDIR}' to '${MYADMIN_SUBDIR}_old'... "
			mv "${MYADMIN_SUBDIR}" "${MYADMIN_SUBDIR}_old" 2>/dev/null
			if [ $? -eq 0 ]; then
				echo "OK"
			else
				echo "ERR"
			fi
		fi
		if [ ! -d "${MYADMIN_SUBDIR}" ]; then
			echo -n "Installing new phpMyAdmin version... "
			mv "phpMyAdmin-${MYADMIN_VER}-all-languages" "${MYADMIN_SUBDIR}" 2>/dev/null
			if [ $? -eq 0 ]; then
				echo "OK"
				if [ -d "${MYADMIN_SUBDIR}_old" ]; then
					rm -rf "${MYADMIN_SUBDIR}_old" 2>/dev/null
				fi
			else
				echo "ERR"
			fi
		fi
		rm -f "phpMyAdmin-${MYADMIN_VER}-all-languages.zip" 2>/dev/null
	else
		echo "ERROR: Directory 'phpMyAdmin-${MYADMIN_VER}-all-languages' not found."
	fi
else
	echo "ERROR: File 'phpMyAdmin-${MYADMIN_VER}-all-languages.zip' not found."
fi
