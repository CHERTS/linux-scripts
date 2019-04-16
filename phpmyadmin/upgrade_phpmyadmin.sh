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

myadmin_ver="4.8.5"
myadmin_dst_dir=/var/www/apps
myadmin_dir=phpmyadmin
www_user=apps
www_group=apps

_command_exists() {
	type "$1" &> /dev/null
}

if _command_exists wget ; then
        WGET_BIN=$(which wget)
else
        echo "ERROR: wget not found."
        exit 1
fi

if [ ! -d "${myadmin_dst_dir}" ]; then
	echo "ERROR: Directory ${myadmin_dst_dir} not exist."
	exit 1
fi

cd "${myadmin_dst_dir}"

echo -n "Downloading new version (v${myadmin_ver}) of phpMyAdmin... "
wget "https://files.phpmyadmin.net/phpMyAdmin/${myadmin_ver}/phpMyAdmin-${myadmin_ver}-all-languages.zip" >/dev/null 2>&1
if [ $? -eq 0 ]; then
	if [ -f "phpMyAdmin-${myadmin_ver}-all-languages.zip" ]; then
		echo "OK"
	else
		echo "ERR #1"
		exit 1
	fi
else
	echo "ERR #2"
	exit 1
fi

if [ -d "phpMyAdmin-${myadmin_ver}-all-languages" ]; then
	rm -rf "phpMyAdmin-${myadmin_ver}-all-languages" 2>/dev/null
fi

if [ -f "phpMyAdmin-${myadmin_ver}-all-languages.zip" ]; then
	echo -n "Extracting new version of phpMyAdmin... "
	unzip -q "phpMyAdmin-${myadmin_ver}-all-languages.zip"
	if [ $? -eq 0 ]; then
		echo "OK"
	else
		echo "ERR"
		exit 1
	fi
	if [ -d "phpMyAdmin-${myadmin_ver}-all-languages" ]; then
		if [ -d "${myadmin_dir}" ]; then
			echo -n "Copying old phpMyAdmin settings to a new directory... "
			cp -- "${myadmin_dir}/config.inc.php" "phpMyAdmin-${myadmin_ver}-all-languages" 2>/dev/null
			if [ $? -eq 0 ]; then
				echo "OK"
			else
				echo "ERR"
			fi
		fi
		echo -n "Set owner ${www_user}:${www_group}... "
		chown -R ${www_user}:${www_group} "phpMyAdmin-${myadmin_ver}-all-languages"
		if [ $? -eq 0 ]; then
			echo "OK"
		else
			echo "ERR"
		fi
		echo -n "Removing unnecessary languages and additional files... "
		rm -f "phpMyAdmin-${myadmin_ver}-all-languages/CONTRIBUTING.md" 2>/dev/null
		rm -f "phpMyAdmin-${myadmin_ver}-all-languages/RELEASE-DATE-${myadmin_ver}" 2>/dev/null
		rm -f "phpMyAdmin-${myadmin_ver}-all-languages/README" 2>/dev/null
		rm -f "phpMyAdmin-${myadmin_ver}-all-languages/LICENSE" 2>/dev/null
		rm -f "phpMyAdmin-${myadmin_ver}-all-languages/ChangeLog" 2>/dev/null
		rm -f "phpMyAdmin-${myadmin_ver}-all-languages/DCO" 2>/dev/null
		rm -f "phpMyAdmin-${myadmin_ver}-all-languages/composer.json" 2>/dev/null
		rm -f "phpMyAdmin-${myadmin_ver}-all-languages/composer.lock" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/examples" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/az" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/ar" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/be" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/bg" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/bn" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/ca" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/cs" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/da" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/de" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/el" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/es" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/et" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/fi" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/fr" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/gl" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/he" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/hu" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/hy" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/ia" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/id" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/it" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/ja" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/jo" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/lt" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/nb" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/nl" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/pl" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/pt" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/pt_BR" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/ro" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/si" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/sk" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/sl" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/sq" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/sr@latin" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/sv" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/tr" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/uk" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/vi" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/zh_CN" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/zh_TW" 2>/dev/null
		rm -rf "phpMyAdmin-${myadmin_ver}-all-languages/locale/ko" 2>/dev/null
		echo "OK"
		if [ -d "${myadmin_dir}_old" ]; then
			rm -rf "${myadmin_dir}_old" 2>/dev/null
		fi
		if [ -d "${myadmin_dir}" ]; then
			echo -n "Move older ${myadmin_dir} to ${myadmin_dir}_old... "
			mv "${myadmin_dir}" "${myadmin_dir}_old" 2>/dev/null
			if [ $? -eq 0 ]; then
				echo "OK"
			else
				echo "ERR"
			fi
		fi
		if [ ! -d "${myadmin_dir}" ]; then
			echo -n "Installing new phpMyAdmin version... "
			mv "phpMyAdmin-${myadmin_ver}-all-languages" "${myadmin_dir}" 2>/dev/null
			if [ $? -eq 0 ]; then
				echo "OK"
				if [ -d "${myadmin_dir}_old" ]; then
					rm -rf "${myadmin_dir}_old" 2>/dev/null
				fi
			else
				echo "ERR"
			fi
		fi
		rm -f "phpMyAdmin-${myadmin_ver}-all-languages.zip" 2>/dev/null
	else
		echo "ERROR: Directory phpMyAdmin-${myadmin_ver}-all-languages not found."
	fi
else
	echo "ERROR: File phpMyAdmin-${myadmin_ver}-all-languages.zip not found."
fi
