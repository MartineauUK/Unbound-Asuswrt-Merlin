# Unbound installation script for ASUS Router running RMerlin firmware.

## Installation ##

Enable SSH on router, then use your preferred SSH Client e.g. Xshell6,MobaXterm, PuTTY etc. to copy'n'paste:

	curl --retry 3 "https://raw.githubusercontent.com/MartineauUK/Unbound-Asuswrt-Merlin/master/unbound_installer.sh" -o "/jffs/scripts/unbound_installer.sh" && chmod 755 "/jffs/scripts/unbound_installer.sh" && /jffs/scripts/unbound_installer.sh


## To execute the utility, you may then use the _alias_ ##

	unbound_installer

```
+======================================================================+
|  Welcome to the unbound-Installer-Asuswrt-Merlin installation script |
|  Version 1.19 by Martineau                                           |
|                                                                      |
| Requirements: USB drive with Entware installed                       |
|                                                                      |
| The install script will:                                             |
|   1. Install the unbound Entware package                             |
|   2. Override how the firmware manages DNS                           |
|   3. Optionally Integrate with Stubby                                |
|   4. Optionally Install Ad and Tracker Blocking                      |
|   5. Optionally Customise CPU/Memory usage (Advanced Users)          |
|   6. Optionally Disable Firefox DNS-over-HTTPS (DoH) (USA users)     |
|                                                                      |
|                                                                      |
| You can also use this script to uninstall unbound to back out the    |
| changes made during the installation. See the project repository at  |
|         https://github.com/rgnldo/Unbound-Asuswrt-Merlin             |
|     for helpful user tips on unbound usage/configuration.            |
+======================================================================+

unbound (pid 3113) is running... uptime: 0 Days, 01:14:24 version: 1.9.3 (# rgnldo User Install Custom Version vx.xx (Date Loaded by unbound_installer Fri Jan 10 11:43:15 GMT 2020))


i  = Update ('/opt/var/lib/unbound/') unbound Configuration		l  = Show unbound log entries (lo=Enable Logging)
z  = Remove Existing unbound Installation				v  = View ('/opt/var/lib/unbound/') unbound Configuration (vx=Edit; vh=View Example Configuration) 
?  = About Configuration						rl = Reload Configuration (Doesn't halt unbound) e.g. 'rl test1[.conf]' (Recovery use 'rl reset/user')
									oq = Query unbound Configuration option e.g 'oq verbosity' (ox=Set) e.g. 'ox log-queries yes'

rs = Restart (or Start) unbound						s  = Show unbound statistics (s=Summary Totals; sa=All; s+=Enable Extended Stats)

e  = Exit Script


Option ==>  
```
