#!/usr/bin/env bash

source "$(dirname "$0")/ft-util/ft_util_inc_func"
source "$(dirname "$0")/ft-util/ft_util_inc_var"
source "$(dirname "$0")/ft-util/ft_util_sudoersd"
source "$(dirname "$0")/ft-util/ft_util_usrmgmt"

app_name="futur-tech-zabbix-server"

bin_dir="/usr/local/bin/${app_name}"
src_dir="/usr/local/src/${app_name}"
# Detect the PHP version in use instead of hardcoding it
# (Bookworm ships PHP 8.2, Trixie ships 8.4)
php_confd="$(ls -1d /etc/php/*/apache2/conf.d 2>/dev/null | sort -V | tail -n1)"
mysql_confd="/etc/mysql/mariadb.conf.d"
systemd_mariadb_d="/etc/systemd/system/mariadb.service.d"

# Checking which Zabbix Agent is detected and adjust include directory
$(which zabbix_agent2 >/dev/null) && zbx_conf_agent_d="/etc/zabbix/zabbix_agent2.d"
$(which zabbix_agentd >/dev/null) && zbx_conf_agent_d="/etc/zabbix/zabbix_agentd.conf.d"
if [ ! -d "${zbx_conf_agent_d}" ]; then
  $S_LOG -s crit -d $S_NAME "${zbx_conf_agent_d} Zabbix Include directory not found"
  exit 10
fi

if [ ! -d "${php_confd}" ]; then
  $S_LOG -s crit -d $S_NAME "No /etc/php/*/apache2/conf.d directory found"
  exit 11
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
  MARIADB TUNING
------------------------------------------"

# Normalise a value so a my.cnf entry can be compared with SHOW GLOBAL VARIABLES
# (size suffixes -> bytes, boolean forms -> ON/OFF)
norm_val() {
  local v="${1%/}" # strip trailing slash so path values compare cleanly
  local u="${v^^}"
  case "$u" in
  *[0-9]K) echo $((${u%K} * 1024)) ;;
  *[0-9]M) echo $((${u%M} * 1024 * 1024)) ;;
  *[0-9]G) echo $((${u%G} * 1024 * 1024 * 1024)) ;;
  1 | ON | TRUE) echo "ON" ;;
  0 | OFF | FALSE) echo "OFF" ;;
  *) echo "$v" ;; # keep original case: paths are case-sensitive
  esac
}

# Show, for every variable our tuning file sets, the value in the file next to
# the value the running server actually has. Catches settings that a MariaDB
# upgrade has removed or that need a restart to take effect.
show_mysql_conf_status() {
  local cnf="${1}"
  local var val_conf val_run n_conf n_run status diff_count=0 gone_count=0

  if ! command -v mariadb >/dev/null 2>&1; then
    $S_LOG -s warn -d "$S_NAME" "mariadb client not found - skipping config comparison"
    return 0
  fi
  if ! mariadb -N -B -e "SELECT 1" >/dev/null 2>&1; then
    $S_LOG -s warn -d "$S_NAME" "Cannot connect to MariaDB via socket - skipping config comparison"
    return 0
  fi

  printf "%-32s %-26s %-26s %s\n" "VARIABLE" "CONF FILE" "RUNNING" "STATUS"
  printf "%-32s %-26s %-26s %s\n" "--------------------------------" "--------------------------" "--------------------------" "------"

  while IFS=$'\t' read -r var val_conf; do
    var="${var//-/_}"
    val_run="$(mariadb -N -B -e "SHOW GLOBAL VARIABLES LIKE '${var}'" 2>/dev/null | cut -f2)"
    if [ -z "${val_run}" ]; then
      status="REMOVED - no such variable in this MariaDB version"
      gone_count=$((gone_count + 1))
    else
      n_conf="$(norm_val "${val_conf}")"
      n_run="$(norm_val "${val_run}")"
      if [ "${n_conf}" = "${n_run}" ]; then
        status="ok"
      else
        status="DIFFERS - restart MariaDB to apply"
        diff_count=$((diff_count + 1))
      fi
    fi
    printf "%-32s %-26s %-26s %s\n" "${var}" "${val_conf}" "${val_run:--}" "${status}"
  done < <(awk -F= '/^[[:space:]]*[a-zA-Z_]/ && /=/ {
             n=$1; sub(/^[[:space:]]+/,"",n); sub(/[[:space:]]+$/,"",n);
             v=$2; sub(/#.*/,"",v); sub(/^[[:space:]]+/,"",v); sub(/[[:space:]]+$/,"",v);
             print n "\t" v }' "${cnf}")

  echo
  $S_LOG -s $([ "${gone_count}" -eq 0 ] && echo info || echo warn) -d "$S_NAME" \
    "MariaDB tuning: ${gone_count} removed variable(s), ${diff_count} value(s) awaiting restart"
}

if [ -d "${mysql_confd}" ]; then

  # systemd caps the unit's file descriptors; open_files_limit cannot exceed it
  mkdir_if_missing "${systemd_mariadb_d}"
  $S_DIR/ft-util/ft_util_file-deploy "$S_DIR/etc.systemd/zz-${app_name}.conf" "${systemd_mariadb_d}/zz-${app_name}.conf"
  run_cmd_log systemctl daemon-reload

  $S_DIR/ft-util/ft_util_file-deploy "$S_DIR/etc.mysql/99-${app_name}.cnf" "${mysql_confd}/99-${app_name}.cnf"
  show_mysql_conf_status "${mysql_confd}/99-${app_name}.cnf"
else
  $S_LOG -s warn -d $S_NAME "${mysql_confd} not found - skipping MariaDB tuning deploy"
fi

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
