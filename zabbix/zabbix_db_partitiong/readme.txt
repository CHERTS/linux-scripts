!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! IMPORTANT! Do not run on a production environment! Test first in a test environment !!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

zabbix_create_partition_v1.sh - simple partitioning on a clean zabbix database without data
zabbix_create_partition_v2.sh - advanced partitioning with copying data in different ways without downtime

=============================================================================================================================================

Run simple partitiong for new zabbix database
---------------------------------------------

1) Edit zabbix_create_partition_v1.conf

2) Stop zabbix server:

# systemctl stop zabbix-server

3) Run script zabbix_create_partition_v1.sh:

# ./zabbix_create_partition_v1.sh
29.10.2021 11:03:37: Now connected to database 'zabbix'
29.10.2021 11:03:37: Get min clock from table 'history', please wait... 2021-10-29
29.10.2021 11:03:37: Start creating alter table and save to file 'history_parted.sql'
29.10.2021 11:03:37: Start date (Y-m-d): 2021-10-28
29.10.2021 11:03:37: End date (Y-m-d): 2021-10-30
29.10.2021 11:03:37: Done create file 'history_parted.sql'.
29.10.2021 11:03:37: Get min clock from table 'history_uint', please wait... 2021-10-29
29.10.2021 11:03:37: Start creating alter table and save to file 'history_uint_parted.sql'
29.10.2021 11:03:37: Start date (Y-m-d): 2021-10-28
29.10.2021 11:03:37: End date (Y-m-d): 2021-10-30
29.10.2021 11:03:37: Done create file 'history_uint_parted.sql'.
29.10.2021 11:03:37: Get min clock from table 'history_str', please wait... 2021-10-29
29.10.2021 11:03:37: Start creating alter table and save to file 'history_str_parted.sql'
29.10.2021 11:03:37: Start date (Y-m-d): 2021-10-28
29.10.2021 11:03:37: End date (Y-m-d): 2021-10-30
29.10.2021 11:03:37: Done create file 'history_str_parted.sql'.
29.10.2021 11:03:37: Get min clock from table 'history_log', please wait... NULL, skip
29.10.2021 11:03:37: Get min clock from table 'history_text', please wait... NULL, skip
29.10.2021 11:03:37: Get min clock from table 'trends', please wait... 2021-10-29
29.10.2021 11:03:37: Start creating alter table and save to file 'trends_parted.sql'
29.10.2021 11:03:37: Start date (Y-m-d): 2021-10-28
29.10.2021 11:03:37: End date (Y-m-d): 2021-10-30
29.10.2021 11:03:37: Done create file 'trends_parted.sql'.
29.10.2021 11:03:37: Get min clock from table 'trends_uint', please wait... 2021-10-29
29.10.2021 11:03:37: Start creating alter table and save to file 'trends_uint_parted.sql'
29.10.2021 11:03:37: Start date (Y-m-d): 2021-10-28
29.10.2021 11:03:37: End date (Y-m-d): 2021-10-30
29.10.2021 11:03:37: Done create file 'trends_uint_parted.sql'.

4) Creating service procedure

# mysql zabbix
MariaDB [zabbix]> source zabbix_partitiong_function_create.sql;
Database changed
Query OK, 0 rows affected (0.004 sec)

Query OK, 0 rows affected (0.003 sec)

Query OK, 0 rows affected (0.004 sec)

Query OK, 0 rows affected (0.003 sec)

Query OK, 0 rows affected (0.003 sec)

MariaDB [zabbix]> source zabbix_event_create.sql;
Database changed
Query OK, 0 rows affected (0.002 sec)

5) If set ZBX_AUTO_CREATE_TABLE_PARTS=0 in zabbix_create_partition_v1.conf then running creating partition manualy.
   If set ZBX_AUTO_CREATE_TABLE_PARTS=1 in zabbix_create_partition_v1.conf then skip this step.

MariaDB [zabbix]> source history_parted.sql;
Query OK, 117 rows affected (0.033 sec)
Records: 117  Duplicates: 0  Warnings: 0

MariaDB [zabbix]> source history_str_parted.sql;
Query OK, 1 row affected (0.023 sec)
Records: 1  Duplicates: 0  Warnings: 0

MariaDB [zabbix]> source history_uint_parted.sql;
Query OK, 36 rows affected (0.033 sec)
Records: 36  Duplicates: 0  Warnings: 0

MariaDB [zabbix]> source trends_parted.sql;
Query OK, 58 rows affected (0.023 sec)
Records: 58  Duplicates: 0  Warnings: 0

MariaDB [zabbix]> source trends_uint_parted.sql;
Query OK, 16 rows affected (0.031 sec)
Records: 16  Duplicates: 0  Warnings: 0

6) Checking partitions exist:

# mysql zabbix
MariaDB [zabbix]> SELECT TABLE_SCHEMA, TABLE_NAME,PARTITION_NAME, IFNULL(TABLE_ROWS,0) AS TABLE_ROWS, IFNULL(DATA_LENGTH,0) AS DATA_LENGTH, IFNULL(INDEX_LENGTH,0) AS INDEX_LENGTH, IFNULL((DATA_LENGTH + INDEX_LENGTH),0) AS ALL_LENGTH FROM information_schema.partitions WHERE PARTITION_NAME IS NOT NULL;

