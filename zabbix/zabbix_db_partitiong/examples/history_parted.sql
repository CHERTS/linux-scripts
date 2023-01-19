ALTER TABLE `history` PARTITION BY RANGE (clock)
(PARTITION p202110270000 VALUES LESS THAN (UNIX_TIMESTAMP("2021-10-28 00:00:00")) ENGINE = InnoDB,
PARTITION p202110280000 VALUES LESS THAN (UNIX_TIMESTAMP("2021-10-29 00:00:00")) ENGINE = InnoDB,
PARTITION p202110290000 VALUES LESS THAN (UNIX_TIMESTAMP("2021-10-30 00:00:00")) ENGINE = InnoDB);
