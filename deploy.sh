#!/usr/bin/env bash

source "$(dirname "$0")/ft-util/ft_util_inc_func"
source "$(dirname "$0")/ft-util/ft_util_inc_var"
source "$(dirname "$0")/ft-util/ft_util_sudoersd"
source "$(dirname "$0")/ft-util/ft_util_usrmgmt"

app_name="futur-tech-zabbix-server"

bin_dir="/usr/local/bin/${app_name}"
src_dir="/usr/local/src/${app_name}"
php_confd="/etc/php/8.2/apache2/conf.d"

# Checking which Zabbix Agent is detected and adjust include directory
$(which zabbix_agent2 >/dev/null) && zbx_conf_agent_d="/etc/zabbix/zabbix_agent2.d"
$(which zabbix_agentd >/dev/null) && zbx_conf_agent_d="/etc/zabbix/zabbix_agentd.conf.d"
if [ ! -d "${zbx_conf_agent_d}" ]; then
  $S_LOG -s crit -d $S_NAME "${zbx_conf_agent_d} Zabbix Include directory not found"
  exit 10
fi

echo "
  INSTALL NEEDED PACKAGES & FILES
------------------------------------------"

[ ! -d "${bin_dir}" ] && run_cmd_log mkdir "${bin_dir}"
$S_DIR/ft-util/ft_util_file-deploy "$S_DIR/bin/" "${bin_dir}"
enforce_security exec "$bin_dir" zabbix

$S_DIR/ft-util/ft_util_file-deploy "$S_DIR/etc.zabbix/${app_name}.conf" "${zbx_conf_agent_d}/${app_name}.conf"

$S_DIR/ft-util/ft_util_file-deploy "$S_DIR/etc.php/00-${app_name}.ini" "${php_confd}/00-${app_name}.ini"
run_cmd_log systemctl restart apache2

bak_if_exist "/etc/sudoers.d/${app_name}"
sudoersd_reset_file $app_name zabbix
sudoersd_addto_file $app_name zabbix "${S_DIR_PATH}/deploy-update.sh"
sudoersd_addto_file $app_name zabbix "${bin_dir}/zabbix-server-version.sh"
show_bak_diff_rm "/etc/sudoers.d/${app_name}"

echo "
  APPLY TWEAKS
------------------------------------------"

define_inc() {
  echo "===== ${1} : ${2} >> ${3} ====="
  echo "BEFORE: $(grep ${1} $defines_inc_php)"
  sed -i -e "s/define('${1}', ${2});/define('${1}', ${3});/" $defines_inc_php
  echo "AFTER: $(grep ${1} $defines_inc_php)"
  echo
}

defines_inc_php="/usr/share/zabbix/include/defines.inc.php"
bak_if_exist $defines_inc_php

define_inc ZBX_WIDGET_ROWS 20 200
define_inc ZBX_MAX_IMAGE_SIZE "ZBX_MEBIBYTE" "ZBX_MEBIBYTE * 8"
define_inc SVG_GRAPH_MAX_NUMBER_OF_METRICS 50 500
show_bak_diff $defines_inc_php

# Remove 0 values from GUI Graph Hintbox
class_csvggraph_js="/usr/share/zabbix/js/class.csvggraph.js"
echo "===== ${class_csvggraph_js} patch ====="
bak_if_exist $class_csvggraph_js
sed -i -e 's/if (show_hint \&\& data.hintMaxRows > rows_added) {/if (show_hint \&\& data.hintMaxRows \> rows_added \&\& \!point.v.match(\/^0( \\w*)?$\/)) {/' $class_csvggraph_js
show_bak_diff $class_csvggraph_js
echo

# Increase hardcoded 20 characters limit for LOG data in Operational Data view
items_inc_php="/usr/share/zabbix/include/items.inc.php"
echo "===== ${items_inc_php} patch ====="
bak_if_exist $items_inc_php
sed -i '/case ITEM_VALUE_TYPE_LOG:/{:a;N;/}/!ba;s/mb_strlen($value) > 20/mb_strlen($value) > 100/g;s/mb_substr($value, 0, 20)/mb_substr($value, 0, 100)/g}' $items_inc_php
show_bak_diff $items_inc_php
echo

echo "
  RESTART ZABBIX LATER
------------------------------------------"

echo "systemctl restart zabbix-agent*" | at now + 1 min &>/dev/null ## restart zabbix agent with a delay
$S_LOG -s $? -d "$S_NAME" "Scheduling Zabbix Agent Restart"

exit
