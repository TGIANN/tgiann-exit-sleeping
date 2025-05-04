CREATE TABLE IF NOT EXISTS `tgiann_exit_sleeping` (
  `citizenid` varchar(50) DEFAULT NULL,
  `sleepData` longtext DEFAULT NULL,
  `unixTime` int(11) DEFAULT unix_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;