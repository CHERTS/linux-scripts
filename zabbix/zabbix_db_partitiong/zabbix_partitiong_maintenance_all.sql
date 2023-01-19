DELIMITER $$
DROP PROCEDURE partition_maintenance_all;
CREATE PROCEDURE `partition_maintenance_all`(SCHEMA_NAME VARCHAR(32))
BEGIN
DECLARE DBStatus Integer;
--SELECT COUNT(1) INTO DBStatus FROM performance_schema.replication_connection_status;
SELECT @@global.read_only INTO DBStatus;
IF DBStatus = 0 THEN
                CALL partition_maintenance(SCHEMA_NAME, 'history', 30, 24, 3);
                CALL partition_maintenance(SCHEMA_NAME, 'history_log', 30, 24, 3);
                CALL partition_maintenance(SCHEMA_NAME, 'history_str', 30, 24, 3);
                CALL partition_maintenance(SCHEMA_NAME, 'history_text', 30, 24, 3);
                CALL partition_maintenance(SCHEMA_NAME, 'history_uint', 30, 24, 3);
                CALL partition_maintenance(SCHEMA_NAME, 'trends', 3650, 24, 3);
                CALL partition_maintenance(SCHEMA_NAME, 'trends_uint', 3650, 24, 3);
END IF;
END$$
DELIMITER ;
