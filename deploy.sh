#!/usr/bin/env bash

source "$(dirname "$0")/ft-util/ft_util_inc_var"

APP_NAME="futur-tech-zabbix-server"

BIN_DIR="/usr/local/bin/${APP_NAME}"
SRC_DIR="/usr/local/src/${APP_NAME}"
SUDOERS_ETC="/etc/sudoers.d/${APP_NAME}"

# Checking which Zabbix Agent is detected and adjust include directory
$(which zabbix_agent2 >/dev/null) && ZBX_CONF_AGENT_D="/etc/zabbix/zabbix_agent2.d"
$(which zabbix_agentd >/dev/null) && ZBX_CONF_AGENT_D="/etc/zabbix/zabbix_agentd.conf.d"
if [ ! -d "${ZBX_CONF_AGENT_D}" ] ; then $S_LOG -s crit -d $S_NAME "${ZBX_CONF_AGENT_D} Zabbix Include directory not found" ; exit 10 ; fi

$S_LOG -d $S_NAME "Start $S_DIR_NAME/$S_NAME $*"

echo "
  INSTALL NEEDED PACKAGES & FILES
------------------------------------------"

if [ ! -d "${BIN_DIR}" ] ; then mkdir "${BIN_DIR}" ; $S_LOG -s $? -d $S_NAME "Creating ${BIN_DIR} returned EXIT_CODE=$?" ; fi

$S_DIR/ft-util/ft_util_file-deploy "$S_DIR/bin/" "${BIN_DIR}"
$S_DIR/ft-util/ft_util_file-deploy "$S_DIR/etc.zabbix/${APP_NAME}.conf" "${ZBX_CONF_AGENT_D}/${APP_NAME}.conf"

echo "
  SETUP SUDOERS FILE
------------------------------------------"

$S_LOG -d $S_NAME -d "$SUDOERS_ETC" "==============================="

echo "Defaults:zabbix !requiretty" | sudo EDITOR='tee' visudo --file=$SUDOERS_ETC &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${SRC_DIR}/deploy-update.sh" | sudo EDITOR='tee -a' visudo --file=$SUDOERS_ETC &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${BIN_DIR}/zabbix-server-version.sh" | sudo EDITOR='tee -a' visudo --file=$SUDOERS_ETC &>/dev/null

cat $SUDOERS_ETC | $S_LOG -d "$S_NAME" -d "$SUDOERS_ETC" -i 

$S_LOG -d $S_NAME -d "$SUDOERS_ETC" "==============================="

echo "
  APPLY TWEAKS
------------------------------------------"


cd /usr/share/zabbix/include/
cp defines.inc.php defines.inc.php.bak

define_inc() { 
    echo "===== ${1} : ${2} >> ${3} ====="
    echo "BEFORE: $(grep ${1} defines.inc.php)"
    sed -i -e "s/define('${1}', ${2});/define('${1}', ${3});/" defines.inc.php
    echo "AFTER: $(grep ${1} defines.inc.php)"
    echo
}

define_inc ZBX_WIDGET_ROWS 20 200 
define_inc ZBX_MAX_TABLE_COLUMNS 50 500 
define_inc ZBX_MAX_IMAGE_SIZE "ZBX_MEBIBYTE" "ZBX_MEBIBYTE * 8" 
define_inc SVG_GRAPH_MAX_NUMBER_OF_METRICS 50 500 
diff defines.inc.php.bak defines.inc.php | $S_LOG -d $S_NAME -d "tweak" -d "defines.inc.php diff" -i

# Remove 0 values from GUI Graph Hintbox
cd /usr/share/zabbix/js/
cp class.csvggraph.js class.csvggraph.js.bak
sed -i -e 's/if (show_hint \&\& data.hintMaxRows > rows_added) {/if (show_hint \&\& data.hintMaxRows \> rows_added \&\& \!point.v.match(\/^0( \\w*)?$\/)) {/' class.csvggraph.js
diff class.csvggraph.js.bak class.csvggraph.js | $S_LOG -d $S_NAME -d "tweak" -d "class.csvggraph.js diff" -i

echo "
  RESTART ZABBIX LATER
------------------------------------------"

echo "systemctl restart zabbix-agent*" | at now + 1 min &>/dev/null ## restart zabbix agent with a delay
$S_LOG -s $? -d "$S_NAME" "Scheduling Zabbix Agent Restart"

$S_LOG -d "$S_NAME" "End $S_NAME"

exit