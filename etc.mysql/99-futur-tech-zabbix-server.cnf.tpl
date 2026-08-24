###############################################################################
# Futur-Tech Zabbix Server - MariaDB fine tuning
#
# Deployed by futur-tech-zabbix-server/deploy.sh
# DO NOT EDIT ON THE SERVER - edit it in the git repo, it is overwritten on
# every deploy.
#
# This file lives in /etc/mysql/mariadb.conf.d/ and is read AFTER the Debian
# package file 50-server.cnf, so every value here wins. 50-server.cnf is kept
# pristine on purpose: package upgrades can then replace it without ever
# touching our tuning, and without prompting for a config conflict.
#
# THIS IS A TEMPLATE. deploy.sh substitutes the placeholders below with
# values computed from the host's RAM and free disk space, then deploys the
# result. Everything else is copied verbatim.
#
# Baseline: the tuning previously held inline in 50-server.cnf (2025-09-06),
# written for MariaDB 10.6. Tuned for a Zabbix DB host on NVMe, write-heavy.
###############################################################################

[mysqld]

### PATHS
# datadir is deliberately set here rather than left to the package default.
# The Debian package file ships it commented out, so without this the server
# silently falls back to /var/lib/mysql and tries to create an empty database.
datadir                       = @@DATADIR@@
tmpdir                        = /tmp
socket                        = /run/mysqld/mysqld.sock

### CHARACTER SET
# Kept explicitly: the Debian 11.8 package file dropped these, and MariaDB
# 11.4+ changed the default utf8mb4 collation to utf8mb4_uca1400_ai_ci.
# Pinning them keeps newly created tables consistent with the existing schema.
character-set-server          = utf8mb4
collation-server              = utf8mb4_general_ci

### MEMORY
# Computed by deploy.sh as a percentage of MemTotal (see innodb_bufpool_pct).
# Deliberately below the 75-80% usual for a dedicated database machine, because
# zabbix-server, Apache and PHP share this host and need their own headroom.
innodb_buffer_pool_size       = @@BUFFER_POOL_SIZE@@

### REDO LOG
# CHANGED 2026-08-25: was `innodb_log_file_size = 3G` + `innodb_log_files_in_group = 4`,
# intending ~12G of total redo. innodb_log_files_in_group was REMOVED in MariaDB
# 10.5 and has been silently ignored ever since, so the server was actually
# running on 3G of redo - a quarter of the intended capacity, forcing far more
# frequent checkpoint flushing.
#
# Computed by deploy.sh as half the buffer pool, then capped at a quarter of the
# space actually free on datadir. That cap matters: InnoDB aborts startup with
# error 28 if it cannot preallocate the redo file, taking the server down.
innodb_log_file_size          = @@LOG_FILE_SIZE@@
innodb_log_buffer_size        = 256M

### FLUSHING / DURABILITY (NVMe)
innodb_flush_method           = O_DIRECT
innodb_flush_log_at_trx_commit= 2          # throughput-friendly for Zabbix
innodb_flush_log_at_timeout   = 10
innodb_adaptive_flushing      = 1
innodb_flush_neighbors        = 0          # SSD/NVMe

### PARALLEL I/O
innodb_read_io_threads        = 8
innodb_write_io_threads       = 8

### I/O CAPACITY (NVMe RAID1 start point; tune with real IOPS)
innodb_io_capacity            = 5000
innodb_io_capacity_max        = 20000

### MISC FOR WRITE-HEAVY
# REMOVED 2026-08-25: `innodb_change_buffering = all` - the InnoDB change buffer
# was removed outright in MariaDB 11.0. The setting no longer exists and the
# server logs a warning for it at every startup.
innodb_lru_scan_depth         = 2048       # Faster page refresh on larger pools
innodb_doublewrite            = 1          # Keep ON unless FS is fully crash-safe
innodb_adaptive_hash_index    = 1          # Usually helps mixed read/write (default ON)

### SERVER-LEVEL BASICS FOR ZABBIX
table_open_cache              = 4096
open_files_limit              = 65535
max_connections               = 300
thread_cache_size             = 100