+--------------+--------------+----------------+------------+-------------+--------------+------------+
| TABLE_SCHEMA | TABLE_NAME   | PARTITION_NAME | TABLE_ROWS | DATA_LENGTH | INDEX_LENGTH | ALL_LENGTH |
+--------------+--------------+----------------+------------+-------------+--------------+------------+
| zabbix       | history_uint | p202110270000  |          0 |       16384 |        16384 |      32768 |
| zabbix       | history_uint | p202110280000  |          0 |       16384 |        16384 |      32768 |
| zabbix       | history_uint | p202110290000  |         36 |       16384 |        16384 |      32768 |
| zabbix       | history      | p202110270000  |          0 |       16384 |        16384 |      32768 |
| zabbix       | history      | p202110280000  |          0 |       16384 |        16384 |      32768 |
| zabbix       | history      | p202110290000  |        117 |       16384 |        16384 |      32768 |
| zabbix       | trends       | p202110270000  |          0 |       16384 |            0 |      16384 |
| zabbix       | trends       | p202110280000  |          0 |       16384 |            0 |      16384 |
| zabbix       | trends       | p202110290000  |         58 |       16384 |            0 |      16384 |
| zabbix       | trends_uint  | p202110270000  |          0 |       16384 |            0 |      16384 |
| zabbix       | trends_uint  | p202110280000  |          0 |       16384 |            0 |      16384 |
| zabbix       | trends_uint  | p202110290000  |         16 |       16384 |            0 |      16384 |
| zabbix       | history_str  | p202110270000  |          0 |       16384 |        16384 |      32768 |
| zabbix       | history_str  | p202110280000  |          0 |       16384 |        16384 |      32768 |
| zabbix       | history_str  | p202110290000  |          0 |       16384 |        16384 |      32768 |
+--------------+--------------+----------------+------------+-------------+--------------+------------+
15 rows in set (0.100 sec)

7) Checking event exist:

# mysql zabbix
MariaDB [zabbix]> show events;
+--------+----------------------+----------------+-----------+-----------+------------+----------------+----------------+---------------------+------+---------+------------+----------------------+----------------------+--------------------+
| Db     | Name                 | Definer        | Time zone | Type      | Execute at | Interval value | Interval field | Starts              | Ends | Status  | Originator | character_set_client | collation_connection | Database Collation |
+--------+----------------------+----------------+-----------+-----------+------------+----------------+----------------+---------------------+------+---------+------------+----------------------+----------------------+--------------------+
| zabbix | zabbix_partition_mgr | root@localhost | SYSTEM    | RECURRING | NULL       | 1              | DAY            | 2021-10-29 01:00:00 | NULL | ENABLED |          1 | utf8                 | utf8_general_ci      | utf8_bin           |
+--------+----------------------+----------------+-----------+-----------+------------+----------------+----------------+---------------------+------+---------+------------+----------------------+----------------------+--------------------+
1 row in set (0.002 sec)

8) Checking event scheduler is running:

# mysql zabbix
MariaDB [zabbix]> show processlist;
+-----+-----------------+-----------+--------+---------+------+-----------------------------+------------------+----------+
| Id  | User            | Host      | db     | Command | Time | State                       | Info             | Progress |
+-----+-----------------+-----------+--------+---------+------+-----------------------------+------------------+----------+
|   1 | event_scheduler | localhost | NULL   | Daemon  | 1633 | Waiting for next activation | NULL             |    0.000 |
| 385 | root            | localhost | zabbix | Query   |    0 | starting                    | show processlist |    0.000 |
+-----+-----------------+-----------+--------+---------+------+-----------------------------+------------------+----------+
2 rows in set (0.000 sec)

MariaDB [zabbix]> quit;

9) Start zabbix server

# systemctl start zabbix-server

 41574:20211029:111156.880 Starting Zabbix Server. Zabbix 5.4.7 (revision 84dc2ec5dc).
 41574:20211029:111156.880 ****** Enabled features ******
 41574:20211029:111156.880 SNMP monitoring:           YES
 41574:20211029:111156.880 IPMI monitoring:           YES
 41574:20211029:111156.880 Web monitoring:            YES
 41574:20211029:111156.880 VMware monitoring:         YES
 41574:20211029:111156.880 SMTP authentication:       YES
 41574:20211029:111156.880 ODBC:                      YES
 41574:20211029:111156.880 SSH support:               YES
 41574:20211029:111156.880 IPv6 support:              YES
 41574:20211029:111156.880 TLS support:               YES
 41574:20211029:111156.880 ******************************
 41574:20211029:111156.880 using configuration file: /etc/zabbix/zabbix_server.conf
 41574:20211029:111156.887 current database version (mandatory/optional): 05040000/05040000
 41574:20211029:111156.887 required mandatory version: 05040000
 41574:20211029:111156.899 server #0 started [main process]
 41575:20211029:111156.900 server #1 started [configuration syncer #1]
 41576:20211029:111157.004 server #2 started [alert manager #1]
 41577:20211029:111157.007 server #3 started [alerter #1]
 41578:20211029:111157.008 server #4 started [alerter #2]
 ......
 41612:20211029:111157.044 server #38 started [history poller #1]
 41616:20211029:111157.047 server #42 started [history poller #5]
 41617:20211029:111157.047 server #43 started [availability manager #1]
 41615:20211029:111157.048 server #41 started [history poller #4]

10) Go to Zabbix web interface and disable housekeeper (history and trends)

Congratulations! All tables are partitioned.

=============================================================================================================================================

Advanced partitioning with copying data in different ways without downtime
--------------------------------------------------------------------------

This is a complex procedure and should be carried out by a professional. Please contact me at sleuthhound@gmail.com and I will help you. Do not run the zabbix_create_partition_v2.sh script without consulting the shift!

(c) 2020-2023 by Mikhail Grigorev <sleuthhound@gmail.com>
