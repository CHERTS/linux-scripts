# A scripts to automate the Clickhouse working

clickhouse-backup.sh - A script to automate the creating Clickhouse backup via clickhouse-backup

[See latest release version](https://github.com/Altinity/clickhouse-backup/releases/latest)

Installing clickhouse-backup (debian package)
```
CLB_VER=2.6.35
wget https://github.com/AlexAkulov/clickhouse-backup/releases/download/v${CLB_VER}/clickhouse-backup_${CLB_VER}_amd64.deb
dpkg -i clickhouse-backup_${CLB_VER}_amd64.deb && rm -f clickhouse-backup_${CLB_VER}_amd64.deb
cp /etc/clickhouse-backup/config.yml.example /etc/clickhouse-backup/config.yml
chmod 600 /etc/clickhouse-backup/config.yml
```

Edit clickhouse-backup settings
```
vim /etc/clickhouse-backup/config.yml
```

Setup clickhouse-backup.sh script 
```
mkdir /var/lib/clickhouse/scripts
cp clickhouse-backup.sh /var/lib/clickhouse/scripts
chmod a+x /var/lib/clickhouse/scripts/clickhouse-backup.sh
```

Edit script config (see avaliable settings in clickhouse-backup.sh)
```
vim /var/lib/clickhouse/scripts/clickhouse-backup.conf
```

Adding crontab task
```
0 1 * * * /var/lib/clickhouse/scripts/clickhouse-backup.sh >/dev/null 2>&1
```

See log file
```
tail -n 100 /var/log/clickhouse-server/clickhouse-backup.log
```
