# Unbound installation script for ASUS Router running RMerlin firmware.

Installation

Enable SSH on router, then use your preferred SSH Client e.g. Xshell6,MobaXterm, PuTTY etc. to copy'n'paste:

	curl --retry 3 "https://raw.githubusercontent.com/Unbound-Asuswrt-Merlin/VPN-Failover/master/unbound_installer.sh" -o "/jffs/scripts/unbound_installer.sh" && chmod 755 "/jffs/scripts/unbound_installer.sh"

