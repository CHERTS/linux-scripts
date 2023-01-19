DELIMITER $$
USE `zabbix` $$
CREATE EVENT `zabbix_partition_mgr`
       ON SCHEDULE EVERY 1 DAY
       STARTS '2022-06-01 23:59:00'
       ON COMPLETION PRESERVE
       ENABLE
       COMMENT 'Managing the creation and deletion of partitions in zabbix'
       DO BEGIN
            CALL zabbix.partition_maintenance_all('zabbix');
       END$$
DELIMITER ;
