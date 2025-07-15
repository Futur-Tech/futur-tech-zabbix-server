# Zabbix Server Tweaking
Zabbix Server tweaks and Zabbix server template.

Works for Zabbix Server 6.0

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

**Problem:** Default max upload size for pictures is 1MB. Showing error: *Image size must be less than 1 MB.*

**Solution:** On Zabbix Server, edit **/usr/share/zabbix/include/defines.inc.php**

```php
// Original
define('ZBX_MAX_IMAGE_SIZE', ZBX_MEBIBYTE);

// Replaced by
define('ZBX_MAX_IMAGE_SIZE', ZBX_MEBIBYTE * 8);
```
> Source: https://www.zabbix.com/forum/zabbix-help/53220-problem-with-upload-size-walpaper 


---

**Problem:** GUI Graph Hintbox show a lot of 0 value data... which is not useful in most cases.

**Solution:** On Zabbix Server, edit **/usr/share/zabbix/js/class.csvggraph.js#**

```php
// Original
if (show_hint && data.hintMaxRows > rows_added) {

// Replaced by
if (show_hint && data.hintMaxRows > rows_added && !point.v.match(/^0( \w*)?$/)) {
```

--

**Problem:** When using wildcard host and items in graph, the number of metrics is limited to 50

**Solution:** On Zabbix Server, edit **/usr/share/zabbix/include/defines.inc.php**

```php
// Original
define('SVG_GRAPH_MAX_NUMBER_OF_METRICS', 50);

// Replaced by
define('SVG_GRAPH_MAX_NUMBER_OF_METRICS', 500);
```

-- 

**Problem:** In problems list, the *Operational Data* is limited at 20 characters for Log datatype.

**Solution:** On Zabbix Server, edit **/usr/share/zabbix/include/defines.inc.php**

```php
// Original
case ITEM_VALUE_TYPE_LOG:
	$display_value = $trim && mb_strlen($value) > 20 ? mb_substr($value, 0, 20).'...' : $value;
	break;

// Replaced by
case ITEM_VALUE_TYPE_LOG:
	$display_value = $trim && mb_strlen($value) > 100 ? mb_substr($value, 0, 100).'...' : $value;
	break;
```
