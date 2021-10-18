# Zabbix Server Tweaking
Zabbix Server tweaks and Zabbix server template.

Works for Zabbix Server 5.x

## Deploy Commands

Everything is executed by only a few basic deploy scripts. 

```bash
cd /usr/local/src
git clone https://github.com/Futur-Tech/futur-tech-zabbix-server.git
cd futur-tech-zabbix-server

./deploy.sh 
# Main deploy script

./deploy-update.sh -b main
# This script will automatically pull the latest version of the branch ("main" in the example) and relaunch itself if a new version is found. Then it will run deploy.sh. Also note that any additional arguments given to this script will be passed to the deploy.sh script.
```

Finally import the template XML in Zabbix Server and attach it to your host.

## Tweaks descriptions

## Dashboards

**Problem:** when mouse overing a **Graph widget**, only 20 lines of data show. Showing message at the bottom: *Displaying 20 of xx found*.

**Solution:** On Zabbix Server, edit **/usr/share/zabbix/include/defines.inc.php**

```php
// Original
define('ZBX_WIDGET_ROWS', 20);

// Replaced by
define('ZBX_WIDGET_ROWS', 200);
```

---

**Problem:** Only 50 rows are shown on **Overview widget**. Showing message at the bottom: *Not all results are displayed. Please provide more specific search criteria.*

**Solution:** On Zabbix Server, edit **/usr/share/zabbix/include/defines.inc.php**

```php
// Original
define('ZBX_MAX_TABLE_COLUMNS', 50);

// Replaced by
define('ZBX_MAX_TABLE_COLUMNS', 500); 
```
> Source: https://www.zabbix.com/forum/zabbix-help/401358-data-overwiev-widget-doesn%C2%B4t-show-all-records 

---

**Problem:** Default max upload size for pictures is 1MB. Showing error: *Image size must be less than 1 MB.*

**Solution:** On Zabbix Server, edit **/usr/share/zabbix/include/defines.inc.php**

```php
// Original
define('ZBX_MAX_IMAGE_SIZE', ZBX_MEBIBYTE);

// Replaced by
define('ZBX_MAX_IMAGE_SIZE', ZBX_MEBIBYTE * 8);
```
> Source: https://www.zabbix.com/forum/zabbix-help/53220-problem-with-upload-size-walpaper 

