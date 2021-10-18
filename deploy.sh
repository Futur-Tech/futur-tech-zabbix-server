#!/usr/bin/env bash

source "$(dirname "$0")/ft-util/ft_util_inc_var"

APP_NAME="futur-tech-zabbix-server"

SRC_DIR="/usr/local/src/${APP_NAME}"
SUDOERS_ETC="/etc/sudoers.d/${APP_NAME}"

$S_LOG -d $S_NAME "Start $S_DIR_NAME/$S_NAME $*"

echo
echo "------------------------------------------"
echo "  SETUP SUDOERS FILE"
echo "------------------------------------------"
echo

$S_LOG -d $S_NAME -d "$SUDOERS_ETC" "==============================="
$S_LOG -d $S_NAME -d "$SUDOERS_ETC" "==== SUDOERS CONFIGURATION ===="
$S_LOG -d $S_NAME -d "$SUDOERS_ETC" "==============================="

echo "Defaults:zabbix !requiretty" | sudo EDITOR='tee' visudo --file=$SUDOERS_ETC &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${SRC_DIR}/deploy-update.sh" | sudo EDITOR='tee -a' visudo --file=$SUDOERS_ETC &>/dev/null

cat $SUDOERS_ETC | $S_LOG -d "$S_NAME" -d "$SUDOERS_ETC" -i 

$S_LOG -d $S_NAME -d "$SUDOERS_ETC" "==============================="
$S_LOG -d $S_NAME -d "$SUDOERS_ETC" "==============================="

echo
echo "------------------------------------------"
echo "  APPLY TWEAKS"
echo "------------------------------------------"
echo


cd /usr/share/zabbix/include/

cp defines.inc.php defines.inc.php.bak

cmd() { 
    echo "===== ${1} : ${2} >> ${3} ====="
    echo "BEFORE: $(grep ${1} defines.inc.php)"
    sed -i -e "s/define('${1}', ${2});/define('${1}', ${3});/" defines.inc.php
    echo "AFTER: $(grep ${1} defines.inc.php)"
    echo
}

cmd ZBX_WIDGET_ROWS 20 200 
cmd ZBX_MAX_TABLE_COLUMNS 50 500 
cmd ZBX_MAX_IMAGE_SIZE "ZBX_MEBIBYTE" "ZBX_MEBIBYTE * 8" 

# echo
# echo "------------------------------------------"
# echo "  RESTART ZABBIX LATER"
# echo "------------------------------------------"
# echo

# echo "service zabbix-agent restart" | at now + 1 min &>/dev/null ## restart zabbix agent with a delay
# $S_LOG -s $? -d "$S_NAME" "Scheduling Zabbix Agent Restart"

$S_LOG -d "$S_NAME" "End $S_NAME"

exit