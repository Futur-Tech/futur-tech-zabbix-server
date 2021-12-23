#!/usr/bin/env bash
zabbix_server -V | grep "zabbix_server (Zabbix)" | egrep -o "\w+\.\w+\.\w+"
