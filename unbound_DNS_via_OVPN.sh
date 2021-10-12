#!/bin/sh
VER="v1.01"

# v1.00 12 Oct 2021 Martineau Hack from @Swinson original see http://www.snbforums.com/threads/unbound-dns-vpn-client-w-policy-rules.67370/post-653427


Check_Tun_Con() {
    ping -c1 -w1 -I tun1$VPN_ID 9.9.9.9
}
Delete_Rules() {
    iptables-save | grep "unbound_rule" | sed 's/^-A/iptables -t mangle -D/' | while read CMD;do $CMD;done
}
Add_Rules(){
    Delete_Rules
    iptables -t mangle -A OUTPUT -d "${wan0_dns##*.*.*.* }"/32 -p udp --dport 53 -m comment --comment unbound_rule -j MARK --set-mark $TAG_MARK_WAN
    iptables -t mangle -A OUTPUT -d "${wan0_dns%% *.*.*.*}"/32 -p udp --dport 53 -m comment --comment unbound_rule -j MARK --set-mark $TAG_MARK_WAN
    iptables -t mangle -A OUTPUT -d "${wan0_dns##*.*.*.* }"/32 -p tcp --dport 53 -m comment --comment unbound_rule -j MARK --set-mark $TAG_MARK_WAN
    iptables -t mangle -A OUTPUT -d "${wan0_dns%% *.*.*.*}"/32 -p tcp --dport 53 -m comment --comment unbound_rule -j MARK --set-mark $TAG_MARK_WAN
    iptables -t mangle -A OUTPUT -p tcp --dport 53 -m comment --comment unbound_rule -j MARK --set-mark $TAG_MARK_VPN
    iptables -t mangle -A OUTPUT -p udp --dport 53 -m comment --comment unbound_rule -j MARK --set-mark $TAG_MARK_VPN
}
Call_unbound_manager() {
    /jffs/addons/unbound/unbound_manager.sh vpn="$1"
}
Poll_Tun() {
    timer=$1
    [ "$timer" == "0" ] && Post_log "Error Timeout" && exit 1 || sleep 2
    Check_Tun_Con && Add_Rules && Call_unbound_manager "$VPN_ID" || Poll_Tun "$((timer-1))"
}
Post_log() {
    $(logger -st "($(basename "$0"))" $$ "$@")
}

#=============================================================Main==============================================================
Main() { true; }                                # Syntax that is Atom Shellchecker compatible!

modprobe xt_comment                 # v1.01

[ -z "$2" ] && Post_log "Script request Invalid e.g. Usage: $(basename "$0") 1 start" && exit 1 || Post_log "Starting Script Execution $@"

VPN_ID=$1                                       # The desired VPN instance (1 to 5)

[ -z $(echo "$VPN_ID" | grep -E "^[1-5]$") ] && { Post_log "Invalid VPN client '$VPN_ID' - use 1-5 e.g. $(basename "$0") 1 start"; exit 1; }    # v1.01

[ -z "$3" ] && MAX_WAIT=150 || MAX_WAIT=$3       # Maximum wait time for tunnel is x 2secs i.e. MAX_WAIT=5 is total 10 secs


# nat-start must contain see https://github.com/RMerl/asuswrt-merlin.ng/wiki/Policy-based-Port-routing-(manual-method)#installation
TAG_MARK_WAN="0x8000/0x8000"
# VPN 1 use 0x1000; VPN 2 use 0x2000 etc.
case $VPN_ID in
    1|2)    TAG_MARK_VPN="0x${VPN_ID}000/0x${VPN_ID}000";;
    3)      TAG_MARK_VPN="0x4000/0x4000";;
    4)      TAG_MARK_VPN="0x7000/0x7000";;
    5)      TAG_MARK_VPN="0x3000/0x3000";;
esac

wan0_dns="$(nvram get wan0_dns)"

iptables -t mangle -A OUTPUT -p udp --dport 53 -m comment --comment unbound_rule -j MARK --set-mark $TAG_MARK_VPN
iptables -t mangle -A OUTPUT -d "${wan0_dns##*.*.*.* }"/32 -p udp --dport 53 -m comment --comment unbound_rule -j MARK --set-mark $TAG_MARK_WAN

Delete_Rules

case "$2" in
    start)
        Poll_Tun "$MAX_WAIT" "$VPN_ID" && Post_log "Ending Script Execution" && exit 0;;
    stop)
        Call_unbound_manager "disable" && Post_log "Ending Script Execution" && exit 0;;
    *)
        Post_log "Script Arg '' Invalid - e.g. $(basename "$0") 3 start" && exit 1;;
esac
