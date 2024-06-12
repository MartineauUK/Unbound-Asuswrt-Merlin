#!/bin/sh
# shellcheck disable=SC2086,SC2068,SC1087,SC2039,SC2155,SC2124,SC2027,SC2046
VERSION="3.24"
#============================================================================================ © 2019-2024 Martineau v3.24
#  Install 'unbound - Recursive,validating and caching DNS resolver' package from Entware on Asuswrt-Merlin firmware.
#
# Usage:    unbound_manager    ['help'|'-h'] | [ [debug] ['nochk'] ['advanced'] ['install'] ['stop'] ['recovery' | 'restart' ['reload config='[config_file] ]] ]
#                              ['vpn='{vpn_id [ delay=nnn ] | 'disable' } ] [bind | nobind] ['noreadline']
#
#           unbound_manager
#                              Context Menu: Install with 'user option prompts (see advanced section below)
#
#                                    |   1  = Install unbound DNS Server                                    |
#                                    |   2  = Remove unbound/unbound_manager                                |
#                                    |   3  = Start unbound*                                                |
#                                    |   4  = n/a Show unbound statistics*                                  |
#                                    |   5  = Install Ad and Tracker blocker (Ad Block)*                    |
#                                    |   6  = Install Graphical Statistics GUI Add-on TAB*                  |
#                                    |   7  = Enable DNS Firewall*                                          |
#
#                              '*' - toggle' options; e.g. unbound already started, option '3' shows 'Stop'
#
#           unbound_manager    advanced
#                              Context Menu: Install with user option prompts with Advanced Tools menu
#
#                                    |   i = Install unbound DNS Server - Advanced Mode                     |
#                                    |       o1. Enable unbound Logging                                     |
#                                    |       o2. Integrate with Stubby                                      |
#                                    |       o3. Install Ad and Tracker Blocking                            |
#                                    |       o4. Customise CPU/Memory usage                                 |
#                                    |       o5. Disable Firefox DNS-over-HTTPS (DoH) (USA users)           |
#                                    |       o6. Install Graphical Statistics GUI (Add-ons) TAB             |
#                                    |       o7. Enable DNS Firewall                                        |
#                                    |                                                                      |
#                                    |   z  = Remove Existing unbound/unbound_manager Installation          |
#                                    |   ?  = About Configuration                                           |
#                                    |   3  = Advanced Tools                                                |
#
#           unbound_manager    recovery
#                              Will attempt to reload a default 'unbound.config' to fix a corrupt config
#           unbound_manager    config=mytest
#                              Will attempt to load '/opt/share/unbound/configs/mytest.config'
#           unbound_manager    nochk
#                              The script on start-up attempts to check GitHub for any version update/md5 mismatch, but a
#                              failed install will look as if the script has stalled until cURL time-out expires (3 mins).
#                              Use of nochk disables the 'stall' to quickly allow access to the 'z  = Remove unbound Installation' option
#           unbound_manager    restart
#                              Allows saving of the cache (unlike sh /opt/etc/init.d/S61unbound restart)
#           unbound_manager    vpn=1
#                              unbound will send its Root Server DNS requests via the VPN Client 1 tunnel
#           unbound_manager    vpn=disable
#                              unbound will send its Root Server DNS requests via the WAN (see post-mount)
#           unbound_manager    vpn=5 delay=2
#                              unbound will send its Root Server DNS requests via the VPN Client 5 tunnel
#                              ('delay=' MUST be used if invoked by vpnclientX-up)
#
#  See https://github.com/MartineauUK/Unbound-Asuswrt-Merlin for additional help/documentation with this script.
#  See SNBForums thread https://tinyurl.com/s89z3mm for helpful user tips on unbound usage/configuration.

# Maintainer: Martineau
# Last Updated Date: 12-Jun-2024
#
# Description:
#
# Acknowledgement:
#  Test team: rngldo
#  Contributors: rgnldo,dave14305,SomeWhereOverTheRainbow,Camm,Max33Verstappen,toazd,Chris0815,ugandy,Safemode,tomsk,joe scian,juched,sfatula,mister,francovilar,PeterR,AlexanderPavlenko,novusB  (Xentrk for this script template and thelonelycoder for amtm)

#
#   https://medium.com/nlnetlabs
#   https://dnswatch.com/dns-docs/UNBOUND/
#   https://calomel.org/unbound_dns.html
#   https://wiki.archlinux.org/index.php/unbound
#   https://www.tumfatig.net/20190417/storing-unbound8-logs-into-influxdb/
#
####################################################################################################

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:$PATH    # v1.15 Fix by SNB Forum Member @Cam
logger -t "($(basename "$0"))" "$$ Starting Script Execution ($(if [ -n "$1" ]; then echo "$1"; else echo "menu"; fi))"
GIT_REPO="unbound-Asuswrt-Merlin"
GITHUB_JUCHED="https://raw.githubusercontent.com/juched78/$GIT_REPO/master"     # v2.14
GITHUB_JUCHED_DEV="https://raw.githubusercontent.com/juched78/$GIT_REPO/develop"    # v3.00
GITHUB_MARTINEAU="https://raw.githubusercontent.com/MartineauUK/$GIT_REPO/master"
GITHUB_MARTINEAU_DEV="https://raw.githubusercontent.com/MartineauUK/$GIT_REPO/dev"
GITHUB_DIR=$GITHUB_MARTINEAU                       # v1.08 default for script
GITHUB_NLNETLABS="https://raw.githubusercontent.com/NLnetLabs/unbound/master"   # v3.06
CONFIG_DIR="/opt/var/lib/unbound/"
UNBOUNCTRLCMD="unbound-control"                    # v2.12 [using the '-c' parameter is recommended v1.27]
ENTWARE_UNBOUND="unbound-checkconf unbound-control-setup unbound-control unbound-anchor unbound-daemon"         # v2.02
SILENT="s"                                         # Default is no progress messages for file downloads # v1.08
ALLOWUPGRADE="Y"                                   # Default is allow script download from Github      # v1.09
CHECK_GITHUB=1                                     # Only check Github MD5 every nn times
MAX_OPTIONS=5                                      # Available Installation Options 1 thru 5 see $AUTO_REPLYx
USER_OPTION_PROMPTS="?"                            # Global reset if ANY Auto-Options specified
CURRENT_AUTO_OPTIONS=                              # List of CURRENT Auto Reply Options
DIV_DIR="/opt/share/diversion/list/"               # diversion directory v1.25
KEEPACTIVECONFIG="N"                               # During install/update download 'unbound.conf' from GitHub; "Y" - skip download
USE_GITHUB_DEV="N"                                 # During install/update download from GitHub 'master'; "Y" - download from 'dev' branch 2.06
READLINE="ReadLine"                                # Emulate 'readline' for 'read' v3.18
CMDLINE=                                           # Command line INPUT v3.18
CMD1=;CMD2=;CMD3=;CMD4=;CMD5=                      # Command recall push stack v3.18
DEBUGMODE=

# Uncomment the line below for debugging
#set -x
# Print between line beginning with'#==' to first blank line inclusive
ShowHelp() {
    echo -en $cBWHT >&2
    awk '/^#==/{f=1} f{print; if (!NF) exit}' $0
    echo -en $cRESET >&2
}

Say(){
   echo -e $$ $@ | logger -st "($(basename $0))"
}
SayT(){
   echo -e $$ $@ | logger -t "($(basename $0))"
}
# shellcheck disable=SC2034
ANSIColours () {
    cRESET="\e[0m";cBLA="\e[30m";cRED="\e[31m";cGRE="\e[32m";cYEL="\e[33m";cBLU="\e[34m";cMAG="\e[35m";cCYA="\e[36m";cGRA="\e[37m";cFGRESET="\e[39m"
    cBGRA="\e[90m";cBRED="\e[91m";cBGRE="\e[92m";cBYEL="\e[93m";cBBLU="\e[94m";cBMAG="\e[95m";cBCYA="\e[96m";cBWHT="\e[97m"
    aBOLD="\e[1m";aDIM="\e[2m";aUNDER="\e[4m";aBLINK="\e[5m";aREVERSE="\e[7m"
    aBOLDr="\e[21m";aDIMr="\e[22m";aUNDERr="\e[24m";aBLINKr="\e[25m";aREVERSEr="\e[27m"
    cWRED="\e[41m";cWGRE="\e[42m";cWYEL="\e[43m";cWBLU="\e[44m";cWMAG="\e[45m";cWCYA="\e[46m";cWGRA="\e[47m"
    cYBLU="\e[93;48;5;21m"
    cRED_="\e[41m";cGRE_="\e[42m"
    xHOME="\e[H";xERASE="\e[2J";xERASEDOWN="\e[J";xERASEUP="\e[1J";xCSRPOS="\e[s";xPOSCSR="\e[u";xERASEEOL="\e[K";xQUERYCSRPOS="\e[6n"
    xGoto="\e[Line;Columnf"
}
Get_Router_Model() {

    # Contribution by @thelonelycoder as odmpid is blank for non SKU hardware,
    local HARDWARE_MODEL
    [ -z "$(nvram get odmpid)" ] && HARDWARE_MODEL=$(nvram get productid) || HARDWARE_MODEL=$(nvram get odmpid)

    echo $HARDWARE_MODEL

    return 0
}
Chk_Entware() {

        # ARGS [wait attempts] [specific_entware_utility]
        READY="1"                   # Assume Entware Utilities are NOT available
        ENTWARE_UTILITY=""          # Specific Entware utility to search for
        MAX_TRIES="30"

        if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
            MAX_TRIES="$2"
        elif [ -z "$2" ] && [ "$1" -eq "$1" ] 2>/dev/null; then
            MAX_TRIES="$1"
        fi

        if [ -n "$1" ] && ! [ "$1" -eq "$1" ] 2>/dev/null; then
            ENTWARE_UTILITY="$1"
        fi

        # Wait up to (default) 30 seconds to see if Entware utilities available.....
        TRIES="0"

        while [ "$TRIES" -lt "$MAX_TRIES" ]; do
            if [ -n "$(which opkg)" ]; then                     # v3.23
                if [ -n "$ENTWARE_UTILITY" ]; then            # Specific Entware utility installed?
                    if [ -n "$(opkg list-installed "$ENTWARE_UTILITY")" ]; then
                        READY="0"                             # Specific Entware utility found
                    else
                        # Not all Entware utilities exists as a stand-alone package e.g. 'find' is in package 'findutils'
                        if [ -d /opt ] && [ -n "$(find /opt/ -name "$ENTWARE_UTILITY")" ]; then
                            READY="0"                         # Specific Entware utility found
                        fi
                    fi
                else
                    READY="0"                                 # Entware utilities ready
                fi
                break
            fi
            sleep 1
            logger -st "($(basename "$0"))" "$$ Entware $ENTWARE_UTILITY not available - wait time $((MAX_TRIES - TRIES-1)) secs left"
            TRIES=$((TRIES + 1))
        done
        return "$READY"
}
Get_WAN_IF_Name () {

    local IF_NAME=$(nvram get wan0_ifname)              # DHCP/Static ?

    # Usually this is probably valid for both eth0/ppp0e ?
    if [ "$(nvram get wan0_gw_ifname)" != "$IF_NAME" ];then
        local IF_NAME=$(nvram get wan0_gw_ifname)
    fi

    if [ ! -z "$(nvram get wan0_pppoe_ifname)" ];then
        local IF_NAME="$(nvram get wan0_pppoe_ifname)"      # PPPoE
    fi

    echo $IF_NAME

}
Convert_SECS_to_HHMMSS() {

    local SECS=$1

    local DAYS_TXT=
    if [ $SECS -ge 86400 ] && [ -n "$2" ];then              # More than 24:00 i.e. 1 day?
        local DAYS=$((${SECS}/86400))
        SECS=$((SECS-DAYS*86400))
        local DAYS_TXT=$DAYS" days"
    fi
    local HH=$((${SECS}/3600))
    local MM=$((${SECS}%3600/60))
    local SS=$((${SECS}%60))
    if [ -z "$2" ];then
        echo $(printf "%02d:%02d:%02d" $HH $MM $SS)                    # Return 'hh:mm:ss" format
    else
        if [ -n "$2" ] && [ -z "$DAYS_TXT" ];then
            DAYS_TXT="0 Days, "
        fi
        echo $(printf "%s %02d:%02d:%02d" "$DAYS_TXT" $HH $MM $SS)      # Return in "x days hh:mm:ss" format
    fi
}
Size_Human() {

    local SIZE=$1
    if [ -z "$SIZE" ];then
        echo "N/A"
        return 1
    fi
    #echo $(echo $SIZE | awk '{ suffix=" KMGT"; for(i=1; $1>1024 && i < length(suffix); i++) $1/=1024; print int($1) substr(suffix, i, 1), $3; }')

    # if [ $SIZE -gt $((1024*1024*1024*1024)) ];then                                        # 1,099,511,627,776
        # printf "%2.2f TB\n" $(echo $SIZE | awk '{$1=$1/(1024^4); print $1;}')
    # else
        if [ $SIZE -gt $((1024*1024*1024)) ];then                                       # 1,073,741,824
            printf "%2.2f GB\n" $(echo $SIZE | awk '{$1=$1/(1024^3); print $1;}')
        else
            if [ $SIZE -gt $((1024*1024)) ];then                                        # 1,048,576
                printf "%2.2f MB\n" $(echo $SIZE | awk '{$1=$1/(1024^2);   print $1;}')
            else
                if [ $SIZE -gt $((1024)) ];then
                    printf "%2.2f KB\n" $(echo $SIZE | awk '{$1=$1/(1024);   print $1;}')
                else
                    printf "%d Bytes\n" $SIZE
                fi
            fi
        fi
    # fi

    return 0
}
Is_IPv4 () {
        grep -oE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'                    # IPv4 format
}
Is_IPv4_CIDR() {
        grep -oE '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'         # IPv4 CIDR range notation
}
Is_Private_IPv4() {
    # 127.  0.0.0 – 127.255.255.255     127.0.0.0 /8
    # 10.   0.0.0 –  10.255.255.255      10.0.0.0 /8
    # 172. 16.0.0 – 172. 31.255.255    172.16.0.0 /12
    # 192.168.0.0 – 192.168.255.255   192.168.0.0 /16
    #grep -oE "(^192\.168\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])$)|(^172\.([1][6-9]|[2][0-9]|[3][0-1])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])$)|(^10\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])$)"
    grep -oE "(^127\.)|(^(0)?10\.)|(^172\.(0)?1[6-9]\.)|(^172\.(0)?2[0-9]\.)|(^172\.(0)?3[0-1]\.)|(^169\.254\.)|(^192\.168\.)"
}
Is_Private_IPv6() {
    grep -oE "(::1$)|([fF][cCdD])"
}
LastLine_LF() {

# Used by SmartInsertLine()

    case $2 in
        QueryLF)                # Does last line of file end with 'LF'?; if so return 'LF' otherwise return NULL
                [ $(wc -l < $1) -eq $(awk 'END{print NR}' $1 ) ] && echo "\n" || echo ""
                return 0
                ;;
        Count)
                echo "$(awk 'END{print NR}' $1)"        # Return number of lines in file
                return 0
                ;;
        *)
                echo "$(tail -n 1 $FN)"                 # Return the last line of file
                return 0
                ;;
    esac

}
Smart_LineInsert() {

# Requires LastLine_LF()

    local FN=$1
    local ARGS=$@
    local TEXT="$(printf "%s" "$ARGS" | cut -d' ' -f2-)"                    # Drop the first word
    local TEXT=$(printf "%s" "$TEXT" | sed 's/^[ \t]*//;s/[ \t]*$//')       # Old-skool strip leading/trailing spaces

    sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $FN                            # Delete all trailing blank lines from file

    # If last line doesn't end with '\n' then add one '\n'
    #[ -n "$(LastLine_LF "$FN" "QueryLF")" ] && echo -e "\n" >> "$FN"

    # If LAST line begins with 'exit' then insert TEXT line BEFORE it.
    if [ -z "$(grep -E "^##@Insert##" "$FN")" ];then
        FIRSTWORD=$(grep "." "$FN" | tail -n 1)
        [ "$FIRSTWORD" == "exit" ] && POS=$(awk 'END{print NR}' $FN) || POS=
    else
        POS="$(awk ' /^##@Insert##/ {print NR}' "$FN")";POS=$((POS + 1))
    fi
    [ -n "$POS" ] && { awk -v here="$POS" -v newline="$TEXT" 'NR==here{print newline}1' "$FN" > ${FN}a; rm $FN; mv ${FN}a $FN; } || printf "%s\n" "$TEXT" >> "$FN"

}
Is_HND() {
    [ -n "$(/bin/uname -m | grep "aarch64")" ] && { echo Y; return 0; } || { echo N; return 1; }
}
Repeat() {                                                      # v3.22
    # Print 25 '=' use HDRLINE=$(Repeat 25 "=")
    printf "%${1}s\n" | tr " " "$2"
}
Edit_config_options() {
# v2.12 renamed function
_quote() {
  echo $1 | sed 's/[]\/()$*.^|[]/\\&/g'
}
    local FN="${CONFIG_DIR}unbound.conf" # v1.27
    local TO=

    local MATCH=$(_quote "$1")
    shift

    local SEDACTION="-i"        # Inline edit

    # Check options
    while [ $# -gt 0 ]; do    # Until you run out of parameters . . .       # v1.07
      case "$1" in
        comment|uncomment)
                local ACTION=$1
                ;;
        noedit)
                local SEDACTION="-e"
                ;;
        file=*)
                local FN=$(echo "$1" | sed -n "s/^.*file=//p" | awk '{print $1}')
                ;;
        *)
                local TO=$(_quote "$1")
                ;;
      esac
      shift       # Check next set of parameters.
    done

    [ -z "$MATCH" ] && { echo -e $cBRED"\a\n\t***ERROR - Missing option name" 2>&1; exit 1; }

    # When using v1.01+ of unbound.conf, need to exclude the header comments from the search
    # i.e. 'server:' should be the FIRST non-comment line in 'unbound.conf' if there are legitimate duplicates
    #      e.g. @Max33Verstappen uses multiple pairs:
    #         server:
    #            domain-insecure:
    # Allow legitimate 'server:' duplicates
    local POS="$(grep -Enw "[[:space:]]*server:" ${CONFIG_DIR}unbound.conf | head -n 1 | cut -d':' -f1)"   # v3.00 v2.05
    # So if the following appears in 'unbound.conf'
    #     server:
    #        do-ip6 yes
    #     server:
    #        do ip6 no
    # then 'do-ip6 no' will NOT be retrieved, so v3.00 will deliberately not start unbound
    #      (see functions Show_status() & Valid_unbound_config_Syntax() )
    case $ACTION in
        comment)
                if [ -z "$TO" ];then
                    #[ -z "$(grep "#$MATCH" $FN )" ] && sed $SEDACTION "/$MATCH/ s/\($MATCH.*$\)/#\1/" $FN|| echo -e $cRESET"\tAleady commented out '#$MATCH'"
                    [ -n "$(grep "^$MATCH" $FN )" ] && sed $SEDACTION "$POS,$ {/$MATCH/ s/\($MATCH.*$\)/#\1/}" $FN        # v3.06 Fix
                else
                    sed $SEDACTION "$POS,$ {/$MATCH/,/$TO/ s/\(^[[:space:]]*\)\(.\)/\1#\2/}" $FN    # v2.05
                fi
                ;;
        uncomment)
                if [ -z "$TO" ];then
                    #sed $SEDACTION "/#$MATCH/ s/#//1" $FN
                    sed $SEDACTION "$POS,$ {/#[[:space:]]*$MATCH/ s/#//1}" $FN  # v2.05
                else
                    #sed $SEDACTION "/#$MATCH/,/#$TO/ s/\(^[[:space:]]*\)\(#\)/\1/" $FN
                    sed $SEDACTION "$POS,$ {/#[[:space:]]*$MATCH/,/#[[:space:]]*$TO/ s/\(^[[:space:]]*\)\(#\)/\1/}" $FN     # v2.05
                fi
                ;;
    esac

}
Show_Advanced_Menu() {
    printf "%s\t\t%s\n"             "$MENU_I"  "$MENU_L"
    printf "%s\t\t\t\t\t%s\n"       "$MENU_Z"  "$MENU_VX"
    printf "%s\t\t\t\t\t\t\t%s\n"   "$MENUW_X" "$MENU_VB"
    printf "\t\t\t\t\t\t\t\t\t%s\n" "$MENU_RL"
    printf "%s\t\t\t\t\t\t%s\n"     "$MENU__"  "$MENU_OQ"
    printf "%s\t\t\t\t\t%s\n"       "$MENU_SD" "$MENU_S"
    #[ -n "$MENU_FM" ] && printf "\t\t\t\t\t\t\t\t\t%s\n"             "$MENU_FM"      # v3.00 its the default v2.15
    [ -n "$MENUW_ADBLOCK" ] && printf "\t\t\t\t\t\t\t\t\t%s\n"       "$MENUW_ADBLOCK"      # v3.03
    printf "%s\t\t\t%s\n"                          "$MENUW_FFDOH"     "$MENUW_YOUTUBE"   #  v3.16 3.11
    printf "%s\t\t\t\t\t%s\n"                      "$MENUW_STUBBY"    "$MENUW_DOT"    # v3.00
    printf "%s\t\t\t\t\t\t\t\t\t%s\n"              ""                 "$MENUW_RPZ"    # v3.00
    printf "%s\t\t%s\n"                            "$MENUW_BIND"      "$MENUW_VPN"    # v3.07

    printf "\n%s\t\t\t%s\n"         "$MENUW_SCRIBE"    "$MENU_AD"      # v3.09 Hotfix v2.00 v1.25
    printf "%s\t\t%s\n"   "$MENUW_DNSMASQ"         "$MENU_EL"      # v3.10 v2.15
    printf "%s\t%s\n"       "$MENUW_DUMPCACHE" "$MENU_CA"      # v2.17 v2.12 v1.26
    printf "\t\t\t\t\t\t\t\t\t%s\n"                                "$MENUW_VIEWS"   # v3.17
    printf "\t\t\t\t\t\t\t\t\t%s\n"                                "$MENUW_SAFESEARCH"   # v3.22
    printf "\t\t\t\t\t\t\t\t\t%s\n"                                "$MENUW_LOCALHOST"   # v3.23
    printf "\n%s\t\t%s\n"           "$MENUW_DIG"     "$MENUW_LOOKUP" # v2.11
    printf "%s\t\t\t\t%s\n"         "$MENUW_DNSINFO" "$MENUW_DNSSEC"                 # v2.12 v1.28
    printf "%s\\n\n"                "$MENUW_LINKS"              # v1.28
    #printf '\n%be %b = Exit Script [?]\n' "${cBYEL}" "${cRESET}"
    printf '\n%b[Enter] %bLeave %bAdvanced Tools Menu\n' "${cBGRE}" "$cBCYA" "${cRESET}" # v1.21
}
Unbound_Installed() {
    if [ -f ${CONFIG_DIR}unbound.conf ] && [ -n "$(which unbound-control)" ];then   # v2.00
        echo "Y"                                                # v2.01
        return 0
    else
        echo "N"                                                # v2.01
        return 1
    fi
}
Show_credits() {
    printf '\n+======================================================================+\n'
    printf '|  Welcome to the %bunbound Manager/Installation script (Asuswrt-Merlin)%b |\n' "$cBGRE" "$cRESET"
    printf '|                                                                      |\n'
    local local CNT=23;VERSION_LENGTH=${#VERSION}                                   # v3.22
    [ $VERSION_LENGTH -gt 4 ] && CNT=$((CNT-(VERSION_LENGTH-4)))                    # v3.22
    local BLANKS=$(Repeat $CNT " ")                                                 # v3.22
    printf '|                      Version %b%s%b by Martineau%b' "$cBMAG" "$VERSION" "${cRESET}" "${BLANKS}|\n"    # v3.22
    printf '|                                                                      |\n'
}
Show_status() {

    if [ "$(Unbound_Installed)" == "Y" ];then

        local CONFIG_STATUS="Y"   # v3.23 Hack v3.00

        if [ -z "$(which unbound-control)" ] || [ "$CONFIG_STATUS" == "Y" ];then # V3.00 v2.03

            # Show unbound uptime
            local UNBOUNDPID=$(pidof unbound)
            if [ -n "$UNBOUNDPID" ];then
                # Each call to unbound-control takes upto 2secs!!!
                I=1

                # error: SSL handshake failed           # v2.02
                # 548130435088:error:1416F086:SSL routines:tls_process_server_certificate:certificate verify failed:ssl/statem/statem_clnt.c:1915:

                local UNBOUND_STATUS="$($UNBOUNCTRLCMD status)"
                local UNBOUNDUPTIME="$(echo "$UNBOUND_STATUS" | grep -E "uptime:.*seconds"  | awk '{print $2}')"
                local UNBOUNDVERS="$(echo "$UNBOUND_STATUS" | grep -E "version:.*$" | awk '{print $2}')"

                if [ -n "$UNBOUNDUPTIME" ];then         # v2.02
                    local UNBOUND_STATUS="unbound (pid $UNBOUNDPID) is running...  uptime: "$(Convert_SECS_to_HHMMSS "$UNBOUNDUPTIME" "days")" version: "$UNBOUNDVERS
                else
                    echo -e $cBRED"\a\n\t***ERROR unbound-control - failed'?"   # v2.02
                    #/opt/etc/init.d/S61unbound
                    #exit_message
                fi

                # Display 'unbound.conf' header if present
                local TAG="Date Loaded by unbound_manager "$(date)")"
                local UNBOUND_CONF_VER=$(head -n 1 ${CONFIG_DIR}unbound.conf) # v1.19
                if [ -n "$(echo "$UNBOUND_CONF_VER" | grep -iE "^#.*Version|Config" )" ];then  # v3.23 v2.04                                         # v2.05
                    local UNBOUND_CONF_VER_TXT=$UNBOUND_CONF_VER
                else
                    #sed -i "1s/Date.*Loaded.*$/$TAG/" ${CONFIG_DIR}unbound.conf
                    :
                fi
                echo -e ${cRESET}$cBMAG"\n"$UNBOUND_STATUS $UNBOUND_CONF_VER_TXT"\n"$cRESET      # v3.23 v1.19
                [ "$1" == "syslog" ] && SayT "$UNBOUND_STATUS $UNBOUND_CONF_VER_TXT"    # v2.18 Hotfix
            else
                local TAG="Date Loaded by unbound_manager "$(date)")"
                local UNBOUND_CONF_VER=$(head -n 1 ${CONFIG_DIR}unbound.conf) # v1.19
                if [ -n "$(echo "$UNBOUND_CONF_VER" | grep -iE "^#.*Version" )" ];then  # v2.04                                         # v2.05
                    local UNBOUND_CONF_VER_TXT=$UNBOUND_CONF_VER
                else
                    #sed -i "1s/Date.*Loaded.*$/$TAG/" ${CONFIG_DIR}unbound.conf
                    :
                fi
                echo -e "\a\n\e[44m${cBYEL}Warning unbound not running!!${cRESET} - Config last loaded info:"${cBMAG}$UNBOUND_STATUS $UNBOUND_CONF_VER_TXT"\n"$cRESET
                SayT "Warning unbound not running!! $UNBOUND_STATUS $UNBOUND_CONF_VER_TXT"  # v3.03
            fi
        else
           echo -e $cBRED"\a"
           if [ "$CONFIG_STATUS" == "N" ];then                     # V3.00
                unbound-checkconf ${CONFIG_DIR}unbound.conf         # v2.03
                echo -e $cBRED"\n***ERROR INVALID unbound ${cRESET}configuration - use option ${cBMAG}'vx'$cRESET to correct $cBMAG'unbound.conf'$cRESET or ${cBMAG}'rl'${cRESET} to load a valid configuration file\n\n\t\t\t\t\t or ${cBMAG}'e'${cRESET} exit; then issue debug command\n\n\t\t\t\t\t\t${cBMAG}unbound -dv${cRESET}\n\n"$cBGRE
           else
                echo -e $cBRED"\n***ERROR unbound ${cRESET}configuration contains ${cBYEL}DUPLICATES$cRESET - use option ${cBMAG}'vx'$cRESET to correct $cBMAG'unbound.conf'$cRESET or ${cBMAG}'rl'${cRESET} to load a valid configuration file\n"$cBGRE   # v3.00
                echo -e $cBYEL"\t$(Valid_unbound_config_Syntax "${CONFIG_DIR}unbound.conf" "returndup")\n"   # v3.00
           fi
        fi
        # If bind 'outgoing-interface' ENABLED, might be prudent to check that the interface is UP? otherwise SERVFAIL for ALL requests.
        if [ -n "$(grep "^outgoing-interface" ${CONFIG_DIR}unbound.conf)" ];then   # v3.16
            # Use obscure but benign URLthat most will never reference.....
            if [ -z "$(nslookup amdahl.com | grep -woE '([0-9]{1,3}\.){3}[0-9]{1,3}' | awk 'NR>2')" ];then
                echo -e $cBRED"\a\n***ERROR unbound ${cRESET}configuration contains 'outgoing-interface' and nslookup fails? use $cBMAG'bind [disable]'$cRESET to reset\n"$cRESET
                SayT "***ERROR unbound ${cRESET}configuration contains 'outgoing-interface' and nslookup fails? "
            fi
            # .....Remove it from the cache to prevent a false-positive for next time.
            $UNBOUNCTRLCMD flush amdahl.com 1>/dev/null   # v3.16
        fi
    fi
}
Calculate_Percent() {                                                           # v3.07

        local TOTAL=$1
        local HITS=$2

        if [ -n "$TOTAL" ] && [ $TOTAL -gt 0 ];then
            local PCT=`expr "$HITS" \* "100" / "$TOTAL"`                    # v3.18 HotFix
        else
            local PCT=0
        fi

        echo $PCT
}
Read_INPUT() {

# shellcheck disable=SC2120,SC2154
_GetKEY() {

        #local OLDIFS=$IFS

        # Doesn't require user also hitting ENTER
        IFS= read -rsn1  "${@:-char}"               # v3.00

        #IFS=$OLDIFS

        echo -en $char 2>&1
}

        local ESC=$(printf "\x1b")                              # v3.18
        local ENTER=$(printf "\x0a")                            # v3.18
        local BACKSPACE_VT220=$(printf "\x7e")                  # v3.18 Xshell6 Del VT220 aka Esc[3~
        local BACKSPACE_ASCII=$(printf "\x7f")                  # v3.18 Xshell6 CTRL+? ASCII 127
        local BACKSPACE=$(printf "\x08")                        # v3.18 Xshell6 CTRL+H

        local DEL=$(printf "\x7e")                              # v3.18

        local JUNK=

        local CHAR=
        local LBUF=
        local RBUF=
        local KEY_CNT=0

        local X=0
        local RECALLINDEX=0
        local MAX_RECALLINDEX=6

        if [ -n "$CMDLINE" ];then                             # v3.18 Only save last command if it's non-blank
            CMD5="$CMD4";CMD5=$CMD5
            CMD4="$CMD3"
            CMD3="$CMD2"
            CMD2="$CMD1"
            CMD1="$CMDLINE"                           # v3.18 Hotfix
        fi

        local OLDIFS=$IFS

        while true;do                                       # v3.18

            #local CHAR=$(_GetKEY)
            IFS= read -rsn1 "CHAR"

            if [ "$CHAR" == "$ESC" ]; then                  # v3.18
                read -rsn2 JUNK # Read 2 more CTRL chars
                case "$JUNK" in                              # v3.18 A-UP;B-DOWN;C-RIGHT;D-LEFT
                    "[A")                                     # v3.18 CSR_UP
                       local RECALLINDEX=$((RECALLINDEX+1))
                       [ $RECALLINDEX -eq $MAX_RECALLINDEX ] && RECALLINDEX=1

                       eval local LBUF_TMP="\$CMD$RECALLINDEX"     # v3.18 Retrieve last cmd from 'buffer stack'
                       if [ -z "$LBUF_TMP" ];then
                            if [ $RECALLINDEX -gt 1 ];then
                                local RECALLINDEX=1
                                local LBUF="$CMD1"
                            fi
                       else
                            local LBUF=$LBUF_TMP
                       fi
                       if [ -n "$LBUF" ];then
                            echo -en ${xPOSCSR}${xERASEEOL}$LBUF
                            local KEY_CNT=${#LBUF}
                       else
                            local RECALLINDEX=0
                       fi
                        ;;
                    "[D")                                    # 3.18 CSR_LEFT
                        if [ ${#LBUF} -gt 0 ];then
                            echo -en "\e[D"
                            local X=$((${#LBUF}-1))
                            [ -z "$RBUF" ] && local RBUF=${LBUF:$X} || local RBUF=${LBUF:$X}${RBUF}
                            local LBUF=${LBUF:0:$X}
                        fi
                        ;;
                    "[C")                                    # 3.18 CSR_RIGHT
                        if [ ${#RBUF} -gt 0 ];then
                            echo -en "\e[C"
                            local LBUF=${LBUF}${RBUF:0:1}
                            local RBUF=$(echo "$RBUF" | sed 's/^.//')
                        fi;;
                    *)
                        :
                        ;;
                esac
                continue
            fi

            if [ "$CHAR" == "$BACKSPACE" ] || [ "$CHAR" == "$BACKSPACE_ASCII" ]  || [ "$CHAR" == "$BACKSPACE_VT220" ];then   # v3.18 Hotfix
               if [ $((KEY_CNT+PROMPT_SIZE)) -gt $PROMPT_SIZE ];then
                   echo -en ${CHAR}$xERASEEOL
                   LBUF=$(echo "$LBUF" | sed 's/.$//')
                   local KEY_CNT=$((KEY_CNT-1))
                   [ -n "$RBUF" ] && echo -en ${xCSRPOS}${xERASEEOL}${RBUF}$xPOSCSR
               fi
               continue
            fi

            if [ -n "$RBUF" ] && [ "$CHAR" == "$DEL" ];then
                local RBUF="$(echo "$RBUF" | sed 's/^.//')"
                local KEY_CNT=$((KEY_CNT-1))
                echo -en ${xCSRPOS}${xERASEEOL}${RBUF}$xPOSCSR
                continue
            fi

            [ "$CHAR" == "$ENTER" ] && break       # v3.18 Hotfix

            [ "$CHAR" == " " ] && echo -en " "     # v3.18 Hack!!!!!

            echo -en ${CHAR}${xCSRPOS}${xERASEEOL}${RBUF}$xPOSCSR
            LBUF=${LBUF}${CHAR}
            local KEY_CNT=$((KEY_CNT+1))
        done

        IFS=$OLDIFS                                 # v3.18

        CMDLINE="${LBUF}$RBUF"                       # Tacky GLOBAL!!!!

        echo -e 2>&1                                # v3.18 HotFix

}
welcome_message() {

        # Reinstate CTRL-C if 'trap 'welcome_message' INT brought us here!      # 3.06 Fix
        trap 'exit_message' INT                                                 # Release lockfile

        # No need to recreate the STATIC menu items on each invocation
        if [ -z "$MENU_Z" ];then                                # v2.12
            if [ "$EASYMENU" != "Y" ];then
              MENU_Z="$(printf '%bz %b = %bRemove%b unbound/unbound_manager\n' "${cBYEL}" "${cRESET}" "${cBRED}" "${cRESET}")"         # v2.06 Hotfix for amtm
              MENU_VB="$(printf '%bvb%b = Backup current %b(%s)%b Configuration [filename]\n' "${cBYEL}" "${cRESET}" "$cBGRE" "${CONFIG_DIR}unbound.conf" "${cRESET}")"  # v3.23 @mister v1.28
              MENU_3="$(printf '%b3 %b = Advanced Tools\n' "${cBYEL}" "${cRESET}")"
              MENU__="$(printf '%b? %b = About Configuration\n' "${cBYEL}" "${cRESET}")"  # v1.17
              MENUW_X="$(printf '%bx %b = Stop unbound\n' "${cBYEL}" "${cRESET}")"  # v1.28
              #MENU_FM="$(printf '%bfastmenu%b = Disable SLOW unbound-control LAN SSL cert validation\n' "${cBYEL}" "${cRESET}")"
              MENUW_SCRIBE="$(printf '%bscribe%b = Enable scribe (syslog-ng) unbound logging\n' "${cBYEL}" "${cRESET}")"  # v1.28
              MENUW_FFDOH="$(printf '%bDisableFirefoxDoH%b = Disable Firefox DoH [yes | no]\n' "${cBYEL}" "${cRESET}")"
              MENUW_STUBBY="$(printf '%bStubby%b = Enable Stubby Integration\n' "${cBYEL}" "${cRESET}")"  # v3.00
              MENUW_DNSMASQ="$(printf '%bdnsmasq%b = Disable dnsmasq [disable | interfaces | nointerfaces]\n' "${cBYEL}" "${cRESET}")"  # v3.10
              MENUW_VIEWS="$(printf '%bviews%b = [? | uninstall] | {view_name [? | remove]} | {view_name [[type] domain_name[...] | IP_address[...]] [del]} ]\n' "${cBYEL}" "${cRESET}")"
              MENUW_SAFESEARCH="$(printf '%bsafesearch%b = Enable Safe Search [disable | status | ? ] e.g. redirect 'google.com' to 'forcesafesearch.google.com' \n' "${cBYEL}" "${cRESET}")"
              MENUW_LOCALHOST="$(printf '%blocalhost%b = Add { domain_name {IP_address | 'del'} }\n' "${cBYEL}" "${cRESET}")"       # v3.23
              MENUW_DOT="$(printf '%bDoT%b = Enable DNS-over-TLS\n' "${cBYEL}" "${cRESET}")"
              MENUW_RPZ="$(printf '%bfirewall%b = Enable DNS Firewall [disable | ?]\n' "${cBYEL}" "${cRESET}")"  # v3.02
              MENUW_VPN="$(printf '%bvpn%b = BIND unbound to VPN {vpnid [debug]} | [disable | debug show] e.g. vpn 1\n' "${cBYEL}" "${cRESET}")"  # v3.07
              MENUW_BIND="$(printf '%bbind%b = BIND unbound to WAN [debug | disable | debug show]\n' "${cBYEL}" "${cRESET}")"  # v3.07
              MENUW_ADBLOCK="$(printf '%badblock%b = Install Ad Block [uninstall | update | track]\n' "${cBYEL}" "${cRESET}")"  # v3.12 v3.03
              MENUW_YOUTUBE="$(printf '%byoutube%b = Install YouTube Ad Block [uninstall | update]\n' "${cBYEL}" "${cRESET}")"  # v3.11
              MENUW_DNSSEC="$(printf '%bdnssec%b = {url} Show DNSSEC Validation Chain e.g. dnssec www.snbforums.com\n' "${cBYEL}" "${cRESET}")"  # v1.28
              MENUW_DNSINFO="$(printf '%bdnsinfo%b = {dns} Show DNS Server e.g. dnsinfo \n' "${cBYEL}" "${cRESET}")"  # v1.28
              MENUW_LINKS="$(printf '%blinks%b = Show list of external URL links\n' "${cBYEL}" "${cRESET}")"  # v1.28
              MENUW_DIG="$(printf '%bdig%b = {domain} [time] Show dig info e.g. dig asciiart.com\n' "${cBYEL}" "${cRESET}")"    # v2.09
              MENUW_LOOKUP="$(printf '%blookup%b = {domain} Show the name servers used for domain e.g. lookup asciiart.eu \n' "${cBYEL}" "${cRESET}")"
              MENUW_DUMPCACHE="$(printf '%bdumpcache%b = [bootrest] (or Manually use %brestorecache%b after REBOOT)\n' "${cBYEL}" "${cRESET}" "${cBYEL}" "${cRESET}" )"  # v2.12
              MENU_RL="$(printf "%brl%b = Reload Configuration (Doesn't halt unbound) e.g. 'rl test1[.conf]' (Recovery use 'rl reset/user')\n" "${cBYEL}" "${cRESET}")"
              MENU_SD="$(printf "%bsd%b = Show dnsmasq Statistics/Cache Size\n" "${cBYEL}" "${cRESET}")"
            else
              MENU_Z="$(printf '%b2 %b = %bRemove%b unbound/unbound_manager\n' "${cBYEL}" "${cRESET}" "${cBRED}" "${cRESET}")"         # v2.06 Hotfix for amtm
            fi
        fi

        Show_credits

        if [ "$(Unbound_Installed)" == "Y" ];then   # v2.12
            HDR="N"
            printf '+======================================================================+'   # 2.13

            if [ -n "$(grep  "^#verbosity:" ${CONFIG_DIR}unbound.conf)" ];then      # v3.09 Hotfix @Safemode
                Edit_config_options "verbosity"       "uncomment"                     # v3.09 Hotfix
                sed -i "/^verbosity:/ s/[^ ]*[^ ]/0/2" ${CONFIG_DIR}unbound.conf    # v3.09 Hotfix
            fi

            # The cron job should really be created from init-start or /init.d/S61unbound??????
            if [ -n "$(awk '/^verbosity/ {print $2}' ${CONFIG_DIR}unbound.conf)" ] || [ "$(unbound_Control "oq" "verbosity" "value")" != "0" ];then   # v3.06
                # Cron job 00:01 daily to check'n'delete log file when it is >10MB
                cru d unboundLOG 2>/dev/null                                                              # v3.06
                cru a unboundLOG "1 0 * * * /opt/bin/find ${CONFIG_DIR}unbound.log -size +10M -exec rm -f {} \;"   # v3.06
            fi
        fi

        # Identify currently installed eligible AUTO Reply options
        [ -n "$(pidof unbound)" ] && CURRENT_AUTO_OPTIONS=$(Check_GUI_NVRAM "active")   # v2.18
        if [ -n "$CURRENT_AUTO_OPTIONS" ];then                                             # v2.18
            #local TXT=$cRESET"Auto Reply='y' for User Selectable Options ('"$CURRENT_AUTO_OPTIONS"')"   # v2.18
            USER_OPTION_PROMPTS="N"                   # v2.18
        fi

        while true; do

            # If unbound already installed then no need to display FULL HDR - stops confusing idiot users ;-:
            if [ "$HDR" == "ForceDisplay" ];then            # v2.12
                HDR=                                        # v2.12 Show the header Splash box in FULL
                Show_credits
            fi

            # No need to display the Header box every time....
            if [ -z "$HDR" ];then                               # v1.09

                printf '| Requirements: USB drive with Entware installed                       |\n'
                printf '|                                                                      |\n'
                if [ "$EASYMENU" == "N" ];then                  # v2.07
                    printf '|   i = Install unbound DNS Server - Advanced Mode                     |\n'
                else
                    printf '|   1 = Install unbound DNS Server                                     |\n'
                fi
                local YES_NO="   "                              # v2.07
                [ "$EASYMENU" == "Y" ] && local YES_NO="${cBGRE}   ";   printf '|       o1. Enable unbound Logging                             %b    %b |\n' "$YES_NO" "$cRESET"
                [ "$EASYMENU" == "Y" ] && local YES_NO="${cGRA}   ";    printf '|       o2. Integrate with Stubby (%bAdvanced Users%b)             %b    %b |\n' "$cBRED" "$cRESET" "$YES_NO" "$cRESET"
                [ "$EASYMENU" == "Y" ] && local YES_NO="${cGRA}   ";    printf '|       o3. Install Ad and Tracker Blocking                    %b    %b |\n' "$YES_NO" "$cRESET"
                [ "$EASYMENU" == "Y" ] && local YES_NO="${cBGRE}   ";   printf '|       o4. Customise CPU/Memory usage                         %b    %b |\n' "$YES_NO" "$cRESET"
                [ "$EASYMENU" == "Y" ] && local YES_NO="${cGRA}   ";    printf '|       o5. Disable Firefox DNS-over-HTTPS (DoH) (USA users)   %b    %b |\n' "$YES_NO" "$cRESET"
                [ "$EASYMENU" == "Y" ] && local YES_NO="${cGRA}   ";    printf '|       o6. Install Graphical Statistics GUI (Add-ons) TAB     %b    %b |\n' "$YES_NO" "$cRESET"
                [ "$EASYMENU" == "Y" ] && local YES_NO="${cGRA}   ";    printf '|       o7. Integrate with DoT (%bAdvanced Users%b)                %b    %b |\n' "$cBRED" "$cRESET" "$YES_NO" "$cRESET"
                [ "$EASYMENU" == "Y" ] && local YES_NO="${cGRA}   ";    printf '|       o8. Enable DNS Firewall                                %b    %b |\n' "$YES_NO" "$cRESET"
                [ "$EASYMENU" == "Y" ] && local YES_NO="${cGRA}   ";    printf '|       o9. Install YouTube Ad Blocking                        %b    %b |\n' "$YES_NO" "$cRESET"   # v3.11
                printf '|                                                                      |\n'

                if [ "$EASYMENU" == "N" ];then                  # v2.07
                    printf '|   z  = Remove unbound/unbound_manager                                |\n'
                    printf '|   ?  = About Configuration                                           |\n'
                    printf '|   3  = Advanced Tools                                                |\n'
                fi
                printf '|                                                                      |\n'
                printf '|     See SNBForums thread %b%s%b for legacy      |\n' "$cBGRE" "https://tinyurl.com/s89z3mm" "$cRESET"
                printf '|         user tips on unbound usage/configuration.                    |\n'
                printf '+======================================================================+\n'

                HDR="N"                                     # v1.09

            fi

            if [ "$1" = "uninstall" ]; then
                menu1="z"                                   # v1.21
            else
                #if [ "$1" != "nochk" ];then                 # v3.22 v2.13
                    Show_status                         # v2.18
                #fi

                if [ $CHECK_GITHUB -eq 1 ];then             # v1.20

                    GITHUB_DIR=$GITHUB_MARTINEAU

                    localmd5="$(md5sum "$0" | awk '{print $1}')"

                    if [ "$1" != "nochk" ];then                 # v3.22
                        REMOTE_VERSION_NUMDOT="$(curl -${SILENT}fLN --retry 3 --connect-timeout 3 "${GITHUB_DIR}/unbound_manager.sh" | grep -E "^VERSION" | tr -d '"' | sed 's/VERSION\=//')" || REMOTE_VERSION_NUMDOT="?.??" # v3.16 Hotfix v1.11 v1.05
                        if [ -z "$REMOTE_VERSION_NUMDOT" ] || [ "$REMOTE_VERSION_NUMDOT" == "?.??" ];then
                            echo -e ${cRESET}$cRED_"\a\t***ERROR Unable to verify Github version...check DNS/Internet access!\n\n"$cRESET
                            REMOTE_VERSION_NUMDOT=
                        else
                            [ "$1" != "nochk" ] && remotemd5="$(curl -${SILENT}fL  --retry 3 --connect-timeout 3 "${GITHUB_DIR}/unbound_manager.sh" | md5sum | awk '{print $1}')"  # v3.16 Hotfix v1.11
                            REMOTE_VERSION_NUM=$(echo $REMOTE_VERSION_NUMDOT | sed 's/[^0-9]*//g')  # v1.04
                        fi
                    fi

                    LOCAL_VERSION_NUM=$(echo $VERSION | sed 's/[^0-9]*//g')             # v1.04

                    local CHANGELOG="$cRESET(${cBCYA}Change Log: ${cBYEL}https://github.com/MartineauUK/Unbound-Asuswrt-Merlin/commits/master/unbound_manager.sh$cRESET)"
                    [ -n "$(echo $VERSION | grep "b")" ] && local CHANGELOG="$cRESET(${cBCYA}Change Log: ${cBYEL}https://github.com/MartineauUK/Unbound-Asuswrt-Merlin/commits/dev/unbound_manager.sh$cRESET)"  # v3.20

                    # As the developer, I need to differentiate between the GitHub md5sum hasn't changed, which means I've tweaked it locally
                    if [ -n "$REMOTE_VERSION_NUMDOT" ];then
                        [ ! -f /jffs/addons/unbound/unbound_manager.md5 ] && echo $remotemd5 > /jffs/addons/unbound/unbound_manager.md5   # v2.03 v1.09
                    fi

                    [ -z "$REMOTE_VERSION_NUM" ] && REMOTE_VERSION_NUM=0            # v1.11

                    # MD5 Mismatch due to local development?
                    if [ "${VERSION#????}" == "b" ] || { [ "$(awk '{print $1}' /jffs/addons/unbound/unbound_manager.md5)" == "$remotemd5" ]; } && [ "$localmd5" != "$remotemd5" ];then # v 3.15 v1.28
                        if [ $REMOTE_VERSION_NUM -lt $LOCAL_VERSION_NUM ];then      # v1.09
                            ALLOWUPGRADE="N"                                                # v1.09
                            UPDATE_SCRIPT_ALERT="$(printf '%bu  = Push to Github PENDING for %b(Major) %b%s%b UPDATE %b%s%b >>>> %b%s\n\n' "${cBRED}" "${cBGRE}" "$cRESET" "$(basename $0)" "$cBRED" "$cBMAG" "v$VERSION" "$cRESET" "$cBGRE" "v$REMOTE_VERSION_NUMDOT")" # v1.21
                        else
                            ALLOWUPGRADE="N"
                            UPDATE_SCRIPT_ALERT="$(printf '%bu  = Push to Github PENDING for %b(Minor Hotfix) %b%s update >>>> %b%s %b%s\n\n' "${cBRED}" "$cBRED" "$cBGRE" "$cRESET" "$(basename $0)" "$cRESET" "$cBMAG" "v$VERSION")" # v11.21
                        fi
                    else
                        if [ "$localmd5" != "$remotemd5" ]; then
                            if [ $REMOTE_VERSION_NUM -ge $LOCAL_VERSION_NUM ];then      # v1.27
                                if [ $REMOTE_VERSION_NUM -gt $LOCAL_VERSION_NUM ];then  # v1.27
                                    UPDATE_SCRIPT_ALERT="$(printf '%bu%b  = %bUpdate (Major) %b%s %b%s -> %b %s\n\n' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION" "v$REMOTE_VERSION_NUMDOT" "$CHANGELOG")"   # v3.15 v1.21
                                else
                                    UPDATE_SCRIPT_ALERT="$(printf '%bu%b  = %bUpdate (Minor Hotfix) %b%s %b%s -> %b %s\n\n' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION" "v$REMOTE_VERSION_NUMDOT" "$CHANGELOG")"   # v3.15
                                fi
                            fi
                        fi
                    fi
                fi

                [ -n "$UPDATE_SCRIPT_ALERT" ] && echo -e $UPDATE_SCRIPT_ALERT"\n"    # v1.25 Fix by SNB Forum Member @Cam
                CHECK_GITHUB=0                                                  # v1.27 Only check Github on first run of script or 'rl' a config

                if [ -z "$SUPPRESSMENU" ];then                                  # v1.11

                    if [ -f ${CONFIG_DIR}unbound.conf ];then                   # v1.06

                        if [ "$EASYMENU" == "N" ];then
                            MENU_I="$(printf '%bi %b = Update unbound and configuration %b%s%b\n' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET")"
                            MENU_VX="$(printf '%bv %b = View %b%s %bunbound Configuration (%bvx%b=Edit;%bvh%b=help)\n' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')"  "$cRESET" "${cBYEL}" "${cRESET}" "${cBYEL}" "${cRESET}")" # v3.06
                        else
                            MENU_VX="$(printf '%bv %b = View %b%s\n' "${cBYEL}" "${cRESET}" "$cBGRE" "('${CONFIG_DIR}unbound.conf')")"    # v 3.23 Hotfix @PeterR v3.00
                        fi

                        MENU_RS="$(printf '%brs%b = %bRestart%b (or %bStart%b) unbound (%b)\n' "${cBYEL}" "${cRESET}" "$cBGRE" "${cRESET}" "$cBGRE" "${cRESET}" "use $cBGRE'rs nocache'$cRESET to flush cache" )"

                    else
                        if [ "$EASYMENU" == "N" ] ;then
                            MENU_I="$(printf '%bi %b = %bBegin%b unbound Installation Process %b%s%b\n' "${cBYEL}" "${cRESET}" "$cBGRE" "${cRESET}" "${cBGRE}" "('$CONFIG_DIR')" "$cRESET")"
                        else
                            [ -z "$ADVANCED_TOOLS" ] && MENU_I="$(printf '%b1 %b = Begin unbound Installation Process %b%s%b\n%b2 %b = Begin unbound Advanced Installation Process %b%s%b\n%b3 %b = Advanced Tools\n\n ' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET" "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET"  "${cBYEL}" "${cRESET}" )"
                        fi
                    fi

                    # Always rebuild the dynamic menu items if unbound INSTALLED & UP
                    if [ "$1" != "nochk" ];then                                                         # v2.13
                        #if [ "$(Valid_unbound_config_Syntax "${CONFIG_DIR}unbound.conf")" == "Y" ];then # v3.23 v2.03
                            if [ "$(Unbound_Installed)" == "Y" ];then           # Installed?  v2.18 Hotfix @toazd
                                if [ -n "$(pidof unbound)" ];then   # UP ?
                                    if [ "$EASYMENU" == "N" ];then
                                        MENU_OQ="$(printf "%boq%b = Query unbound Configuration option e.g 'oq verbosity' (%box%b=Set) e.g. 'ox log-queries yes'\n" "${cBYEL}" "${cRESET}" "${cBYEL}" "${cRESET}")"
                                        MENU_CA="$(printf "%bca%b = Cache Size Optimisation [ min | calc ]\n" "${cBYEL}" "${cRESET}")"
                                        local LOGLEVEL=$(unbound_Control "oq" "verbosity" "value")         # v3.09
                                        # Takes 0.75 - 2 secs :-( unless 'fastmenu' option ENABLED! ;-)
                                        if [ "$(awk '/^verbosity:.*[1-5]/ {print $2}' ${CONFIG_DIR}unbound.conf)" -gt 0 ] || [ "$LOGLEVEL" != "0" ];then   # v3.09 v3.08 v3.06 v1.16
                                            LOGSTATUS=$cBGRE"LIVE ${cBCYA}(Loglevel="${LOGLEVEL}") "$cRESET
                                            LOGGING_OPTION="(${cBYEL}lx${cRESET}=Disable Logging)"
                                        else
                                            LOGSTATUS=
                                            LOGGING_OPTION="(${cBYEL}lo${cRESET}=Enable FULL Logging [log_level])"
                                        fi
                                        MENU_L="$(printf "%bl %b = Show unbound %blog entries $LOGGING_OPTION\n" "${cBYEL}" "${cRESET}" "$LOGSTATUS")"

                                        # Takes 0.75 - 2 secs :-( unless 'fastmenu' option ENABLED! ;-)
                                        if [ "$($UNBOUNCTRLCMD get_option extended-statistics)" == "yes" ] || [ "$(Get_unbound_config_option "extended-statistics:")" == "yes" ] ;then    # v 2.14 v1.18
                                            EXTENDEDSTATS=$cBGRE" Extended"$cRESET
                                            EXTENDEDSTATS_OPTION="s-=Disable Extended Stats"
                                        else
                                            EXTENDEDSTATS=
                                            EXTENDEDSTATS_OPTION="s+=Enable Extended Stats"
                                        fi

                                        GUI_TAB="sgui=Install GUI TAB [all]; "                                # v2.15

                                        if [ -f /jffs/addons/unbound/unboundstats_www.asp ];then
                                            GUI_TAB=                                                    # v2.15 'sgui uninstall=' ?
                                            if [ -f /tmp/menuTree.js ];then                                                     # v3.23
                                                EXTENDEDSTATS_OPTION=$cBYEL"$HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/"$(grep -i unbound /tmp/menuTree.js  | grep -Eo "(user.*\.asp)")$cRESET # v2.16
                                            else
                                                # Error unbound is not ACTUALLY in '/tmp/menuTree.js' so indicate user should run 'sgui'        # v3.23
                                                GUI_TAB="sgui=Install GUI TAB [all]; "                  # v3.23
                                            fi
                                        fi

                                        MENU_S="$(printf '%bs %b = Show unbound%b statistics (s=Summary Totals; sa=All; %s%b)\n' "${cBYEL}" "${cRESET}" "${EXTENDEDSTATS}" "${GUI_TAB}" "${EXTENDEDSTATS_OPTION}")"   # v2.16

                                        MENU_EL="$(printf '%bea%b = Edit Ad Block Allowlist (eb=Blocklist; ec=Config; el {Ad Block file})\n' "${cBYEL}" "${cRESET}")"   # v2.15
                                        if [ -f ${CONFIG_DIR}adblock/gen_adblock.sh ] && [ -n "$(grep blocksites ${CONFIG_DIR}adblock/gen_adblock.sh)" ];then   # v2.17
                                            MENU_EL="$(printf '%bea%b = Edit Ad Block Allowlist (eb=Blocklist; eca=Config-AllowSites; ecb=Config-BlockSites; el {Ad Block file})\n' "${cBYEL}" "${cRESET}")"    # v2.17
                                        fi
                                        [ "$(Get_unbound_config_option "adblock/adservers" ${CONFIG_DIR}unbound.conf)" == "?" ] && MENU_EL=     # v2.15
                                    fi
                                fi
                            fi
                        #fi
                    fi

                    if [ "$EASYMENU" == "N" ] && [ -n "$(which diversion)" ] ;then
                        MENU_AD="$(printf '%bad%b = Analyse Diversion White/Block lists [ file_name ] ["type=adblock"] ["action=merge"]\n' "${cBYEL}" "${cRESET}")"
                    fi

                    # v1.08 Use 'context aware' horizontal menu!!!! Radical eh?
                    if [ "$EASYMENU" == "N" ];then
                        if [ -z "$ADVANCED_TOOLS" ];then                           # v1.21
                            printf "%s\t\t%s\n"            "$MENU_I" "$MENU_L"
                        fi

                        if [ -n "$ADVANCED_TOOLS" ];then                           # v1.26
                            Show_Advanced_Menu
                        else                                                       # v1.26
                            printf "%s\t\t\t\t\t%s\n"      "$MENU_Z" "$MENU_VX"    # v1.11
                            printf "%s\t\t\t\t\t\t\t%s\n"  "$MENU_3" "$MENU_RL"    # v1.17
                            printf "%s\t\t\t\t\t\t%s\n"    "$MENU__" "$MENU_OQ"
                            echo
                            printf "%s\t%s\n"              "$MENU_RS" "$MENU_S"    # v2.11

                        fi
                    else
                        # Generate v3.00 Easy (dynamically context aware) menu
                        if [ -f /opt/etc/init.d/S61unbound ] || [ -f ${CONFIG_DIR}unbound.conf ];then       # v3.00
                            MENU_I="$(printf '%b1 %b = %bUpdate%b unbound files and configuration' "${cBYEL}" "${cRESET}" "${cBGRE}" "${cRESET}")"
                        else
                            MENU_I="$(printf '%b1 %b = %bBegin%b unbound Installation Process' "${cBYEL}" "${cRESET}" "${cBGRE}" "${cRESET}")"
                        fi
                        if [ -n "$(pidof unbound)" ];then
                            MENU_S="$(printf '%b3 %b = %bStop%b unbound' "${cBYEL}" "${cRESET}" "${cBRED}" "${cRESET}" )"
                            MENU_ST="$(printf '%b4 %b = Show unbound statistics' "${cBYEL}" "${cRESET}")"

                            if [ ! -f /tmp/menuTree.js ] || [ -z "$(grep -i "Unbound" /tmp/menuTree.js)" ];then
                                MENU_T="$(printf '%b6 %b = %bInstall%b Graphical Statistics GUI Add-on TAB' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET")"   # v3.15
                            else
                                MENU_T="$(printf '%b6 %b = %bUninstall%b Graphical Statistics GUI Add-on TAB' "${cBYEL}" "${cRESET}" "$cBRED" "$cRESET")"   # v3.15
                            fi

                            if ! grep -qF "Unbound_RPZ" /jffs/scripts/services-start; then                  # v3.02 Hotfix
                                MENUW_RPZ="$(printf '%b7 %b = %bEnable%b    DNS Firewall' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET")"   # v3.15 v3.02 Hotfix
                            else
                                MENUW_RPZ="$(printf '%b7 %b = %bDisable  %b DNS Firewall [?]' "${cBYEL}" "${cRESET}" "$cBRED" "$cRESET")"  # v3.15 v3.02 Hotfix
                            fi

                            if [ -f /opt/var/lib/unbound/adblock/gen_ytadblock.sh ];then                    # v3.11 HotFix
                               MENUW_YOUTUBE="$(printf '%b8 %b = %bUninstall%b YouTube Ad blocker' "${cBYEL}" "${cRESET}" "$cBRED" "$cRESET")"   # v3.15
                            else
                               MENUW_YOUTUBE="$(printf '%b8 %b = %bInstall%b YouTube Ad blocker' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET")"  # v3.15
                            fi
                            if [ -n "$(grep "^include.*unbound\.conf\.safesearch" ${CONFIG_DIR}unbound.conf)" ];then                    # v3.22
                               MENUW_SAFESEARCH="$(printf '%b9 %b = %bUninstall%b Safe Search' "${cBYEL}" "${cRESET}" "$cBRED" "$cRESET")"   # v3.22
                            else
                               MENUW_SAFESEARCH="$(printf '%b9 %b = %bInstall%b Safe Search e.g. google.com->forcesafesearch.google.com' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET")"  # v3.22
                            fi
                        else
                            if [ -f /opt/etc/init.d/S61unbound ];then
                                MENU_S="$(printf '%b3 %b = %bStart%b unbound' "${cBYEL}" "${cRESET}" "${cBGRE}" "${cRESET}")"
                            else
                                MENU_S="$(printf '%b3 %b = n/a Start unbound' "${cBYEL}" "${cRESET}$cGRA")"
                            fi
                            MENU_ST="$(printf '%b4 %b = n/a Show unbound statistics' "${cBYEL}" "${cRESET}$cGRA")"
                            MENU_T="$(printf '%b6 %b = n/a Install Graphical Statistics GUI Add-on TAB' "${cBYEL}" "${cRESET}$cGRA")"
                            MENUW_RPZ="$(printf '%b7 %b = n/a Enable DNS Firewall' "${cBYEL}" "${cRESET}$cGRA")"   # v3.02 Hotfix
                            MENUW_YOUTUBE="$(printf '%b8 %b = n/a Install YouTube Ad blocker' "${cBYEL}" "${cRESET}$cGRA")"   # v3.14
                            MENUW_SAFESEARCH="$(printf '%b8 %b = n/a Install Safe Search' "${cBYEL}" "${cRESET}$cGRA")"   # v3.22
                        fi
                        if [ -f ${CONFIG_DIR}unbound.conf ] && [ -n "$(grep -E "^[\s]*include:.*adblock/adservers" ${CONFIG_DIR}unbound.conf)" ];then
                            MENU_AD="$(printf '%b5 %b = %bUninstall%b Ad and Tracker blocker (Ad Block)' "${cBYEL}" "${cRESET}" "$cBRED" "$cRESET")"   # v3.15
                        else
                            if [ -d /opt/var/lib/unbound/adblock ];then
                                MENU_AD="$(printf '%b5 %b = %bInstall%b Ad and Tracker blocker (Ad Block)' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET")"   # v3.15
                            else
                                MENU_AD="$(printf '%b5 %b = n/a Install Ad and Tracker blocker (Ad Block)' "${cBYEL}" "${cRESET}$cGRA")"
                            fi
                        fi


                        MENU__="$(printf '%b? %b = About Configuration\n' "${cBYEL}" "${cRESET}")"  # v1.17

                        echo -en $cRESET
                        printf "%s\t\t\t\t\t\t%s\n"                 "$MENU_I" "$MENU_AD"           # v3.15
                        printf "%s\t\t\t\t\t\t\t%s\n"               "$MENU_Z" "$MENU_T"
                        printf "%s\t\t\t\t\t\t\t\t\t%s\n"           "$MENU_S" "$MENUW_RPZ"         # v3.02 Hotfix
                        printf "%s\t\t\t\t\t\t\t\t%b\n"             "$MENU_ST" "$MENUW_YOUTUBE"     # v3.11
                        printf "\t\t\t\t\t\t\t\t\t\t\t%b\n"         "$MENUW_SAFESEARCH"             # v3.22
                        printf "\n%s\t\t\t\t\t\n"                   "$MENU__"
                        printf "%s\t\t\n"                           "$MENU_VX"

                    fi
                    printf '\n%be %b = Exit Script [?]\n' "${cBYEL}" "${cRESET}"
                fi

                # Show 'E[asy]'/'A[dvanced]' mode, and does the selection require ENTER?    # v3.03 revert to 'normal' behaviour
                if [ "$EASYMENU" == "N" ];then
                   TXT="A:"
                   #printf '\n%b%s%bOption ==>%b ' "$cBCYA" "$TXT" "${cBYEL}" "${cRESET}"
                else
                   TXT="E:"
                   #printf '\n%b%s%bPress desired Option key (no ENTER key reqd.) %bOption ==>%b ' "$cBCYA" "$TXT" "${cBYEL}" "${cRESET}" "${cBYEL}"
                fi
                local PROMPT=${TXT}$DEBUGMODE"Option ==> "
                local PROMPT_SIZE=${#PROMPT}
                printf '\n%b%s%bOption ==>%b ' "$cBCYA" "${TXT}$DEBUGMODE" "${cBYEL}" "${cRESET}"
                echo -en $xCSRPOS

                [ "$READLINE" == "ReadLine" ] && Read_INPUT || read -r "CMDLINE"

                menu1="$CMDLINE"

            fi
            local TXT=
            unset $TXT
            HDR="N"

            # Translate v3.00 (restricted) Easy menu but Advanced mode commands remain for consistency backward compatibility.
            if [ "$EASYMENU" == "Y" ];then

                case "$menu1" in
                    0) ;;
                    1|i) menu1="i?";;
                    2|z) menu1="z";;
                    3|x) [ -n "$(pidof unbound)" ] && menu1="x" || menu1="rs";;
                    4|s) menu1="s";;
                    5|adblock*) [ -n "$(echo "$MENU_AD" | grep "Uninstall" )" ] && menu1="adblock uninstall" || menu1="adblock";;   # v3.10
                    6|sgui) [ -n "$(echo "$MENU_T"  | grep "Uninstall" )" ] && { GUI_Stats_TAB "uninstall"; menu1=; } || menu1="sgui";;
                    7*|firewall*) if [ "$menu1" == "7" ];then                                                    # v 3.03
                                     [ -n "$(echo "$MENUW_RPZ"  | grep "Disable" )" ] && { DNS_Firewall "disable"; menu1=; } || menu1="firewall"   # v3.02 Hotfix
                                  else
                                     [ -n "$(echo "$menu1" | grep -E "7.*\?")" ] && menu1="firewall ?"                  # v3.03
                                  fi
                    ;;
                    8*|youtube*) [ -n "$(echo "$MENUW_YOUTUBE" | grep "Uninstall" )" ] && menu1="youtube uninstall" || menu1="youtube";;   #v3.11
                    safesearchv|safesearchx) ;;         # v3.22
                    9*)                                                             #v3.22
                                  if [ -n "$(echo "$MENUW_SAFESEARCH" | grep "Uninstall" )" ];then
                                    [ -n "$(echo "$menu1" | grep -E "9.*\?")" ] && menu1="safesearch ?" || menu1="safesearch disable"
                                  else
                                    [ -n "$(echo "$menu1" | grep -E "9.*\?")" ] && menu1="safesearch ?" || menu1="safesearch"
                                  fi
                    ;;
                    u|uf*) ;;                           # v3.14
                    "?") ;;
                    v|vx|vh|vb) ;;                      # v3.22 v3.06 v3.04
                    l|lo|lx) ;;                         # v3 .12
                    debug) ;;                           # v3.04
                    rl) ;;                              # v3.04
                    rs) ;;                              # v3.23
                    "") ;;
                    easy|adv*) ;;
                    e*) ;;
                    *) printf '\n\a\t%bInvalid Option%b "%s"%b Please enter a valid option\n' "$cBRED" "$cRESET" "$menu1" "$cBRED"
                       continue
                       ;;
                esac
            fi

            [ -n "$DEBUGMODE" ] && set -x                 # v3.10

            menu1=$(printf "%s" "$menu1" | sed 's/^[ \t]*//;s/[ \t]*$//')       # v3.23 Old-skool strip leading/trailing spaces

            case "$menu1" in
                0|splash)                                           # v2.12
                    HDR="ForceDisplay"                                            # v1.09
                ;;
                ipset*)
                    # Extract IPSETs from dnsmasq
                    local IPSET_LIST="$(awk -F'/' '/^ipset=/ {print $NF}' /etc/dnsmasq.conf | sort | uniq | tr '\n' ' ')"
                    echo -e "ipset:" > /opt/share/unbound/configs/unbound.conf.ipset
                    for IPSET in $IPSET_LIST
                        do
                           echo -e "name-v4:   \""$IPSET"\"" >> /opt/share/unbound/configs/unbound.conf.ipset
                        done
                ;;
                1|2|2*|i|iu|"i?"|i*)

                    USE_GITHUB_DEV="N"                                  # v2.06
                    if [ -n "$(echo "$menu1" | grep -o "dev")" ];then   # v2.06
                        USE_GITHUB_DEV="Y"                              # v2.06 Use Github 'dev' branch rather than 'master'
                        menu1="$(echo "$menu1" | sed 's/dev//g')"
                    fi

                    if [ -n "$(echo "$menu1" | grep -o "config")" ]  || \
                       [ -n "$(echo "$menu1" | grep -o "example")" ] || \
                       [ -n "$(echo "$menu1" | grep -o "s61unbound")" ];then   # v3.06
                        if [ -n "$(echo "$menu1" | grep -o "config")" ];then
                            echo -e $cBCYA"Retrieving Custom unbound configuration"$cBGRA
                            if [ "$USE_GITHUB_DEV" != "Y" ];then
                               download_file $CONFIG_DIR unbound.conf martineau  # v3.05
                            else
                               download_file $CONFIG_DIR unbound.conf martineau dev # v3.05
                            fi
                            Edit_config_options "verbosity"       "uncomment"     # v3.09
                            sed -i "/^verbosity:/ s/[^ ]*[^ ]/0/2" ${CONFIG_DIR}unbound.conf   # v3.09
                            local TAG="Date Loaded by unbound_manager "$(date)")"
                            sed -i "1s/Date.*Loaded.*$/$TAG/" ${CONFIG_DIR}unbound.conf
                            # Reapply local customisation 'include: unbound.conf.addgui'/'unbound.conf.add'
                            Check_config_add_and_postconf                                               # v3.07
                            Restart_unbound
                        elif [ -n "$(echo "$menu1" | grep -o "example")" ];then
                             echo -e $cBCYA"Retrieving Example unbound configuration"$cBGRA
                             if [ "$USE_GITHUB_DEV" != "Y" ];then
                                download_file /opt/share/unbound/configs doc/example.conf.in nlnetlabs      # v3.06
                             else
                                download_file /opt/share/unbound/configs doc/example.conf.in nlnetlabs  dev # v3.06
                             fi
                        elif [ -n "$(echo "$menu1" | grep -o "s61unbound")" ];then
                               echo
                              [ "$USE_GITHUB_DEV" != "Y" ] && S61unbound_update || S61unbound_update dev # v3.10
                        fi
                    else

                        KEEPACTIVECONFIG="N"                                # v1.27
                        if [ -n "$(echo "$menu1" | grep -o "keepconfig")" ];then    # v1.27
                            KEEPACTIVECONFIG="Y"                            # v1.27 Explicitly keep current 'unbound.conf'
                            menu1="$(echo "$menu1" | sed 's/keepconfig//g')"
                        fi

                        if [ "$menu1" == "i?" ];then
                            USER_OPTION_PROMPTS="?"
                            CURRENT_AUTO_OPTIONS=
                            KEEPACTIVECONFIG="N"                            # v1.20 Force Selectable User option prompts
                        fi
                        [ "$menu1" == "1" ] && menu1="1 none"           # v1.21 EASYMENU unbound ONLY install (NO options)
                        [ "$menu1" == "2?" ] && USER_OPTION_PROMPTS="?" # v1.21 Force Selectable User option prompts
                        #[ "$menu1" == "2" ] && menu1="2 all"           # v1.21 EASYMENU Force Auto Reply to Selectable User option prompts
                        [ "$menu1" == "2" ] && menu1="2 1 4"            # v2.07 EASYMENU ONLY Auto Reply to options 1 & 4 (logging and Tweaks)

                        case "$(echo "$menu1" | awk '{print $2}' )" in
                            all)
                                menu1="i"
                                I=1
                                while [ $I -le $MAX_OPTIONS ];do
                                    menu1=$menu1" "$I                   # v1.20 Auto Reply to all Selectable User options
                                    I=$((I + 1))
                                done
                                ;;
                            none)
                                USER_OPTION_PROMPTS="N"                 # v1.21 Only install unbound - no Optional features
                                menu1="i"
                                ;;
                            keepconfig)
                                KEEPACTIVECONFIG="Y"                    # v1.27 Explicitly keep current 'unbound.conf'
                                ;;
                        esac

                        local PREINSTALLCONFIG=
                        if [ -f ${CONFIG_DIR}unbound.conf ];then
                            local PREINSTALLCONFIG="$(Backup_unbound_config)"   # v1.27 Preserve any custom config.conf
                        fi

                        [ -n "$(pidof unbound)" ] && Manage_cache_stats "save"      # v2.12 v2.11

                        install_unbound $menu1

                        # Was the Install/Update successful or CANCELled
                        if [ $? -eq 0 ];then                            # v2.06 0-Successful;1-CANCELled

                            Manage_cache_stats "restore"                # v2.11

                            if [ "$KEEPACTIVECONFIG" != "Y" ];then      # v1.27

                                if [ -n "$PREINSTALLCONFIG" ] && [ -f "/opt/share/unbound/configs/"$PREINSTALLCONFIG ] ;then

                                    # If either of the two customising files exist then no point in prompting the restore
                                    if [ ! -f /opt/share/unbound/configs/unbound.conf.add ] && [ ! -f /opt/share/unbound/configs/unbound.postconf ];then      # V2.12 Hotfix v2.10
                                            if [ "$EASYMENU" != "Y" ];then
                                                echo -e "\a\nDo you want to KEEP your current unbound configuration? ${cRESET}('${cBMAG}${PREINSTALLCONFIG}${cRESET}')\n\n\tReply$cBRED 'y'$cRESET to ${cBRED}KEEP ${cRESET}or press ${cBGRE}[Enter] to use new downloaded 'unbound.conf'$cRESET"
                                                read -r "ANS"
                                                if [ "$ANS" == "y"  ];then                      # v1.27
                                                    cp "/opt/share/unbound/configs/$PREINSTALLCONFIG" ${CONFIG_DIR}unbound.conf # Restore previous config
                                                    local TAG="Date Loaded by unbound_manager "$(date)")"
                                                    sed -i "1s/Date.*Loaded.*$/$TAG/" ${CONFIG_DIR}unbound.conf
                                                    echo -en $cBCYA"\nReloading 'unbound.conf'$TXT status="$cRESET
                                                    $UNBOUNCTRLCMD reload

                                                fi
                                            fi
                                    fi
                                    rm "/opt/share/unbound/configs/$PREINSTALLCONFIG"       # v2.06 Always delete the temp backup 'unbound.conf'
                                fi
                            fi
                        fi
                    fi
                    local TXT=
                    unset $TXT
                    #break
                ;;
                3)
                    ADVANCED_TOOLS="Y"                                  # v1.21
                    menu1=""
                    #echo -e ${cRESET}$cWGRE"\n"$cRESET 2>&1        # Separator line
                    ;;
                lookup*)                                                    # v2.11
                    if [ "$(echo "$menu1" | wc -w)" -eq 2 ];then
                        TESTTHIS="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                        echo -e $cBGRA
                        unbound_Control "lookup" "$TESTTHIS"
                    else
                        echo -e $cBRED"\a\n\t***ERROR Please specify valid domain for 'lookup'"
                    fi
                ;;
                z)
                    local UNINSTALL_TYPE="full"                         # v2.09 Force deletion of scribe logs for uiscribe
                    #[ "$menu1" == "zl" ] && UNINSTALL_TYPE="full"
                    validate_removal "$UNINSTALL_TYPE"                  # v2.09
                    [ $? -eq 1 ] && { exit_message; exit 0; } || echo -en $cRESET"\nunbound uninstall CANCELled\n"$cRESET           # v2.05 v2.00
                    #break
                ;;
                v|vx|vh|vhb|vb|vb" "*)                                     # v3.23 @mister v3.06
                    case $menu1 in
                        v|vh) ACCESS="--view"                           # v1.11 View/Readonly
                              [ ! -d /opt/share/unbound/configs/doc ] && mkdir /opt/share/unbound/configs/doc     # v3.06
                              if [ "$menu1" == "vh" ] && [ ! -f /opt/share/unbound/configs/doc/example.conf.in ];then   # v3.06
                                 download_file /opt/share/unbound/configs doc/example.conf.in nlnetlabs
                              fi
                        ;;
                        vx) ACCESS="--unix"                             # Edit in Unix format
                            local PRE_MD5="$(md5sum ${CONFIG_DIR}unbound.conf | awk '{print $1}')"              # v3.05
                        ;;
                        vb|vb" "*)                                         # v3.23 @mister
                                if [ "$(echo "$menu1" | wc -w)" -eq 2 ];then    # v3.23
                                    ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"  # v3.23
                                fi
                                if [ "$ARG" == "?" ];then # v3.23
                                    echo -e $cRESET"\n\t${cBMAG}'unbound.conf'$cBGRE Configuration backups\n"$cRESET    # v3.23
                                    ls -lahecr /opt/share/unbound/configs/*.conf | sed 's/^.*root//'            # v3.23
                                else
                                    echo -e "\n"$(Backup_unbound_config "msg" $ARG)  # v3.23 v1.27
                                fi
                                continue
                        ;;
                    esac

                    [ "$menu1" != "vh" ] && nano $ACCESS ${CONFIG_DIR}unbound.conf || nano $ACCESS /opt/share/unbound/configs/doc/example.conf.in  # v2.05

                    # Has the user edited 'unbound.conf'.....
                    if [ "$ACCESS" == "--unix" ];then                                             # v3.05
                       local POST_MD5="$(md5sum ${CONFIG_DIR}unbound.conf | awk '{print $1}')"    # v3.05
                       if [ "$PRE_MD5" != "$POST_MD5" ];then
                          echo -e "\nDo you want to restart unbound to apply your config changes?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
                          read -r "ANS"
                          [ "$ANS" == "y" ] && Restart_unbound                                     # v3.05
                       fi
                    fi
                    #break
                ;;
                ea|eb|ec|eca|ecb|el|el*)
                    # v 2.17 v2.15 Add ability to modify @juched's Ad Block configuration
                    #if [ "$(Get_unbound_config_option "adblock/adservers" ${CONFIG_DIR}unbound.conf)" != "?" ];then
                        local ACCESS="--unix"                             # Edit in Unix format

                        case $menu1 in
                            ea) local FN="/opt/share/unbound/configs/allowhost"     # v2.15 Allowlist
                            ;;
                            eb) local FN="/opt/share/unbound/configs/blockhost"     # v2.15 Blocklist
                            ;;
                            ec*) local FN="/opt/share/unbound/configs/sites"        # v2.17 v2.15 Config
                                if [ -f ${CONFIG_DIR}adblock/gen_adblock.sh ] && [ -n "$(grep blocksites ${CONFIG_DIR}adblock/gen_adblock.sh)" ];then
                                    case $menu1 in
                                        eca)
                                            local FN="/opt/share/unbound/configs/allowsites"
                                        ;;
                                        ecb)
                                            local FN="/opt/share/unbound/configs/blocksites"
                                        ;;
                                    esac
                                fi
                            ;;
                            el|el*)
                                if [ "$(echo "$menu1" | wc -w)" -gt 1 ];then
                                    local FN=$(echo "$menu1" | awk '{print $2}')
                                else
                                    echo -en $cRED"\a\n\tAd Block file to be edited not specified"$cRESET   # v3.23 Fix @francovilar
                                    local FN=
                                fi
                            ;;
                        esac

                        if [ -f "$FN" ];then
                            local PRE_MD5="$(md5sum "$FN" | awk '{print $1}')"
                            nano $ACCESS $FN
                            local POST_MD5="$(md5sum "$FN" | awk '{print $1}')"
                            if [ "$PRE_MD5" != "$POST_MD5" ];then
                                echo -e $cCYA"\n\tAd Block file '$FN' changed....updating Ad Block\n"$cRESET
                                sh ${CONFIG_DIR}adblock/gen_adblock.sh
                            else
                                echo -e $cCYA"\n\tAd Block file '$FN' NOT changed....Ad Block update skipped"$cRESET
                            fi
                        else
                            echo -e $cBRED"\a\n\tAd Block file '$FN' NOT found?"$cRESET
                        fi
                    #else
                        #echo -e $cBRED"\a\nAd Block option NOT enabled?\n"$cRESET
                    #fi
                    #break
                ;;
                rl|rl*)
                    # 'reset' and 'user' are Recovery aliases
                    #       i.e. 'reset' is Github's config, and 'user' is the customised install version
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then         # v3.17

                        NEW_CONFIG=$(echo "$menu1" | awk '{print $2}')
                        if [ "$NEW_CONFIG" != "?" ];then                # v1.22
                            local PERFORMRELOAD="Y"
                            [ -z "$(echo "$NEW_CONFIG" | grep -E "\.conf$")" ] && NEW_CONFIG=$NEW_CONFIG".conf"
                            [ "${NEW_CONFIG:0:1}" != "/" ] && NEW_CONFIG="/opt/share/unbound/configs/"$NEW_CONFIG    # v1.19
                            local TXT=
                            if [ -f $NEW_CONFIG ];then
                                if [ "$(Valid_unbound_config_Syntax "$NEW_CONFIG")" == "Y" ];then # v2.03
                                    echo -e $cBGRE
                                    unbound-checkconf $NEW_CONFIG               # v2.03
                                    cp $NEW_CONFIG ${CONFIG_DIR}unbound.conf
                                else
                                    echo -e $cBRED"\a"
                                    unbound-checkconf $NEW_CONFIG               # v2.03
                                    local PERFORMRELOAD="N"
                                    echo -e $cBRED"\n***ERROR ${cRESET}requested config $cBMAG'$NEW_CONFIG'$cRESET NOT loaded"$cBGRE
                                fi
                                #local TXT=" <<== $NEW_CONFIG"
                            else
                                echo -e $cBRED"\a\nConfiguration file '$NEW_CONFIG' NOT found?\n"$cRESET
                                local PERFORMRELOAD="N"
                            fi
                        else
                            # List available .conf files
                            echo -e $cRESET"\n\t${cBMAG}'unbound.conf'$cBGRE Configuration backups\n"$cRESET    # v3.23
                            ls -lahecr /opt/share/unbound/configs/*.conf | sed 's/^.*root//'            # v3.23
                            echo -en $cRESET
                        fi
                    else
                        local PERFORMRELOAD="Y"                                 # v3.17
                    fi

                    if [ "$PERFORMRELOAD" == "Y" ];then                         # v1.19
                        local TAG="Date Loaded by unbound_manager "$(date)")"
                        sed -i "1s/Date.*Loaded.*$/$TAG/" ${CONFIG_DIR}unbound.conf
                        if [ -n "$(pidof unbound)" ];then                      # v3.00
                            echo -en $cBCYA"\nReloading 'unbound.conf'$TXT status="$cRESET
                            Manage_cache_stats "save"                           # v2.12
                            $UNBOUNCTRLCMD reload
                            local STATUS=$($UNBOUNCTRLCMD status)
                            [ -z "$(echo "$STATUS" | grep "error")" ] && Manage_cache_stats "restore" || Restart_unbound   # v3.17 v2.12
                        else
                            local FN="/opt/share/unbound/configs/unbound.conf.add"  # v3.00
                            if [ -n "$(echo "$NEW_CONFIG" | grep "reset")" ] && [ -f $FN ];then
                                echo -en $cRESET"\nReset requested..disabling $cBGRE'unbound.conf.add'$cRESET - renamed $cBGRE'${FN}RESET'"$cRESET
                                mv $FN $FN"RESET"                               # v3.00 Always disable 'unbound.conf.add'
                            fi
                            Restart_unbound                                     # v3.00
                        fi
                        CHECK_GITHUB=1                                          # v1.27 force a GitHub version check to see if we are OK
                    fi
                    local TXT=
                    unset $TXT
                    #break
                ;;
                logtrace*)                                                      # v2.09
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        TESTTHIS="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                        # Turn on logging; perform the lookup;then turn off logging!

                    else
                        echo -e $cBRED"\a\n\t***ERROR Please specify valid domain for logtrace"
                    fi
                ;;
                localhost*)                                                                 # v3.23 { domain_name {IP_address | 'del'} }
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2)"
                    fi
                    if [ "$(echo "$menu1" | wc -w)" -ge 3 ];then
                        local ARG2="$(printf "%s" "$menu1" | cut -d' ' -f3)"
                    fi

                    if [ "$(Unbound_Installed)" == "Y" ];then

                        [ ! -f /opt/share/unbound/configs/unbound.conf.localhosts ] && true > /opt/share/unbound/configs/unbound.conf.localhosts
                        if [ -n "$ARG" ] && [ "$ARG" != "del" ];then
                            if [ -z "$(echo $menu1 | grep -wo "del")" ];then
                                if [ -n "$(echo "$ARG2" | Is_IPv4)" ];then
                                    local RTYPE="A"
                                    echo -en $cBCYA"\nAdding localhost '$ARG' -> '$ARG2'"$cRESET
                                    echo -e "local-zone: \""${ARG}".\" static\nlocal-data: \"${ARG}. IN $RTYPE $ARG2\"" >> /opt/share/unbound/configs/unbound.conf.localhosts
                                    sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /opt/share/unbound/configs/unbound.conf.localhosts
                                    RC=0
                                else
                                    echo -e $cBRED"\a\n\t'$ARG2' is NOT a valid IP address!"$cRESET
                                    local RC=1
                                fi
                            else
                                echo -en $cBCYA"\nDeleting localhost '$ARG $ARG2'"$cRESET
                                sed -i "/$ARG\./d" /opt/share/unbound/configs/unbound.conf.localhosts
                                sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /opt/share/unbound/configs/unbound.conf.localhosts
                                RC=0
                            fi
                        else
                            echo -e $cBRED"\a\n\tMissing 'domain/IP' for 'del' request!"$cRESET
                            local RC=1
                        fi
                    else
                        echo -e $cBRED"\a\n\tunbound NOT installed!"$cRESET
                        local RC=1
                    fi
                    [ $RC -eq 0 ] && Restart_unbound
                ;;
                l|lx|ln*|lo*)                                                    # v1.16

                    [ "$(Unbound_Installed)" == "N" ] && { echo -e $cBRED"\a\n\tunbound NOT installed! - option unavailable"$cRESET; continue; }

                    local TXT=
                    # Get LOGFILE location from 'unbound.conf' or via 'unbound-control' if dynamically assigned
                    # logfile: "/opt/var/lib/unbound/unbound.log" or "unbound.log"
                    local LOGFILE="$(Get_unbound_config_option "logfile:"  | tr -d '"')"          # v2.00 v1.25

                    if  [ "$LOGFILE" == "?" ] || [ -z "$LOGFILE" ];then
                        local LOGFILE="$($UNBOUNCTRLCMD get_option log-replies)"    # v2.00
                    fi

                    if [ -n "$LOGFILE" ];then
                        [ "${LOGFILE:0:1}" != "/" ] && LOGFILE=${CONFIG_DIR}$LOGFILE        # v1.26 Ensure full pathname
                    fi

                    case $menu1 in

                        lo*)                                                            # v3.08 [ log_level ]v1.16

                            local LOGLEVEL=1                                           # v3.08
                            local TXT=
                            if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                               local LOGLEVEL="$(printf "%s" "$menu1" | cut -d' ' -f2)" # v3.08
                            fi

                            if [ -n "$(echo $LOGLEVEL | grep -E "^[1-5]$")" ];then      # v3.09
                                local TXT="(Loglevel="$LOGLEVEL")"
                                $UNBOUNCTRLCMD -q set_option log-queries: yes
                                Edit_config_options "log-queries:"    "uncomment"     # v3.06
                                $UNBOUNCTRLCMD -q set_option log-replies: yes
                                Edit_config_options "log-replies:"    "uncomment"     # v3.06
                                $UNBOUNCTRLCMD -q set_option log-time-ascii: yes
                                echo -e $(date "+%b %d %T") "unbound_manager: 'lo':  =================================================================================== Started Loglevel="$LOGLEVEL >> $LOGFILE   # v3.06
                                $UNBOUNCTRLCMD -q verbosity $LOGLEVEL                         # v3.08 v3.06 v2.05
                                $UNBOUNCTRLCMD -q set_option verbosity $LOGLEVEL
                                Edit_config_options "verbosity"       "uncomment"     # v3.06
                                sed -i "/^verbosity:/ s/[^ ]*[^ ]/$LOGLEVEL/2" ${CONFIG_DIR}unbound.conf   # v3.08
                                echo -e $cBCYA"\nunbound logging $TXT ENABLED"$cRESET
                                #[ $LOGLEVEL -gt 1 ] && Restart_unbound
                                echo -e $cBMAG"\a\n${LOGFILE} $TXT\t\t${cBGRE}Press CTRL-C to stop\n"$cRESET
                                trap 'welcome_message' INT
                                tail $NUM -F $LOGFILE
                                # Cron job 00:01 daily to check'n'delete log file when it is >10MB
                                cru d unboundLOG 2>/dev/null                        # v3.06
                                cru a unboundLOG "1 0 * * * /opt/bin/find ${CONFIG_DIR}unbound.log -size +10M -exec rm -f {} \;"   # v3.06
                            else
                                echo -e $cBRED"\a\n\t***ERROR Invalid arg 'log level' - must be in range 1-5"
                            fi
                            ;;
                        lx)                                                     # v1.16
                            $UNBOUNCTRLCMD -q verbosity 0                     # v3.08 v3.06 v2.05
                            $UNBOUNCTRLCMD -q set_option verbosity 0
                            Edit_config_options "verbosity"       "uncomment"   # v3.08 v3.06
                            sed -i "/^verbosity:/ s/[^ ]*[^ ]/0/2" ${CONFIG_DIR}unbound.conf
                            $UNBOUNCTRLCMD -q set_option log-queries: no
                            Edit_config_options "log-queries:"    "comment"     # v3.06
                            $UNBOUNCTRLCMD -q set_option log-replies: no
                            Edit_config_options "log-replies:"    "comment"     # v3.06
                            echo -e $cBCYA"\nunbound logging DISABLED"$cRESET
                            echo -e $(date "+%b %d %T") "unbound_manager: 'lx':  =================================================================================== Stopped" >> $LOGFILE   # v3.06
                            cru d unboundLOG 2>/dev/null                        # v3.06
                            ;;
                        l|ln*)                                                  # v1.16
                            # syslog-ng/scribe?
                            if [ "$(Get_unbound_config_option "use-syslog:")" == "yes" ];then   # v3.06 v2.00
                                local LOGFILE="/opt/var/log/unbound.log"
                                local TXT=" (syslog-ng/scribe)"                 # v3.06 v2.00 v1.25 syslog-ng/scribe
                            fi
                            NUM=
                            [ "${menu1:0:2}" == "ln" ] && NUM="-n $(echo "$menu1" | cut -d' ' -f2)" # v1.16
                            if [ -f $LOGFILE ];then
                                echo -e $cBMAG"\a\n${LOGFILE}$TXT\t\t${cBGRE}Press CTRL-C to stop\n"$cRESET
                                trap 'welcome_message' INT
                                tail $NUM -F $LOGFILE
                            else
                                echo -e $cBRED"\a\nunbound logging '$LOGFILE' NOT ENABLED?\n"$cRESET
                            fi
                            local TXT=
                            unset $TXT
                            #break
                            ;;
                    esac
                ;;
                safesearch*)                                    # v3.22 @Somewhereovertherainbow

                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    fi

                    if [ "$(Unbound_Installed)" == "Y" ];then
                            local CONFIG_ADD="/opt/share/unbound/configs/unbound.conf.safesearch"       # v3.22
                            if [ "$menu1" != "safesearchv" ] && [ "$menu1" != "safesearchx" ];then
                                case "$ARG" in
                                    status|"?")
                                    if [ -n "$(grep -F "unbound.conf.safesearch" ${CONFIG_DIR}unbound.conf)" ];then
                                        echo -e "\n\t"${cBMAG}$(grep -c "redirect" /opt/share/unbound/configs/unbound.conf.safesearch)$cBGRE "Safe Search domain redirects e.g.\n"$cRESET
                                        for ARG in google.com youtube.com duckduckgo.com bing.com yandex.com api.qwant.com pixabay.com  # v3.22 @SomeWhereOverTheRainbow
                                            do
                                                dig $ARG | grep -iA 1 cname
                                                echo -e
                                            done
                                            echo -e $cBCYA"\tetc.\n"$cRESET
                                    else
                                        echo -e $cBRED"\n\a\tSafe Search domain redirects NOT ENABLED!"
                                    fi
                                ;;
                                    '')
                                    Configure_SafesearchDomains $ARG2
                                    Restart_unbound
                                    local RC=0
                                ;;
                                disable)
                                    if [ -n "$(grep "^include.*unbound\.conf\.safesearch" ${CONFIG_DIR}unbound.conf)" ];then
                                        echo -e $cBGRE"\nDisabling Safe Search....."$cRESET
                                        [ "$VERBOSE" == "Y" ] && echo -e $cBCYA"Removing $cBGRE'include: \"$CONFIG_ADD\" ${cBCYA}from '${CONFIG_DIR}unbound.conf'"$cBGRA
                                        local TO="$(awk '/^include.*\/opt\/share\/unbound\/configs\/unbound\.conf\.safesearch\"/ {print NR}' "${CONFIG_DIR}unbound.conf")";local FROM=$((TO - 1))
                                        [ -n "$TO" ] && sed -i "$FROM,$TO d" ${CONFIG_DIR}unbound.conf                     # v3.08 v3.07
                                        rm $CONFIG_ADD              # v3.22
                                        Restart_unbound
                                        local RC=0
                                    else
                                        echo -e $cBRED"\a\nSafesearch NOT ENABLED?\n"$cRESET
                                    fi
                                ;;
                                esac
                            else
                               local FN=$CONFIG_ADD
                               [ "$menu1" == "safesearchv" ] && local ACCESS="--view"
                               if [ "$menu1" == "safesearchx" ];then
                                  local ACCESS="--unix"
                                  [ ! -f $FN ] && touch $FN
                                  local PRE_MD5="$(md5sum $FN | awk '{print $1}')"
                               fi
                               if [ -f $FN ];then
                                    nano $ACCESS $FN
                                    if [ "$ACCESS" == "--unix" ];then
                                        local POST_MD5="$(md5sum $FN | awk '{print $1}')"
                                        if [ "$PRE_MD5" != "$POST_MD5" ];then
                                            echo -e "\nDo you want to restart unbound to apply your config changes?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
                                            read -r "ANS"
                                            [ "$ANS" == "y" ] && Restart_unbound
                                        fi
                                        [ ! -s $FN ] && rm $FN
                                    fi
                                else
                                    echo -e $cBRED"\a\n\t'$FN' does not exist!"$cRESET
                                    local RC=1
                                fi
                            fi
                    else
                         echo -e $cBRED"\a\n\tunbound NOT installed!"$cRESET
                         local RC=1
                    fi
                ;;
                scribe*)                                                     # v3.06 v1.27

                    local LOGFILE="/opt/var/logs/unbound.log"        # v3.06

                    local TXT=

                    local ARG=                                              # v3.06
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"   # v3.06
                    fi

                    if [ "$ARG" != "disable" ];then                           # v3.06
                        if [ -d /opt/etc/syslog-ng.d ];then
                            if [ ! -f /opt/etc/syslog-ng.d/unbound ];then
                                local TXT="Created scribe 'unbound' file: "
                                cat > /opt/etc/syslog-ng.d/unbound << EOF       # v2.18 Add 'gen_adblock.sh' Generate the missing unbound scribe file
# log all unbound logs to /opt/var/log/unbound.log and stop processing unbound logs

destination d_unbound {
    file("/opt/var/log/unbound.log");
};

filter f_unbound {
    program("unbound") or
    program("gen_adblock.sh");
};

log {
    source(src);
    filter(f_unbound);
    destination(d_unbound);
    flags(final);
};
#eof
EOF
                                chmod 600 /opt/etc/syslog-ng.d/unbound  >/dev/null  # v2.04
                                cat > /opt/etc/logrotate.d/unbound << EOF       # Generate the missing unbound logrotate file   #v2.04
/opt/var/log/unbound.log {
    minsize 1024K
    daily
    rotate 9
    postrotate
        /usr/bin/killall -HUP syslog-ng
    endscript
}
EOF
                                chmod 600 /opt/etc/logrotate.d/unbound  >/dev/null    # v2.04
                                /opt/bin/scribe reload 2>/dev/null 1>/dev/null        # v2.04
                                /opt/sbin/logrotate /opt/etc/logrotate.conf 2>/dev/null 1>/dev/null     # v2.04
                                Restart_unbound                                        # v2.17
                            fi

                            # Assume we have the easy option to uncomment....
                            Edit_config_options "use-syslog:"          "uncomment"     # v1.27
                            Edit_config_options "log-tag-queryreply:"  "uncomment"     # v2.05
                            Edit_config_options "verbosity"            "uncomment"     # v3.06
                            Edit_config_options "log-queries:"         "uncomment"     # v3.06
                            Edit_config_options "log-replies:"         "uncomment"     # v3.08 Hotfix
                            #cru d unboundLOG 2>/dev/null

                            echo -en $cBGRE"\n$TXT${cRESET}Enabling syslog-ng logging (scribe)....."$cRESET     # v2.17
                            local TXT=
                            unset $TXT
                            [ -f /opt/var/lib/unbound/unbound.log ] && echo -e $(date "+%b %d %T") "unbound_manager: 'scribe':  ============================================================== Started" >> /opt/var/lib/unbound/unbound.log # v3.06
                            Restart_unbound                                            # v2.17
                        fi
                    else
                        Edit_config_options "use-syslog:"          "comment"     # v3.06
                        [ -f $LOGFILE ] && echo -e $(date "+%b %d %T") "unbound_manager: 'scribe disable':  ============================================================== Stopped" >> $LOGFILE   # v3.06
                        Restart_unbound                                          # v3.06
                    fi
                ;;
                sd|dnsmasqstats)                                            # v1.18
                    [ -n "$(ps | grep -v grep | grep -F "syslog-ng")" ] && SYSLOG="/opt/var/log/messages" || SYSLOG="/tmp/syslog.log"
                    # Is scribe / Diversion running?
                    if [ -f /opt/share/diversion/.conf/diversion.conf ] && [ "$(grep -E "^DIVERSION_STATUS" /opt/share/diversion/.conf/diversion.conf)" == "DIVERSION_STATUS=enabled" ];then    # v3.11 Hotfix
                        [ -f /opt/var/log/dnsmasq.log ] && SYSLOG="/opt/var/log/dnsmasq.log"     # v1.28
                    fi
                    echo -e $cBGRA
                    # cache size 0, 0/0 cache insertions re-used unexpired cache entries.
                    # queries forwarded 4382, queries answered locally 769
                    # pool memory in use 0, max 0, allocated 0
                    # server 127.0.0.1#53535: queries sent 4375, retried or failed 29
                    # server 100.120.82.1#53: queries sent 0, retried or failed 0
                    # server 1.1.1.1#53: queries sent 7, retried or failed 0
                    # Host                                     Address                        Flags      Expires
                    kill -SIGUSR1 $(pidof dnsmasq) | sed -n '/cache entries\.$/,/Host/p' $SYSLOG | tail -n 6 | grep -F dnsmasq
                ;;
                Stubby*)                                           # v3.00
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    fi
                    if [ "$(Unbound_Installed)" == "Y" ];then
                        if [ "$ARG" != "disable" ];then
                            AUTO_REPLY2="?"
                            Option_Stubby_Integration           "$AUTO_REPLY2"
                            local RC=$?
                        else
                            Stubby_Integration "disable"        # TBA
                            local RC=1                          # TEMPORARARY TO IGNORE UNNECESSARY dnsamsq restart.
                        fi
                    else
                        echo -e $cBRED"\a\n\tunbound NOT installed!?"$cRESET
                        local RC=1
                    fi

                    if [ $RC -eq 0 ];then
                        echo -en $cBCYA"Restarting dnsmasq....."$cBGRE        # v1.13
                        service restart_dnsmasq                                # v1.13
                        echo -en $cRESET
                        Check_GUI_NVRAM
                    fi
                ;;
                "q?"|fs|oq|oq*|ox|ox*|s+|s-|sp|sa|s|sgui*|s" "*)                      # v3.23 v2.07 v1.08

                    echo
                    unbound_Control "$menu1"                                # v1.16
                    #break
                ;;
                u|uf|uf*)
                    [ "$menu1" == "uf" ] && echo -e ${cRESET}$cWRED"\nForced Update"$cRESET"\n"  # v2.06 v1.07
                    # Safeguard against cURL failure i.e. Github DOWN
                    cp $0 $0.u                                             # v3.06
                    update_installer $menu1
                    [ $? -eq 0 ] && { rm $0.u;exec "$0" "$@"; } || mv $0.u $0     # v3.06 v1.18 Only exit if new script downloaded

                ;;
                rs*)                                                        # v1.07

                    [ "$(Unbound_Installed)" == "N" ] && { echo -e $cBRED"\a\n\tunbound NOT installed! - option unavailable"$cRESET; continue; }    # v2.01

                    local NOCACHE=                                          # v2.12

                    if [ "$(echo "$menu1" | wc -w)" -gt 1 ];then            # v2.11
                        local NOCACHE=$(echo "$menu1" | awk '{print $2}')
                        [ "$NOCACHE" != "nocache" ] && { echo -e $cBRED"\a\n\tUnrecognised argument - Only $cRESET'nocache'$cBRED is valid"$cRESET; continue; }
                    fi

                    echo -e
                    Restart_unbound "$NOCACHE" "$1"                         # v2.13 v2.12

                    #break
                ;;
                x)                                                     # v2.01

                    [ "$(Unbound_Installed)" == "N" ] && { echo -e $cBRED"\a\n\tunbound NOT installed! - option unavailable"$cRESET; continue; }    # v2.01

                    echo
                    Manage_cache_stats "save"                               # v2.11
                    /opt/etc/init.d/S61unbound stop
                    echo -en $cBCYA"\nRestarting dnsmasq....."$cBGRE        # v2.09
                    service restart_dnsmasq
                    echo -en $cBCYA"\nunbound STOPPED."$cBGRE
                    SayT "unbound STOPPED"                                  # v3.08
                    #break                                                  # v3.08
                ;;
                debug)                #  v3.10 v1.07

                    [ "$(Unbound_Installed)" == "N" ] && { echo -e $cBRED"\a\n\tunbound NOT installed! - option unavailable"$cRESET; continue; }    # v2.01

                    echo -e $cBCYA"\n\t'unbound.conf'\n"$cBYEL
                    grep -E -m 1 -A 5 "^port:" ${CONFIG_DIR}unbound.conf   # v3.12

                    echo -e $cBCYA"\n\t'/etc/dnsmasq.conf'\n"$cBYEL
                    [ -n "$(grep "^servers-file" /etc/dnsmasq.conf)" ] && grep "^servers-file" /etc/dnsmasq.conf || echo -e $cBGRE"\tn/a"   # v3.12

                    echo -e $cBCYA"\n\tnetstat LISTEN Ports\n"$cBYEL
                    netstat -anp | grep LISTEN | grep -v unix | awk -v OFS='\t' '{gsub(":"," ",$4); print $0}' | sort -g -k4 -k5   # v3.11
                    [ -n "$(pidof unbound)" ] && echo -e $cBCYA"\n\tWarning ${cRESET}unbound$cBCYA is running so $cRESET'unbound -dv'$cBCYA may show sockets already in use by ${cRESET}unbound$cBYEL\n"   # v3.11
                    echo -e $cBRED
                    unbound -dd -vvvv                                                   # v3.17
                    echo -e $cRESET
                    break
                ;;
                dnsmasq*)                                                                 # v3.10 [disable | interfaces|nointerface]
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2)"
                    fi

                    if [ "$(Unbound_Installed)" == "Y" ];then
                       if [ -z "$ARG" ] || [ "$ARG" == "disable" ];then                 # v3.16
                            if [ "$ARG" == "disable" ];then
                                AUTO_REPLY11="?"
                                echo -e
                                Option_Disable_dnsmasq "$AUTO_REPLY11" "$ARG"   # unbound will be the DNS server for ALL LAN Clients
                                local RC=$?
                            else
                                case "$ARG" in
                                    "") Disable_dnsmasq                                 # Reinstate dnsmasq as the DNS reolver for ALL LAN Clients.
                                        local RC=0
                                        ;;
                                    *)
                                     echo -e $cBRED"\a\n\tUnrecognised argument - Only $cRESET'disable'$cBRED is valid"$cRESET
                                     continue
                                    ;;
                                esac
                            fi
                        else
                            if [ -f /opt/share/unbound/configs/unbound.conf.localhosts ];then     # v3.16
                                case "$ARG" in
                                    nointerfaces)
                                        echo -e $cBCYA"\n\tRemoving dnsmasq 'interfaces=' from 'unbound.conf.localhosts'"$cRESET
                                        sed -i -n '/Replicate.*interface=.*directives/q;p' /opt/share/unbound/configs/unbound.conf.localhosts
                                        sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /opt/share/unbound/configs/unbound.conf.localhosts
                                        Restart_unbound
                                        ;;
                                    interfaces)
                                        sed -i -n '/Replicate.*interface=.*directives/q;p' /opt/share/unbound/configs/unbound.conf.localhosts
                                        sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /opt/share/unbound/configs/unbound.conf.localhosts
                                        echo
                                        Convert_dnsmasq_Interfaces
                                        Restart_unbound
                                        ;;
                                esac
                            else
                                echo -e $cBRED"\a\n\t'unbound.conf.localhosts' not found! - dnsmasq bypass NOT"$cRESET
                            fi
                        fi
                    else
                        echo -e $cBRED"\a\n\tunbound NOT installed!"$cRESET
                        local RC=1
                    fi
                ;;
                about|"?")                     # v1.17
                    echo -e $cBGRE"\n\tVersion="${VERSION}$cBCYA"\t\t\t\t\t"$CHANGELOG   # v3.15
                    echo -e $cBMAG"\tLocal\t\t\\t\t\t\tmd5="$localmd5       # v2.00
                    echo -e $cBMAG"\tGithub\t\t\t\t\t\tmd5="$remotemd5      # v2.00
                    echo -e $cBMAG"\t/jffs/addons/unbound/unbound_manager.md5\tmd5="$(cat /jffs/addons/unbound/unbound_manager.md5)


                    Check_GUI_NVRAM

                    if [ "$(Unbound_Installed)" == "Y" ];then  # v2.01
                        echo -e $cBCYA"\n\tunbound Memory/Cache:\n"                         # v2.00
                        local CACHESIZE="$($UNBOUNCTRLCMD get_option key-cache-size)";echo -e $cRESET"\t'key-cache-size:'\t$cBMAG"$CACHESIZE" ("$(echo $(Size_Human "$CACHESIZE"))")"

                        local CACHESIZE="$($UNBOUNCTRLCMD get_option msg-cache-size)"
                        local USED_CACHE=$($UNBOUNCTRLCMD stats_noreset | awk 'BEGIN {FS="[= ]"} /mem.cache.message=/ {print $2}') # v3.07
                        local PCT="$(Calculate_Percent "$CACHESIZE" "$USED_CACHE")"
                        echo -e $cRESET"\t'msg-cache-size:'\t$cBMAG"$CACHESIZE" ("$(echo $(Size_Human "$CACHESIZE"))")\t${cBGRE}$PCT% used$cRESET $USED_CACHE\t($(echo $(Size_Human "$USED_CACHE")))" # v3.07

                        local CACHESIZE="$($UNBOUNCTRLCMD get_option rrset-cache-size)"
                        local USED_CACHE=$($UNBOUNCTRLCMD stats_noreset | awk 'BEGIN {FS="[= ]"} /mem.cache.rrset=/ {print $2}') # v3.07
                        local PCT="$(Calculate_Percent "$CACHESIZE" "$USED_CACHE")"
                        echo -e $cRESET"\t'rrset-cache-size:'\t$cBMAG"$CACHESIZE" ("$(echo $(Size_Human "$CACHESIZE"))")\t${cBGRE}$PCT% used$cRESET $USED_CACHE\t($(echo $(Size_Human "$USED_CACHE")))" # v3.07
                    else
                        echo -e $cBCYA"\n\tunbound Memory/Cache:\n\n\t\t${cBMAG}n/a"        # v2.00
                    fi

                    echo -e $cBCYA"\n\tSystem Memory/Cache:\n"
                    SYSTEMRAM="$(free -m | sed 's/^[ \t]*//;s/[ \t]*$//')"
                    SYSTEMRAM=$(echo "$SYSTEMRAM" | sed 's/Mem:/\\tMem:/' | sed 's/\-/\\t\-/' | sed "s/Swap:/\\tSwap:/")

                    echo -e $cRESET"\t             $SYSTEMRAM"
                    # No of processors/threads
                    #$UNBOUNCTRLCMD get_option thread

                    echo -e $cBCYA"\n\tAbout ${cRESET}unbound: ${cBYEL}https://nlnetlabs.nl/projects/unbound/about/ , ${cBCYA}Manual$cBYEL https://nlnetlabs.nl/documentation/unbound/unbound.conf/${cRESET}"
                    #echo -e $cBCYA"\n\tSNB Forums ${cRESET}unbound ${cBCYA}support: ${cBYEL}https://www.snbforums.com/threads/unbound-authoritative-recursive-caching-dns-server.58967/ ${cRESET}"

                ;;
                adblock*)                                           # v3.20 v3.10 v2.18   [ youtube | track | update | uninstall | country[3] ]
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    fi

                    # List 2-char/3-char domains possible country codes defined in '/opt/share/unbound/configs/blockhost'       # v3.20
                    if [ "$ARG" == "country" ] || [ "$ARG" == "country3" ];then                 # v3.20
                        echo -e $cBWHT"\n\tBlocked country domain"$cBCYA
                        case "$ARG" in
                            country3)   grep -E "local\-zone: \".{2,3}\"" /opt/var/lib/unbound/adblock/adservers | sort;;   # e.g. "fit" or "icw"
                            country)    grep -E "local\-zone: \"..\""     /opt/var/lib/unbound/adblock/adservers | sort;;   # e.g. "cn" or "ru"
                        esac
                    else
                        if [ "$(Unbound_Installed)" == "Y" ];then
                            if [ "$ARG" != "uninstall" ];then
                                AUTO_REPLY3="y"
                                echo
                                [ "$ARG" != "update" ] && Option_Ad_Tracker_Blocker "$AUTO_REPLY3" "$ARG" ||  Ad_Tracker_blocking "update"    # v3.10 v2.18 Hotfix
                                local RC=$?
                            else
                                Ad_Tracker_blocking "uninstall"
                                local RC=0
                            fi
                        else
                            echo -e $cBRED"\a\n\tunbound NOT installed! or Ad Block /adservers NOT defined in 'unbound.conf'?"$cRESET
                            local RC=1
                        fi
                    fi
                ;;
                youtube*)                                           # v3.11   [ update | uninstall ]
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    fi

                    if [ "$ARG" == "view" ] || [ "$ARG" == "edit" ];then                          # v3.12
                        [ "$ARG" != "edit" ] && local ACCESS="--view" || local ACCESS="--unix"    # v3.12
                        nano $ACCESS /opt/var/lib/unbound/adblock/ytadblock                        # v3.12
                    else
                        if [ "$(Unbound_Installed)" == "Y" ];then                                  # v3.12
                            if [ "$ARG" != "uninstall" ];then
                                if [ "$ARG" != "newip" ];then                                     # v3.13
                                    AUTO_REPLY12="?"
                                    echo
                                    if [ "$ARG" != "update" ];then
                                        Option_YouTube_Adblock "$AUTO_REPLY12" "$ARG"
                                        local RC=$?
                                    else
                                        if [ -f /opt/var/lib/unbound/adblock/gen_ytadblock.sh ];then    # v3.23
                                            YouTube_Adblock "update"    # v3.11
                                        else
                                            echo -e $cBRED"\a\n\tYouTube Adblock NOT installed!?"$cRESET        # v3.23
                                            local RC=1
                                        fi
                                    fi
                                else
                                    if [ -f /opt/var/lib/unbound/adblock/gen_ytadblock.sh ];then    # v3.23
                                        ${CONFIG_DIR}/adblock/gen_ytadblock.sh "force_newip"           # v3.13
                                    else
                                        echo -e $cBRED"\a\n\tYouTube Adblock NOT installed!?"$cRESET        # v3.23
                                        local RC=1
                                    fi
                                fi
                            else
                                YouTube_Adblock "uninstall"
                                local RC=0
                            fi
                        else
                            echo -e $cBRED"\a\n\tunbound NOT installed!?"$cRESET
                            local RC=1
                        fi
                    fi
                ;;
                easy|adv*)                                          # v2.07
                    # v2.07 When unbound_manager invoked from amtm, 'easy' mode is the default.
                    #       Allow user to save their preferred mode e.g. 'advanced' as the default across amtm sessions
                    # @kernol finds it too taxing to type in 8-chars, so add 'adv' as a 3-char alternative
                    #       https://github.com/RMerl/asuswrt-merlin/wiki/Addons-API#custom-settings
                    case "$menu1" in                                        # v2.07
                        easy)
                            EASYMENU="Y"
                            [ $FIRMWARE  -ge 38415 ] && am_settings_set unbound_mode "Easy"      # v2.07 Save mode across amtm sessions
                            echo -en $cRESET"\nEasy Menu mode ${cBGRE}ENABLED"$cRESET
                        ;;
                        adv*)
                            local ARG
                            if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                                local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"

                                if [ "$(nvram get et0macaddr | tr -d ':\n' | tail -c 4)" == "$ARG" ];then
                                    EASYMENU="N"
                                    [ $FIRMWARE  -ge 38415 ] && am_settings_set unbound_mode "Advanced"  # v2.07 Save mode across amtm sessions
                                    echo -en $cRESET"\nAdvanced Menu mode ${cBGRE}ENABLED"$cRESET
                                    MENU_Z=
                                    touch ${CONFIG_DIR}Read.me
                                fi
                            else
                                printf '\n\a\t%bInvalid Option%b "%s"%b Please enter a valid option\n' "$cBRED" "$cRESET" "$menu1" "$cBRED"
                            fi
                        ;;
                    esac

                    echo -e $cBGRA
                    ;;
                e|exit)                                         # v3.23
                    [ -n "$(echo "$menu1" | grep -E "e.*\?")" ] && exit_message "0" || exit_message
                    break

                ;;
                ad|ad*)

                    # ad [ 'all' | file_name ] [ 'type=adblock' ] [ 'action=merge' ]

                    local FN="all"
                    local ACTION="Analyz"       # Merg
                    #echo -e $cBCYA"\n${ACTION}ing, please be patient.....may take 30 seconds"

                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local FN=$(echo "$menu1" | awk '{print $2}')
                        [ "${FN:0:5}" = "type=" ] && { local TYPE=$(echo "$menu1" | awk '{print $2}'); local FN="all"; }

                        [ "$(echo "$menu1" | wc -w)" -gt 2 ] && local TYPE=$(echo "$menu1" | awk '{print $3}')
                        Diversion_to_unbound_list "$FN" "$TYPE"             # v1.25
                    else
                        Diversion_to_unbound_list "all"                     # v1.25
                    fi
                ;;
                vpn*)                                                       # v3.00  [ vpn_id [ debug ] | [ debug show ] | disable ]
                    # Allow using a nominated VPN tunnel to send DNS Root Server requests
                    local ARG2=                                                 # v2.16
                    if [ "$(echo "$menu1" | wc -w)" -ge 3 ];then                # v2.16
                        local ARG2="$(printf "%s" "$menu1" | cut -d' ' -f3)"
                    fi
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2)"
                    fi

                    if [ "$(Unbound_Installed)" == "Y" ];then
                        if [ "$ARG" != "disable" ];then
                            if [ "$ARG" == "debug" ] && [ "$ARG2" == "show" ];then  # v3.05
                                local WANIP=$(nvram get wan0_ipaddr)                # v3.05
                                grep -v -F "[BLOCKED" /tmp/syslog.log | grep -o "^.*DPT=53"  | sed -r 's/LEN.*PROTO=//' | sed -r 's/LEN.*PROTO=//' | sed -r "s/$WANIP/wan.isp.ip.addr/"  # v3.07 v3.05
                                local RC=1
                            else
                                if [ -n "$( echo "$ARG" | grep -E "^[1-5]$")" ];then        # v3.20
                                    AUTO_REPLY9="?"                                     # v3.05
                                    echo
                                    Option_Use_VPN_Tunnel "$AUTO_REPLY9" "$ARG" "$ARG2"
                                    local RC=$?
                                else
                                    echo -e $cBRED"\a\n\tVPN Client arg '$ARG' invalid, must be in range 1-5"$cRESET    # v3.20
                                    local RC=1
                                fi

                            fi
                        else
                            Use_VPN_Tunnel "disable"
                            local RC=0
                        fi
                        [ $RC -eq 0 ] && Restart_unbound
                    else
                        echo -e $cBRED"\a\n\tunbound NOT installed! or 'outgoing-interface:' NOT defined in 'unbound.conf'?"$cRESET
                        local RC=1
                    fi
                ;;
                bind*)                                                       # v3.06  [ any | disable ]
                    # Allow overriding default ANY interface to bind to WAN ONLY to send DNS Root Server requests
                    local ARG2=                                              # v3.07
                    if [ "$(echo "$menu1" | wc -w)" -ge 3 ];then
                        local ARG2="$(printf "%s" "$menu1" | cut -d' ' -f3)"
                    fi
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2)"
                    fi

                    if [ "$(Unbound_Installed)" == "Y" ];then
                        if [ "$ARG" != "any" ] && [ "$ARG" != "disable" ];then      # v3.07
                            if [ "$ARG" == "debug" ] && [ "$ARG2" == "show" ];then  # v3.07
                                local WANIP=$(nvram get wan0_ipaddr)                # v3.07
                                grep -v -F "[BLOCKED" /tmp/syslog.log | grep -o "^.*DPT=53"  | sed -r 's/LEN.*PROTO=//' | sed -r 's/LEN.*PROTO=//' | sed -r "s/$WANIP/wan.isp.ip.addr/"  # v3.07
                                local RC=1
                            else
                                AUTO_REPLY9="?"
                                echo
                                Option_BIND_WAN "$AUTO_REPLY9" "$ARG" "$ARG2"
                                local RC=$?
                            fi
                        else
                            BIND_WAN "any"
                            local RC=0
                        fi
                        [ $RC -eq 0 ] && Restart_unbound
                    else
                        echo -e $cBRED"\a\n\tunbound NOT installed! or 'outgoing-interface:' NOT defined in 'unbound.conf'?"$cRESET
                        local RC=1
                    fi
                ;;
                DisableFirefoxDoH*)                                                 # v3.16 {yes | no}
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2)"
                    fi
                    if [ "$ARG" == "yes" ] || [ "$ARG" == "no" ];then
                        echo
                        [ ${ARG:0:3} == "yes" ] &&  Disable_Firefox_DoH || Disable_Firefox_DoH "no"   # v3.16
                    else
                       echo -e $cBRED"\a\n\tUnrecognised argument - Only $cRESET'yes' or 'no'$cBRED is valid"$cRESET
                    fi
                ;;
                getrootdns)                                                 # v1.24
                    echo
                    Get_RootDNS
                ;;
                '')                                                         # v1.17
                    [ -n "$ADVANCED_TOOLS" ] && ADVANCED_TOOLS=             # v1.21
                ;;
                ca|ca*)                                                     # v3.10 [ min | calc ] v1.26
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2)"
                    fi
                    # optional 'reset'   will reset to calculated sizes
                    #          'default' will use '4m,4m,4m'
                    #          otherwise will use '8m,8m.16m'
                    echo
                    #[ "$(echo "$menu1" | awk '{print $2}')" == "reset" ] && Optimise_CacheSize "reset" || Optimise_CacheSize
                    Optimise_CacheSize "$ARG"
                ;;
                test|test*)
                    set -x
                    # function to test
                    TESTTHIS="$(printf "%s" "$menu1" | cut -d' ' -f2-)"                    # Drop the first word
                    $TESTTHIS
                    set -n
                ;;
                dnssec*)
                    # DNSSEC URL/SITE tester
                    #   e.g. https://dnsviz.net/d/www.snbforums.com/dnssec/
                    #   e.g. https://dnsviz.net/d/www.nrsforu.com/dnssec/
                    TESTTHIS="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    echo -e $cBCYA"\nClick ${cBYEL}https://dnsviz.net/d/$TESTTHIS/dnssec/ ${cRESET}to view DNSSEC Authentication Chain"
                    ;;
                    dnsinfo|dnsinfo*)
                    #https://mxtoolbox.com/SuperTool.aspx?action=dns%3a9.9.9.9&run=toolpage
                    TESTTHIS=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        TESTTHIS="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    fi
                    if [ -n "$TESTTHIS" ];then
                        echo -e $cBCYA"\nClick ${cBYEL}https://mxtoolbox.com/SuperTool.aspx?action=dns%3a$TESTTHIS&run=toolpage ${cRESET}to view DNS Server info"
                    else
                        echo -e $cBCYA"\nClick ${cBYEL}https://mxtoolbox.com/SuperTool.aspx?action=dns%3aquad9.net&run=toolpage ${cRESET}to view Quad9 DNS Server info"
                        echo -e $cBCYA"Click ${cBYEL}https://mxtoolbox.com/SuperTool.aspx?action=dns%3acloudflare.net&run=toolpage ${cRESET}to view Cloudflare DNS Server info"
                    fi
                ;;
                links)
                    echo -en $cBCYA"\nClick ${cBYEL}https://rootcanary.org/test.html ${cRESET}to view Web DNSSEC Test"
                    echo -e  $cBCYA"\t\tClick ${cBYEL}https://www.quad9.net/faq/#outer-wrap ${cRESET}to view QUAD9 FAQs/servers list etc."
                    echo -en $cBCYA"Click ${cBYEL}https://1.1.1.1/help ${cRESET}to view Cloudflare."
                    echo -e  $cBCYA"\t\t\t\tClick ${cBYEL}https://cmdns.dev.dns-oarc.net/ ${cRESET}to view Check My DNS."   # v2.09 Credit @rgnldo
                    echo -e  $cBCYA"Click ${cBYEL}https://root-servers.org/ ${cRESET}to view Live Root Server status"
                ;;
                dig*|di*)                                                       # v2.09 'dig {domain} ['time']'

                    # dig txt qnamemintest.internet.nl                          # @rgnldo
                    # dig qnamemintest.internet.nl @127.0.0.1 -p 53535          # @rgnldo
                    # dig +short txt qnamemintest.internet.nl                   # @rgnldo - should see 'HOORAY' if QNAME working
                    local ARG2=                                                 # v2.16
                    if [ "$(echo "$menu1" | wc -w)" -ge 3 ];then                # v2.16
                        local ARG2="$(printf "%s" "$menu1" | cut -d' ' -f3)"
                    fi

                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then                # v2.16
                        TESTTHIS="$(printf "%s" "$menu1" | cut -d' ' -f2)"
                        if [ "$(which dig)" == "/opt/bin/dig" ];then
                            if [ "$ARG2" != "time" ];then                       # v2.16
                                echo -e $cBGRA
                                dig txt $TESTTHIS                               # v2.09 Hotfix
                                [ -n "$(grep -E "^port: 53535" /opt/var/lib/unbound/unbound.conf)" ] && local DIGPORT=53535 || local DIGPORT=53
                                dig $TESTTHIS @127.0.0.1 -p $DIGPORT               # v2.09 Hotfix
                            else
                                # Test dig {domain} five times and print duration       # v2.16 testing for extended-statistic histogram
                                local I=0
                                echo -e $cBCYA"\n\tResponse time\n"$cBGRA
                                while [ $I -lt 5 ]
                                    do (time dig $TESTTHIS) 2>&1 | grep real
                                        I=$((I+1))
                                    done
                            fi
                        else
                                echo -e $cBRED"\a\n\t***ERROR Entware 'dig' utility not installed."
                        fi
                    else
                        echo -e $cBRED"\a\n\t***ERROR Please specify valid domain for 'dig'"
                    fi
                ;;
                option?*)
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        TESTTHIS="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    fi
                    if [ -n "$TESTTHIS" ];then
                        local RESULT="$(Get_unbound_config_option "$TESTTHIS")"
                        case "$RESULT" in
                            "?")
                                echo -e $cBMAG"\n\t'$TESTTHIS' ${cRESET}is NOT defined in 'unbound.conf'"
                            ;;
                            *)
                                echo -e $cBMAG"\n\t'$TESTTHIS' ${cRESET}is defined in 'unbound.conf' Value=${cBMAG}'$RESULT'"
                            ;;

                        esac

                    else
                        echo -e $cBRED"\a\n\t***ERROR Please specify valid 'unbound_config' directive"
                    fi
                ;;
                dumpcache*|restorecache)
                    case $menu1 in
                        dumpcache*)                                                 # v2.17
                            local ARG=
                            if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then            # v2.17 dumpcache bootrest
                               local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                            fi
                            local FN="/opt/share/unbound/configs/cache.txt"
                            # Manually save cache ...to be used over say a REBOOT
                            # NOTE: It will be deleted as soon as it is loaded

                            case "$ARG" in                      # v3.19
                            delete)                             # v3.19
                                    if [ -f $FN ];then
                                        local TIMESTAMP=$(date -r $FN "+%Y-%m-%d %H:%M:%S")
                                        rm $FN
                                        echo -e $cRESET"\n\tunbound cache file $cBGRE'$FN'$cRESET ($TIMESTAMP) DELETED"$cRESET  2>&1
                                    else
                                        echo -e $cRESET"\n\tunbound cache file $cBGRE'$FN'$cRESET does not exist"$cRESET  2>&1
                                    fi
                                    ;;
                            "?")                                # v3.19
                                    local CACHE_MEM_MSG=$(unbound-control stats_noreset | grep "msg.cache" | cut -d'=' -f2)
                                    local CACHE_MEM_RRSET=$(unbound-control stats_noreset | grep "rrset.cache" | cut -d'=' -f2)
                                    $UNBOUNCTRLCMD dump_cache > $FN
                                    local DUMPCACHE_MEM_MSG=$(grep -c "^msg" $FN)
                                    local DUMPCACHE_MEM_RRSET=$(grep -c "^;rrset" $FN)
                                    rm $FN
                                    echo -e ${cBCYA}"\n\tCheck ${cRESET}unbound cache$cBCYA simulated 'dumpcache' msg.cache="$CACHE_MEM_MSG"/"$DUMPCACHE_MEM_MSG "rrset.cache="$CACHE_MEM_RRSET"/"$DUMPCACHE_MEM_RRSET 2>&1
                                    ;;
                            *)
                                    echo -e
                                    unbound_Control "save"              # v2.12 force the 'save' message to console
                                    # Should the cache be automatically restored @BOOT
                                    if [ -z "$(grep -o load_cache /jffs/scripts/post-mount)" ];then       # v2.17
                                        [ -n "$(grep -o unbound_stats /jffs/scripts/post-mount)" ] && POS="$(awk ' /unbound_stats/ {print NR}' "/jffs/scripts/post-mount")";POS=$((POS - 1))
                                        if [ $POS -gt 0 ];then
                                            sed -i "${POS}aFN=\"/opt/share/unbound/configs/cache.txt\"; [ -s \$FN ] && { unbound-control load_cache < \$FN; rm \$FN; logger -st \"(\$(basename \$0))\" \"unbound cache RESTORED from '\$FN'\"; } # unbound_manager" /jffs/scripts/post-mount
                                        else
                                            echo -e "FN=\"/opt/share/unbound/configs/cache.txt\"; [ -s \$FN ] && { unbound-control load_cache < \$FN; rm \$FN; logger -st \"($(basename $0))\" \"unbound cache RESTORED from '\$FN'\"; } # unbound_manager" >> /jffs/scripts/post-mount
                                        fi
                                    fi
                                    echo -e $cBCYA"\tNOTE: unbound cache will be ${cRESET}automatically RESTORED on REBOOT$cBCYA (see /jffs/scripts/post-mount)"$cRESET       # v2.17
                                    ;;
                            esac

                        ;;
                        restorecache)
                            # Manually restore cache ... and DELETE file
                            unbound_Control "rest"              # v2.12 force the 'restore' message to console
                        ;;
                    esac
                ;;
                DoT*)                                           # v2.12
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    fi
                    # https://www.dnsknowledge.com/unbound/configure-unbound-dns-over-tls-on-linux/
                    if [ "$(Unbound_Installed)" == "Y" ] && [ -n "$(grep "forward-zone:#DoT" ${CONFIG_DIR}unbound.conf)" ];then   # v3.12 Hotfix
                        if [ "$ARG" != "disable" ];then
                            AUTO_REPLY6="?"
                            Option_DoT_Forwarder          "$AUTO_REPLY6"
                            local RC=$?
                        else
                            DoT_Forwarder "off"
                            local RC=0
                        fi
                    else
                        echo -e $cBRED"\a\n\tunbound NOT installed! or DoT template NOT defined in 'unbound.conf'?"$cRESET
                        local RC=1
                    fi

                    [ $RC -eq 0 ] && { Restart_unbound;Check_GUI_NVRAM; }           # v3.00
                ;;
                fastmenu*)
                    # unbound-control uses SSL certs for security but this impacts responses see [URL="https://www.snbforums.com/threads/release-unbound_manager-manager-installer-utility-for-unbound-recursive-dns-server.61669/page-33#post-554237"]post #657[/URL]
                    # Thanks @dave14305 see [URL="https://www.snbforums.com/threads/release-unbound_manager-manager-installer-utility-for-unbound-recursive-dns-server.61669/page-42#post-556834"]post #829[/URL]
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    fi
                    if [ "$(Unbound_Installed)" == "Y" ] && [ -n "$(grep -F "control-use-cert:" ${CONFIG_DIR}unbound.conf)" ];then
                        if [ "$ARG" != "disable" ];then
                            AUTO_REPLY8="y"
                            Option_FastMenu          "$AUTO_REPLY8"
                            local RC=$?
                        else
                            FastMenu "disable"
                            local RC=0
                        fi
                    else
                        echo -e $cBRED"\a\n\tunbound NOT installed! or 'control-use-cert:' template NOT defined in 'unbound.conf'?"$cRESET
                        local RC=1
                    fi

                    [ $RC -eq 0 ] && Restart_unbound

                    Check_GUI_NVRAM

                ;;
                firewall*)                                                       # v3.00 [ dev | disable ]
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2-)"
                    fi

                    if [ "$(Unbound_Installed)" == "Y" ] && [ -n "$(grep -F "RPZ" ${CONFIG_DIR}unbound.conf)" ];then
                        if [ "$ARG" != "disable" ];then
                            if [ "$ARG" != "?" ];then                           # v3.02
                                AUTO_REPLY10="?"
                                Option_DNS_Firewall          "$AUTO_REPLY10"   "$ARG"
                                local RC=$?
                            else
                                echo -en ${aBOLD}$cBRED
                                sh /jffs/addons/unbound/unbound_rpz.sh      # v3.02
                                echo -en $cRESET
                                local RC=1
                            fi
                        else
                            DNS_Firewall "disable"
                            local RC=0
                        fi
                    else
                        echo -e $cBRED"\a\n\tunbound NOT installed! or RPZ template NOT defined in 'unbound.conf'?"$cRESET
                        local RC=1
                    fi

                    [ $RC -eq 0 ] && { Restart_unbound;Check_GUI_NVRAM; }
                ;;
                views*)    # v3.17  [ ['?' | ''uninstal'] | [ {view_name ['?' | 'remove']} ] | {view_name domain_name [domain_name... | IP_address...] } | {view_name IP_address ['del']
                    local ARG3=
                    if [ "$(echo "$menu1" | wc -w)" -ge 4 ];then
                        local ARG3="$(printf "%s" "$menu1" | cut -d' ' -f4)"
                    fi
                    local ARG2=
                    if [ "$(echo "$menu1" | wc -w)" -ge 3 ];then
                        local ARG2="$(printf "%s" "$menu1" | cut -d' ' -f3)"
                    fi
                    local ARG=
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2)"
                    fi

                    FN="/opt/share/unbound/configs/unbound.conf.views"       # v3.17
                    [ ! -f $FN ] && echo -e "# View: Clients\n# EndView Clients\n\n" > $FN     # v3.17 Hotfix @tomsk

                    if [ "$(Unbound_Installed)" == "Y" ];then
                        if [ "$menu1" != "viewsv" ] && [ "$menu1" != "viewsx" ];then
                            if [ -n "$ARG" ];then
                                Manage_unbound_Views "$ARG" "$ARG2" "$ARG3"          # v3.17
                                local RC=$?
                            else
                                echo -e $cBCYA"\a\n\t Options syntax:$cRESET [? | uninstall] | {view_name [? | remove]} | {view_name [[type] domain_name[...] | IP_address[...]] [del]} ]"$cRESET
                                local VALID_VIEW_TYPES="deny ${aUNDER}refuse$cRESET redirect static transparent nodefault typetransparent inform inform_deny inform_redirect always_transparent always_refuse always_nxdomain noview"
                                echo -e $cBCYA"\a\n\t Valid ${cBYEL}'type=' $cRESET"${VALID_VIEW_TYPES}$cRESET
                                local RC=1
                            fi
                        else
                            [ "$menu1" == "viewsv" ] && local ACCESS="--view"
                            [ "$menu1" == "viewsx" ] && { local ACCESS="--unix"; local PRE_MD5="$(md5sum $FN | awk '{print $1}')" ; }
                            nano $ACCESS $FN
                            if [ "$ACCESS" == "--unix" ];then
                               local POST_MD5="$(md5sum $FN | awk '{print $1}')"
                               if [ "$PRE_MD5" != "$POST_MD5" ];then
                                  echo -e "\nDo you want to restart unbound to apply your config changes?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
                                  read -r "ANS"
                                  [ "$ANS" == "y" ] && Restart_unbound
                               fi
                            fi
                           RC=1
                         fi
                    else
                        echo -e $cBRED"\a\n\tunbound NOT installed!?"$cRESET
                        local RC=1
                    fi
                    if [ $RC -eq 0 ];then
                        if [ "${menu1:0:6}" != "views?" ];then
                            echo
                            Restart_unbound
                        else
                            echo -e "\nDo you want to restart unbound to apply your config changes?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
                            read -r "ANS"
                            [ "$ANS" == "y" ] && Restart_unbound
                        fi
                    fi
                ;;
                tcpdump*)                                               # [ interface_name [ port_expr ] ]
                    if [ -n "$(which tcpdump)" ];then                   # v3.05
                        local ARG=
                        if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                            local ARG="$(printf "%s" "$menu1" | cut -d' ' -f2)"         # v3.05
                        fi

                        local DNS_INTERFACE="any"                                       # v3.05
                        if [ "$ARG" != "?" ];then                                           # v3.07
                            [ -n "$ARG" ] && local DNS_INTERFACE=$ARG                      # v3.07
                            local TCPDUMP_PORTS="53 or 853"                                 # v3.05

                            if [ "$(echo "$menu1" | wc -w)" -ge 3 ];then                        # v3.05
                                local TCPDUMP_PORTS="$(printf "%s" "$menu1" | cut -d' ' -f3-)"
                            fi

                            echo -e $cBMAG"\a\n${LOGFILE}$TXT\t\t${cBGRE}Press CTRL-C to stop\n"$cRESET
                            trap 'welcome_message' INT
                            [ -n "$(which tcpdump)" ] && tcpdump -i $DNS_INTERFACE 'port ('$TCPDUMP_PORTS')' -nn -tttt || echo -e $cBRED"\a\n\ttcpdump not installed!\n"  # v3.00
                        else
                            tcpdump -D                                  # v3.07
                        fi
                    else
                        echo -e $cBRED"\a\n\tEntware's tcpdump NOT installed!"$cRESET       # v3.05
                    fi
                ;;
                *)
                    printf '\n\n\a\t%bInvalid Option%b "%s"%b Please enter a valid option\n' "$cBRED" "$cRESET" "$menu1" "$cBRED"
                ;;
            esac

            echo -en ${cWGRE}"\n"$cRESET      # Separator line
set +x
        done
}
Check_Lock() {
        if [ -f "/tmp/unbound.lock" ] && [ -d "/proc/$(sed -n '2p' /tmp/unbound.lock)" ] && [ "$(sed -n '2p' /tmp/unbound.lock)" != "$$" ]; then
            if [ "$(($(date +%s)-$(sed -n '3p' /tmp/unbound.lock)))" -gt "1800" ]; then
                Kill_Lock
            else
                logger -st unbound "[*] Lock File Detected ($(sed -n '1p' /tmp/unbound.lock)) (pid=$(sed -n '2p' /tmp/unbound.lock)) - Exiting (cpid=$$)"
                echo; exit 1
            fi
        fi
        if [ -n "$1" ]; then
            echo "$1" > /tmp/unbound.lock
        else
            echo "menu" > /tmp/unbound.lock
        fi
        echo "$$" >> /tmp/unbound.lock
        date +%s >> /tmp/unbound.lock
}
Kill_Lock() {

        if [ -f "/tmp/unbound.lock" ] && [ -d "/proc/$(sed -n '2p' /tmp/unbound.lock)" ]; then
            logger -st unbound "[*] Killing Locked Processes ($(sed -n '1p' /tmp/unbound.lock)) (pid=$(sed -n '2p' /tmp/unbound.lock))"
            logger -st unbound "[*] $(ps | awk -v pid="$(sed -n '2p' /tmp/unbound.lock)" '$1 == pid')"
            kill "$(sed -n '2p' /tmp/unbound.lock)"
            rm -rf /tmp/unbound.lock
            echo
        fi
}

validate_removal() {

        local REMOVED=0                                 # v2.00

        while true; do
            printf '\n%bIMPORTANT: It is recommended to REBOOT in order to complete the removal of unbound\n             %bYou will be asked to confirm BEFORE proceeding with the REBOOT\n\n' "${cBRED}" "${cBRED}"
            #printf '%by%b = Are you sure you want to uninstall unbound? Reply Y or ENTER to CANCEL\n' "${cBYEL}" "${cRESET}"
            echo -e $cRESET"Press$cBRED Y$cRESET to${cBRED} REMOVE ${cRESET}unbound ${cRESET}or press$cBGRE [Enter] to CANCEL"
            printf '\n%bOption ==>%b ' "${cBYEL}" "${cRESET}"
            read -r "menu3"
            case "$menu3" in
                Y)
                    remove_existing_installation "$1"   # v2.09
                    local REMOVED=1                     # v2.00
                    break
                ;;
                *)
                    break
                ;;
            esac
        done

        return $REMOVED                                 # v2.00
}
is_dir_empty() {

        DIR="$1"
        cd "$DIR" || return 1
        set -- .[!.]* ; test -f "$1" && return 1
        set -- ..?* ; test -f "$1" && return 1
        set -- * ; test -f "$1" && return 1
        return 0
}
Check_dnsmasq_postconf() {

    local FN="/jffs/scripts/dnsmasq.postconf"

    if [ "$1" != "del" ];then
        echo -e $cBCYA"Customising 'dnsmasq.postconf' (aka '/jffs/addons/unbound/unbound.postconf')"$cRESET       # v1.08
        [ ! -f $FN ] && { echo "#!/bin/sh" > $FN; chmod +x $FN; }   # v3.11 Hotfix @dave14305
        # By convention only add one-liner....
        if [ -z "$(grep -E "sh \/jffs\/addons\/unbound\/unbound\.postconf" $FN)" ];then
            $(Smart_LineInsert "$FN" "$(echo -e "sh /jffs/addons/unbound/unbound.postconf \"\$1\"\t\t# unbound_manager")" )  # v1.10
        fi

        # Create Dual mode 'unbound<<--dnsmasq<<--LAN device DNS request' or 'unbound<<--LAN device DNS request'
        cat > /jffs/addons/unbound/unbound.postconf << EOF
#!/bin/sh

CONFIG=\$1
source /usr/sbin/helper.sh

######################################################################
#####            DO NOT EDIT THIS FILE MANUALLY                #######
#####             You are probably looking for                 #######
#####               your customising script                    #######
#####     '/opt/share/unbound/configs/unbound.postconf'        #######
######################################################################
logger -t "(dnsmasq.postconf)" "Updating \$CONFIG for unbound....."                      # unbound_manager

ROUTER="\$(nvram get lan_ipaddr_rt)"

if [ -n "\$(pidof unbound)" ];then
   if [ -n "\$(grep -E "^port: 53535" /opt/var/lib/unbound/unbound.conf)" ];then   # Forward dnsmasq DNS requests to unbound
        pc_delete "servers-file" \$CONFIG
        # By design, if GUI DNSSEC ENABLED then attempt to modify 'cache-size=0' results in dnsmasq start-up fail loop
        #       dnsmasq[15203]: cannot reduce cache size from default when DNSSEC enabled
        #       dnsmasq[15203]: FAILED to start up
        if [ -n "\$(grep "^dnssec" \$CONFIG)" ];then
           pc_delete "dnssec" \$CONFIG
           logger -t "(dnsmasq.postconf)" "**Warning: Removing 'dnssec' directive from 'dnsmasq' to allow DISABLE cache (set 'cache-size=0')"
        fi

        pc_replace "cache-size=1500" "cache-size=0" \$CONFIG
        UNBOUNDLISTENADDR="127.0.0.1#53535"
        #UNBOUNDLISTENADDR="\$(netstat -nlup | awk '/unbound/ { print \$4 } ' | tr ':' '#')"   # unbound_manager
        pc_append "server=\$UNBOUNDLISTENADDR" \$CONFIG
        if [ "\$(/bin/uname -o)" == "ASUSWRT-Merlin-LTS" ];then   # Requested by @dave14305
            pc_delete "resolv-file" \$CONFIG
            pc_append "no-resolv" \$CONFIG
        fi
    else
        logger -t "(dnsmasq.postconf)" "dnsmasq DNS bypassed. unbound will be the primary DNS for ALL LAN Clients."

        [ -z "\$(grep -F "port=0" \$CONFIG)" ] && pc_append "port=0" \$CONFIG          # Disable dnsmasq DNS resolver function
        [ -z "\$(grep -F "dhcp-option=lan,6,\$ROUTER" \$CONFIG)" ] && pc_append "dhcp-option=lan,6,\$ROUTER" \$CONFIG
        pc_delete "servers-file" \$CONFIG
        pc_delete "no-negcache" \$CONFIG
        pc_delete "domain-needed" \$CONFIG
        pc_replace "cache-size=1500" "cache-size=0" \$CONFIG
    fi
else
   sed -i '/port=0/d' \$CONFIG
   pc_delete "dhcp-option=lan,6,\$ROUTER" \$CONFIG
fi
EOF

    else
        echo -e $cBCYA"Removing unbound installer directives from 'dnsmasq.postconf'"$cRESET        # v1.08
        sed -i '/#.*unbound_/d' $FN                                                                 # v1.23
        [ -f /jffs/addons/unbound/unbound.postconf ] && rm /jffs/addons/unbound/unbound.postconf    # v2.00 v1.11
    fi

    [ -f $FN ] && chmod +x $FN          # v1.06
    [ -f /jffs/addons/unbound/unbound.postconf ] && chmod +x /jffs/addons/unbound/unbound.postconf  # v2.00 v1.11
}
create_required_directories() {
        for DIR in  "/opt/etc/unbound" "/opt/var/lib/unbound" "/opt/var/lib/unbound/adblock" "/opt/var/log" "/opt/share/unbound/configs" "/opt/share/unbound/configs/doc" "/opt/share/unbound/configs/adblock"; do   # v2.15
            if [ ! -d "$DIR" ]; then
                if mkdir -p "$DIR" >/dev/null 2>&1; then
                    printf "Created project directory %b%s%b\\n" "${cBGRE}" "${DIR}" "${cRESET}"
                    #[ "$DIR" == "/opt/etc/unbound" ] && chown nobody /opt/etc/unbound
                    if [ "$DIR" == "/opt/etc/unbound" ] || [ "$DIR" == "/opt/var/lib/unbound" ];then    # v1.17
                        chown nobody $DIR
                    fi
                else
                    printf "%b***ERROR creating directory %b%s%b. Exiting $(basename "$0")\\n" "$cBRED" "${cBGRE}" "${DIR}" "${cRESET}"
                    exit 1
                fi
            fi
        done
}
download_file() {

        local DIR="$1"
        local FILE="$2"

        local GITHUB="$3"                                       # v2.06
        local GITHUB_BRANCH="$4"                                # v2.06

        case $GITHUB in                                        # v1.08
            martineau)
                [ "$GITHUB_BRANCH" != "dev" ] && GITHUB_DIR=$GITHUB_MARTINEAU || GITHUB_DIR=$GITHUB_MARTINEAU_DEV
            ;;
            juched)
                [ "$GITHUB_BRANCH" != "dev" ] && GITHUB_DIR=$GITHUB_JUCHED || GITHUB_DIR=$GITHUB_JUCHED_DEV                      # v2.14
            ;;
            nlnetlabs)
                [ "$GITHUB_BRANCH" != "dev" ] && GITHUB_DIR=$GITHUB_NLNETLABS || GITHUB_DIR=$GITHUB_NLNETLABS                    # v3.06
            ;;
        esac

        [ "$GITHUB_BRANCH" == "dev" ] && local DEVTXT=${cRESET}$cWRED"Github 'dev/development' branch"$cRESET || local DEVTXT=

        STATUS="$(curl --retry 3 -L${SILENT} -w '%{http_code}' "$GITHUB_DIR/$FILE" -o "$DIR/$FILE")"    # v1.08
        if [ "$STATUS" -eq "200" ]; then
            [ -n "$(echo "$@" | grep -F "dos2unix")" ] && dos2unix $DIR/$FILE      # v2.17
            printf '\t%b%s%b downloaded successfully %b\n' "$cBGRE" "$FILE" "$cRESET" "$DEVTXT"

        else
            printf '\n%b%s%b download FAILED with curl error %s\n\n' "\n\t\a$cBMAG" "'$FILE'" "$cBRED" "$STATUS"
            printf '\tRerun %bunbound_manager nochk%b and select the %bRemove unbound/unbound_manager%b option\n\n' "$cBGRE" "$cRESET" "$cBGRE" "$cRESET"   # v1.17

            Check_GUI_NVRAM                                     # v1.17

            echo -e $cRESET"\a\n"

            exit 1
        fi
}
S61unbound_update() {

    echo -e $cBCYA"Updating S61unbound"$cBGRA

    if [ -d "/opt/etc/init.d" ]; then
        /opt/bin/find /opt/etc/init.d -type f -name S61unbound\* | while IFS= read -r "line"; do
            rm "$line"
        done
    fi
    download_file /opt/etc/init.d S61unbound martineau $1         # v3.11 v2.02 v1.11

    chmod 755 /opt/etc/init.d/S61unbound >/dev/null 2>&1
}
S02haveged_update() {

    echo -e $cBCYA"Updating S02haveged"$cGRA

    if [ -d "/opt/etc/init.d" ]; then
        /opt/bin/find /opt/etc/init.d -type f -name "S02haveged*" | while IFS= read -r "line"; do
            rm "$line"
        done
    fi

    download_file /opt/etc/init.d S02haveged martineau                                         # v3.23 v2.02 v1.11

    chmod 755 /opt/etc/init.d/S02haveged >/dev/null 2>&1

    /opt/etc/init.d/S02haveged restart
}
Option_Stubby_Integration() {

     local ANS=$1                                           # v1.20
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ] || [ "$ANS" == "?" ];then
        # v2.07 Stubby-Integration defeats main selling point of unbound i.e. being your own (secure) Recursive DNS Resolver
        echo -e "\nDo you want to integrate Stubby with unbound?"
        echo -e $cBRED"\n\tWarning: This will DISABLE being able to be your ${aUNDER}own trusted Recursive DNS Resolver\n"$cRESET
        echo -e "\tClick the link below, and read BEFORE answering!\n"
        echo -e $cBYEL"\thttps://github.com/MartineauUK/Unbound-Asuswrt-Merlin/blob/master/Readme.md#a-very-succinct-description-of-the-implicationuse-of-the-option-stubby-integration"$cRESET
        echo -e "\nSo, do you STILL want to integrate Stubby with unbound? (${cBCYA}NO$cRESET recommended)\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     [ "$ANS" == "y"  ] && Stubby_Integration
}
Stubby_Integration() {

    echo -e $cBCYA"Integrating Stubby with unbound....."$cBGRA

    # Check for firmware support of Stubby (Merlin "dnspriv" or John's fork "stubby")       # v2.08 **Pull Request @dave14305**
    if nvram get rc_support | tr ' ' '\n' | grep -qE "dnspriv|stubby"; then
        # router supports stubby natively
        if [ "$(/bin/uname -o)" != "ASUSWRT-Merlin-LTS" ] && [ $FIRMWARE -ge 38406 ];then        # v2.10
            # Merlin firmware
            if [ "$(nvram get dnspriv_enable)" -eq "1" ]; then
                # set Unbound forward address to 127.0.1.1:53
                echo -e $cBCYA"Adding Stubby 'forward-zone:'"$cRESET
                if [ -n "$(grep -E "#forward-zone:" ${CONFIG_DIR}unbound.conf)" ];then
                    #sed -i '/forward\-zone:/,/forward\-addr: 127\.0\.0\.1\@5453/s/^#//' ${CONFIG_DIR}unbound.conf   # v2.18 Bug prompted to review by @toazd
                    local POS=$(grep -nE "^#forward-zone:" ${CONFIG_DIR}unbound.conf | grep -v DNS | cut -d':' -f1)   # v2.18 Hotfix
                    [ -n "$POS" ] && sed -i "$POS,/forward\-addr: 127\.0\.[01]\.1\@5453/s/^#//" ${CONFIG_DIR}unbound.conf   # v2.18 Hotfix
                    sed -i 's/forward\-addr: 127\.0\.[01]\.1\@[0-9]\{1,5\}/forward\-addr: 127\.0\.1\.1\@53/' ${CONFIG_DIR}unbound.conf
                    [ "$(nvram get ipv6_service)" != "disabled" ] && sed -i '/forward\-addr: 0::1@5453/ s/^#//' ${CONFIG_DIR}unbound.conf   # v2.18 Hotfix
                fi
            else
                echo -e $cBRED"\a\n\tERROR: DNS Privacy (DoT) not enabled in GUI. see $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/Advanced_WAN_Content.asp WAN->DNS Privacy Protocol\n"$cRESET 2>&1       # v 2.13 v2.08 Martineau add message attributes
            fi
        elif [ "$(nvram get stubby_proxy)" -eq "1" ]; then
            # John's fork
            # set Unbound forward address to 127.0.0.1 and port determined in nvram stubby_port
            echo -e $cBCYA"Adding Stubby 'forward-zone:'"$cRESET
            if [ -n "$(grep -F "#forward-zone:" ${CONFIG_DIR}unbound.conf)" ];then
                local POS=$(grep -nE "^#forward-zone:" ${CONFIG_DIR}unbound.conf | grep -v DNS | cut -d':' -f1)   # v2.18 Hotfix
                sed -i "$POS,/forward\-addr: 127\.0\.[01]\.1\@53/s/^#//" ${CONFIG_DIR}unbound.conf   # v2.18 Hotfix
                sed -i "s/forward\-addr: 127\.0\.[01]\.1\@[0-9]\{1,5\}/forward\-addr: 127\.0\.0\.1\@$(nvram get stubby_port)/" ${CONFIG_DIR}unbound.conf
            fi
        else
            echo -e $cBRED"\a\n\tERROR: Stubby not enabled in GUI.\n"$cRESET                # v2.08 Martineau add message attributes
        fi                                                                                  # v2.08 **Pull Request @dave14305**
    else
        # Firmware may already contain stubby i.e. which stubby --> /usr/sbin/stubby '0.2.9' aka spoof 100002009
        ENTWARE_STUBBY_MAJVER=$(opkg info stubby | grep "^Version" | cut -d' ' -f2 | cut -d'-' -f1)
        [ -f /usr/sbin/stubby ] && FIRMWARE_STUBBY_MAJVER=$(/usr/sbin/stubby -V) || FIRMWARE_STUBBY_MAJVER="n/a"

        echo -e $cBCYA"Entware stubby Major version="$ENTWARE_STUBBY_MAJVER", Firmware stubby Major version="${FIRMWARE_STUBBY_MAJVER}$cBGRA
        ENTWARE_STUBBY_MAJVER=$(opkg info stubby | grep "^Version" | cut -d' ' -f2 | tr '-' ' ' | awk 'BEGIN { FS = "." } {printf(1"%03d%03d%03d",$1,$2,$3)}')
        [ -f /usr/sbin/stubby ] && FIRMWARE_STUBBY_MAJVER=$(/usr/sbin/stubby -V | awk 'BEGIN { FS = "." } {printf(1"%03d%03d%03d",$1,$2,$3)}') || FIRMWARE_STUBBY_MAJVER="000000000"
        opkg install stubby ca-bundle

        download_file /opt/etc/init.d S62stubby martineau         # v3.23 v2.02 v1.10
        chmod 755 /opt/etc/init.d/S62stubby                     # v1.11
        download_file /opt/etc/stubby/ stubby.yml martineau       # v3.23 v2.02 v1.08

        if [ "$(nvram get ipv6_service)" != "disabled" ];then   # v1.13
            echo -e $cBCYA"Customising Stubby IPv6 'stubby.yml' configuration....."$cRESET
            #  # - 0::1@5453 ## required IPV6 enabled
            sed -i '/  # - 0::1@5453/s/^  # /  /' /opt/etc/stubby/stubby.yml            # v1.13
            # Cloudflare Primary IPv6
            #  - address_data: 2606:4700:4700::1111
            #    tls_auth_name: "cloudflare-dns.com"
            # Cloudflare Secondary IPv6
            #  - address_data: 2606:4700:4700::1001
            #    tls_auth_name: "cloudflare-dns.com"
            sed -i '/address_data: 2606:4700:4700::1111/,/tls_auth_name:/s/^#//' /opt/etc/stubby/stubby.yml # v1.13
            sed -i '/address_data: 2606:4700:4700::1001/,/tls_auth_name:/s/^#//' /opt/etc/stubby/stubby.yml # v1.13
            # dns.sb IPv6
            #  - address_data: 2a09::0
            #    tls_auth_name: "dns.sb"
            #    tls_pubkey_pinset:
            #      - digest: "sha256"
            #        value: /qCm+kZoAyouNBtgd1MPMS/cwpN4KLr60bAtajPLt0k=
            # dns.sb IPv6
            #  - address_data: 2a09::1
            #    tls_auth_name: "dns.sb"
            #    tls_pubkey_pinset:
            #      - digest: "sha256"
            #        value: /qCm+kZoAyouNBtgd1MPMS/cwpN4KLr60bAtajPLt0k=
            sed -i '/address_data: 2a09::0/,/value:/s/^#//' /opt/etc/stubby/stubby.yml  # v1.13
            sed -i '/address_data: 2a09::1/,/value:/s/^#//' /opt/etc/stubby/stubby.yml  # v1.13
        fi

        /opt/etc/init.d/S62stubby restart                       # v1.11

        echo -e $cBCYA"Adding Stubby 'forward-zone:'"$cRESET
        if [ -n "$(grep -F "#forward-zone:" ${CONFIG_DIR}unbound.conf)" ];then
            #sed -i '/forward\-zone:/,/forward\-first: yes/s/^#//' ${CONFIG_DIR}unbound.conf     # v1.04
            sed -i '/forward\-zone:/,/forward\-addr: 127\.0\.0\.1\@5453/s/^#//' ${CONFIG_DIR}unbound.conf     # v2.00
        fi

        if [ "$(nvram get ipv6_service)" != "disabled" ];then                       # v1.10
            echo -e $cBCYA"Customising unbound IPv6 Stubby configuration....."$cRESET
            # Options for integration with TCP/TLS Stubby
            #udp-upstream-without-downstream: yes
            sed -i '/udp\-upstream\-without\-downstream: yes/s/^#//g' ${CONFIG_DIR}unbound.conf
        fi
    fi
}
Option_DoT_Forwarder() {

     local ANS=$1                                           # v2.12
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ] || [ "$ANS" == "?" ];then
        # v2.12 DoT defeats main selling point of unbound i.e. being your own (secure) Recursive DNS Resolver
        echo -e "\nDo you want to ENABLE DoT with unbound?"
        echo -e $cBRED"\n\tWarning: This will DISABLE being able to be your ${aUNDER}own trusted Recursive DNS Resolver\n"$cRESET
        #echo -e "\tClick the link below, and read BEFORE answering!\n"
        #echo -e $cBYEL"\thttps://github.com/MartineauUK/Unbound-Asuswrt-Merlin/blob/master/Readme.md#a-very-succinct-description-of-the-implicationuse-of-the-option-stubby-integration"$cRESET
        echo -e "So, do you STILL want to ENABLE DoT with unbound?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     [ "$ANS" == "y"  ] && { DoT_Forwarder; return 0; } || return 1                     # v2.12
}
DoT_Forwarder() {

    # Include IPv6 if ENABLED ( Ignore if 'do-ip6: no' ??? )
    [ "$(nvram get ipv6_service)" != "disabled" ] && local TO="forward-addr: 2620:fe::9" || local TO="forward-addr: 149.112"

    if [ "$1" != "off" ];then
        echo -e $cBCYA"\n\tEnabling DoT with unbound now as a ${cBWHT}Forwarder.\n"$cBGRA     # v2.12
        #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        #forward-zone:      # DNS-Over-TLS support
        #name: "."
        #forward-tls-upstream: yes
        #forward-addr: 1.1.1.1@853#cloudflare-dns.com
        #forward-addr: 1.0.0.1@853#cloudflare-dns.com
        #forward-addr: 9.9.9.9@853#dns.quad9.net
        #forward-addr: 149.112.112.112@853#dns.quad9.net
        #forward-addr: 2606:4700:4700::1111@853#cloudflare-dns.com
        #forward-addr: 2606:4700:4700::1001@853#cloudflare-dns.com
        #forward-addr: 2620:fe::fe@853#dns.quad9.net
        #forward-addr: 2620:fe::9@853#dns.quad9.net
        #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        Edit_config_options "forward-zone:#DoT" "$TO" "uncomment"                   # v3.12 Hotfix @joe scian
    else
        [ -n "$(grep "^forward-zone:#DoT" ${CONFIG_DIR}unbound.conf)" ] && Edit_config_options "forward-zone:#DoT" "$TO" "comment"   # v3.12 Hotfix @joe scian
        echo -e $cBCYA"\n\tunbound DoT disabled.\n"$cBGRA
    fi
}
Option_GUI_Stats_TAB() {

     local ANS=$1                                           # v2.14
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ];then
        # v2.14 @juched wrote  GUI TAB to display stats
        echo -e "\nDo you want to add router GUI TAB to Graphically display stats?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     [ "$ANS" == "y"  ] && { GUI_Stats_TAB "$@"; return $?; } || return 1                # v3.00 v2.14
}
GUI_Stats_TAB(){

    local STATUS=0

    if [ "$1" != "uninstall" ];then

        # Allow for any latest @juched tweaks.....
        echo -e $cBCYA"\n\tInstalling GUI TAB to Graphically display unbound stats....."$cRESET     # v2.14

        [ "$2" != "dev" ] && local DEV= || local DEV="dev"      # v3.00 juched now also hosts a "dev" branch

        download_file /jffs/addons/unbound/ unbound_stats.sh        juched   "$DEV"         # v3.00
        download_file /jffs/addons/unbound/ unboundstats_www.asp    juched   "$DEV"         # v3.00
        if [ -n "$(grep "unbound_log.sh" /jffs/addons/unbound/unbound_stats.sh)" ];then    # v3.00
            download_file /jffs/addons/unbound/ unbound_log.sh      juched   "$DEV"         # v3.00
            chmod +x /jffs/addons/unbound/unbound_log.sh                                   # v3.00
        fi
        chmod +x /jffs/addons/unbound/unbound_stats.sh

        echo -en $cBGRA
        sh /jffs/addons/unbound/unbound_stats.sh "install"
        echo -en $cRESET

    else
        if [ -f /tmp/menuTree.js ] && [ -n "$(grep -i "Unbound" /tmp/menuTree.js)" ];then
            if [ ! -f /jffs/addons/unbound/unbound_stats.sh ];then              # v3.00 Hotfix
                echo -e $cBRED"\a\n\t***ERROR Orphaned TAB; missing 'unbound_stats.sh' script??? - retrieving....."$cRESET # v3.00 Hotfix
                download_file /jffs/addons/unbound/ unbound_stats.sh juched     # v3.00 Hotfix
                download_file /jffs/addons/unbound/ unboundstats_www.asp    juched
                chmod +x /jffs/addons/unbound/unbound_stats.sh                  # v3.00 Hotfix
            fi
            sh /jffs/addons/unbound/unbound_stats.sh "uninstall"
            rm /jffs/addons/unbound/unboundstats_www.asp 2>/dev/null
            rm /jffs/addons/unbound/unbound_stats.sh     2>/dev/null
            rm /jffs/addons/unbound/unbound_log.sh       2>/dev/null     # v3.00
            echo -e $cBCYA"\n\tunbound GUI graphical stats TAB uninstalled."$cRESET
        else
            echo -e $cBRED"\a\n\t***ERROR unbound GUI graphical stats TAB NOT installed"$cRESET
        fi
    fi

    return $STATUS                                          # v2.15
}
Option_FastMenu() {

     local ANS=$1                                           # v2.15
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ];then
        # v2.15 @dave14305 suggests turning off unbound-control SSL cert validation to improve responses
        echo -e "\nDo you want to speed up menu display (Removes unbound-control unnecessary LAN SSL validation)?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     [ "$ANS" == "y"  ] && { FastMenu; return 0; } || return 1   # v2.15
}
FastMenu() {

    if [ "$1" != "disable" ];then                                # v2.15
        echo -e $cBCYA"\n\tunbound-control FAST response ${cRESET}ENABLED (LAN SSL validation removed)"$cBGRA
        Edit_config_options "control-use-cert:"  "uncomment"
    else
        Edit_config_options "control-use-cert:"  "comment"
        echo -e $cBCYA"\n\tunbound-control FAST response ${cRESET}DISABLED (LAN SSL validation reinstated)"$cBGRA
    fi
}
Option_Use_VPN_Tunnel() {

    # Use VPN Client tunnel for unbound requests to Root Servers        # v3.00
     local ANS=$1
     local ARG=$2
     local ARG2=$3
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ] || [ "$ANS" == "?" ];then         # v3.05
        echo -e "\nDo you want to route unbound requests through VPN Client ${cBMAG}'$ARG'$cRESET tunnel?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     [ "$ANS" == "y"  ] && { Use_VPN_Tunnel "$ARG" "$ARG2" ; return $?; } || return 1                # v3.00
}
Use_VPN_Tunnel() {

    local STATUS=0

    if [ -n "$(grep -E "^[#|o].*utgoing-interface:" /opt/var/lib/unbound/unbound.conf)" ];then
        [ "$1" = "y" ] && shift                                   # v3.05
        local VPN_ID=$(echo "$1" | awk '{print $1}')              # v3.04 HotFix
        local TRACK=$2                                            # v3.05
        local TXT=

        case $VPN_ID in                                         # v3.05
        1|2|3|4|5)
                if [ "$(nvram get vpn_client${VPN_ID}_state)" == "2"  ];then
                    Edit_config_options "outgoing-interface:"  "uncomment"
                    # v3.23 https://github.com/MartineauUK/Unbound-Asuswrt-Merlin/issues/20 @AlexanderPavlenko
                    local VPN_CLIENT_GW=$(ip route | grep -E "dev tun1${VPN_ID}.*proto" | awk '{print $NF}')   # v3.23 @AlexanderPavlenko
                    if [ -n "$VPN_CLIENT_GW" ];then         # v3.05
                        sed -i "/^outgoing-interface:/ s/[^ ]*[^ ]/$VPN_CLIENT_GW/2" ${CONFIG_DIR}unbound.conf
                        if [ "$TRACK" == "debug" ] && [ -z "$(iptables -nvL OUTPUT | grep "DNS")" ];then   # v3.05
                           iptables -I OUTPUT -p udp -m udp --dport 53 -m comment --comment "DNS request tracker" -j LOG
                           local TXT=", and tracked in Syslog"
                           #WANIP=$(nvram get wan0_ipaddr);grep -o "^.*DPT=53" /tmp/syslog.log | sed -r 's/LEN.*PROTO=//' | sed -r 's/LEN.*PROTO=//' | sed -r "s/$WANIP/wan.isp.ip.addr/"local TXT="and Tracked to Syslog"
                        fi
                        echo -e $cBCYA"\n\tunbound requests via VPN Client ${cBMAG}$VPN_ID ($VPN_CLIENT_GW)$cBCYA tunnel ${cRESET}ENABLED"${TXT}$cBGRA   # v3.04
                        SayT "unbound requests via VPN Client $VPN_ID ($VPN_CLIENT_GW) tunnel ENABLED"$TXT
                    else
                        Edit_config_options "outgoing-interface:"  "comment"   # v3.05
                        echo -e $cBRED"\a\n\n\t***ERROR unbound request via VPN Client ${cBMAG}$VPN_ID ($VPN_CLIENT_GW)$cBCYA tunnel ABORTED!\n"$cRESET   # v3.04 Hotfix
                        SayT "unbound requests via VPN Client $VPN_ID ($VPN_CLIENT_GW) tunnel ABORTED!"       # v3.04 Hotfix
                        STATUS=1                    # v3.05
                    fi
                else
                    echo -e $cBRED"\n\a"
                    Say "***ERROR VPN Client '$VPN_ID' is NOT Connected?"
                    STATUS=1
                fi
        ;;
        disable)
                # Remember, 'post-mount' initialises Entware then you must include the following:
                #   [ -n "$(which unbound_manager)" ] && sh /jffs/addons/unbound/unbound_manager.sh vpn=disable
                #
                Edit_config_options "outgoing-interface:"  "comment"
                iptables -D OUTPUT -p udp -m udp --dport 53 -m comment --comment "DNS request tracker" -j LOG 2>/dev/null
                echo -e $cBCYA"\n\tunbound requests via VPN Client tunnel ${cRESET}DISABLED"$cBGRA
                SayT "unbound requests via VPN Client $VPN_ID tunnel DISABLED"
        ;;
        *)
            echo -e $cBRED"\a\n\t***ERROR Invalid argument '$VPN_ID' VPN must be numeric '1-5' or 'disable'"
            SayT "***ERROR Invalid argument '$VPN_ID' must be numeric '1-5' or 'disable'"
            local STATUS=1
        esac
    else
        local STATUS=1
        return $STATUS                                          # v3.05
    fi
}
Option_BIND_WAN() {

    # Force WAN for unbound requests to Root Servers        # v3.06
     local ANS=$1
     local ARG=$2
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ] || [ "$ANS" == "?" ];then
        echo -e "\nDo you want to force BIND unbound requests via ${cBMAG}'WAN'$cRESET?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     [ "$ANS" == "y"  ] && { BIND_WAN "$ARG" "$ARG2" ; return $?; } || return 1
}
BIND_WAN() {

    local STATUS=0
    local TRACK=$1                                            # v3.07
    local TXT=

    if [ -n "$(grep -E "^[#|o].*utgoing-interface:" /opt/var/lib/unbound/unbound.conf)" ];then

        local INTERFACE="wan"
        [ "$TRACK" == "any" ] && INTERFACE="any"

        case $INTERFACE in                                         # v3.06
        wan)
            Edit_config_options "outgoing-interface:"  "uncomment"
            local WAN_IF=$(Get_WAN_IF_Name)                     # v3.06 Hotfix
            if [ "${WAN_IF:0:3}" != "ppp" ];then                # v3.13 v3.10 Hotfix
                local WAN_GW=$(ip route | grep src | grep -v default | grep -E "dev $WAN_IF[[:space:]]" | awk '{print $NF}')    # v3.06 Hotfix
            else
                local WAN_GW=$(ip -o -4  address show | grep $WAN_IF | awk ' { gsub(/\/.*/, "", $4); print $4 } ')     # v3.13 Hotfix 3.10 Fix
            fi
            if [ -n "$WAN_GW" ];then
                sed -i "/^outgoing-interface:/ s/[^ ]*[^ ]/$WAN_GW/2" ${CONFIG_DIR}unbound.conf
                if [ "$TRACK" == "debug" ] && [ -z "$(iptables -nvL OUTPUT | grep "DNS")" ];then   # v3.05
                   iptables -I OUTPUT -p udp -m udp --dport 53 -m comment --comment "DNS request tracker" -j LOG
                   local TXT=", and tracked in Syslog"
                   #WANIP=$(nvram get wan0_ipaddr);grep -o "^.*DPT=53" /tmp/syslog.log | sed -r 's/LEN.*PROTO=//' | sed -r 's/LEN.*PROTO=//' | sed -r "s/$WANIP/wan.isp.ip.addr/"local TXT="and Tracked to Syslog"
                fi
                echo -e $cBCYA"\n\tunbound requests force BIND to ${cBMAG}WAN ($WAN_GW) '$WAN_IF' ${cRESET}ENABLED"${TXT}$cBGRA   # v 3.09 v3.07
                SayT "unbound requests force BIND via WAN ($WAN_GW) ENABLED"$TXT        # v3.07
            else
                Edit_config_options "outgoing-interface:"  "comment"
                echo -e $cBRED"\a\n\n\t***ERROR unbound request force BIND via ${cBMAG}WAN ($WAN_GW) '$WAN_IF' $cBCYA ABORTED!\n"$cRESET   # v3.09 v3.04 Hotfix
                SayT "unbound request force BIND via WAN ($WAN_GW) ABORTED!"
                STATUS=1
            fi
        ;;
        any)
            # Remember, 'post-mount' initialises Entware then you must include the following:
            #   [ -n "$(which unbound_manager)" ] && sh /jffs/addons/unbound/unbound_manager.sh vpn=disable
            #
            Edit_config_options "outgoing-interface:"  "comment"
            iptables -D OUTPUT -p udp -m udp --dport 53 -m comment --comment "DNS request tracker" -j LOG 2>/dev/null   # v3.07
            echo -e $cBCYA"\n\tunbound requests via ANY interface ${cRESET}ENABLED"$cBGRA
            SayT "unbound requests via ANY interface ENABLED"
        ;;
        *)
            echo -e $cBRED"\a\n\t***ERROR Invalid argument '$INTERFACE' 'any' or 'disable'"
            SayT "***ERROR Invalid argument '$INTERFACE' 'any' or 'disable'"
            local STATUS=1
        esac
    else
        local STATUS=1
        return $STATUS                                          # v3.05
    fi
}
Option_DNS_Firewall() {

    # Enable DNS Firewall# v3.00
     local ANS=$1
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ] || [ "$ANS" == "?" ];then
        echo -e "\nDo you want to enable DNS Firewall?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     [ "$ANS" == "y"  ] && { DNS_Firewall "$@"; return 0; } || return 1                # v3.02 v3.00
}
DNS_Firewall() {

    local STATUS=0

    local FIREWALL_CONFIG="/opt/share/unbound/configs/unbound.conf.firewall"           # v3.03

    if [ "$1" != "disable" ];then

        [ "$2" != "dev" ] && local DEV= || local DEV="dev"      # v3.00 juched now also hosts a "dev" branch

        download_file /jffs/addons/unbound/ unbound_rpz.sh  juched "$DEV" dos2unix      # v3.02
        chmod +x /jffs/addons/unbound/unbound_rpz.sh

        if [ ! -f /opt/share/unbound/configs/rpzsites ];then                           # v3.03 Hotfix
            download_file /opt/share/unbound/configs/ rpzsites  juched "$DEV" dos2unix   # v3.03 Hotfix
        else
            echo -e $cBCYA"Custom '/opt/share/unbound/configs/rpzsites' already exists - ${cBGRE}'rpzsites'$cRESET download skipped"$cBGRA
        fi

        echo -e $cGRA
        sh /jffs/addons/unbound/unbound_rpz.sh "install"                                # v3.02
        # Allow external definitions...created by @juched's 'unbound_rpz.sh'            # v3.03
        echo -e $cBCYA"Adding $cBGRE'include: \"$FIREWALL_CONFIG\" ${cBCYA}to '${CONFIG_DIR}unbound.conf'"$cBGRA # v3.03 Hotfix
        [ -z "$(grep "^include.*$FIREWALL_CONFIG" ${CONFIG_DIR}unbound.conf)" ] && echo -e "include: \"$FIREWALL_CONFIG\"\t\t# Custom DNS Firewall\n" >>  ${CONFIG_DIR}unbound.conf # v3.04 v3.03
        echo -e $cBCYA"\n\tunbound DNS Firewall ${cRESET}ENABLED"$cBGRA
        SayT "unbound DNS Firewall ENABLED"
    else
        echo -e $cGRA
        sh /jffs/addons/unbound/unbound_rpz.sh "uninstall"                              # v3.02
        [ -n "$(grep "^include.*$FIREWALL_CONFIG" ${CONFIG_DIR}unbound.conf)" ] && sed -i "\\~$FIREWALL_CONFIG~d" ${CONFIG_DIR}unbound.conf # v3.04 v3.03
        echo -e $cBCYA"\n\tunbound DNS Firewall ${cRESET}DISABLED"$cBGRA
        SayT "unbound DNS Firewall DISABLED"
    fi

    return $STATUS
}
Get_RootDNS() {
     # https://www.iana.org/domains/root/servers
     # https://root-servers.org/ for live status
     echo -e $cBCYA"Retrieving the 13 InterNIC Root DNS Servers from 'https://www.internic.net/domain/named.cache'....."$cBGRA
     curl --progress-bar -o ${CONFIG_DIR}root.hints https://www.internic.net/domain/named.cache     # v1.17
     echo -en $cRESET
}
Backup_unbound_config() {
    local NOW=$(date +"%Y%m%d-%H%M%S") # v1.27
    [ -z "$2" ] && local BACKUP_CONFIG=$NOW"_unbound.conf" || { [ -z "$(echo $2 | grep -E ".conf$")" ] && local BACKUP_CONFIG=$2".conf" || local BACKUP_CONFIG=$2 ; }   # v3.23
    cp -p ${CONFIG_DIR}unbound.conf /opt/share/unbound/configs/$BACKUP_CONFIG
    if [ "$1" == "msg" ];then
        echo -e $cRESET"\nActive $cBMAG'unbound.conf' ${cRESET}backed up to $cBMAG'/opt/share/unbound/configs/$BACKUP_CONFIG'"$cRESET
        #printf "%bActive '%bunbound.conf%b' backup up to '%b%s%b'" "$cRESET" "$cBMAG" "$cRESET" "$cBMAG" "/opt/share/unbound/configs/$BACKUP_CONFIG" "$cRESET"
    else
        echo $BACKUP_CONFIG
    fi
    return 0
}
# shellcheck disable=SC2120
Check_config_add_and_postconf() {

    local VERBOSE="Y"                                                       # v3.09

    [ -n "$1" ] && local VERBOSE="N"                                        # v3.09

    # If GUI 'server:' directives are to be included, insert 'include: "/opt/share/unbound/configs/unbound.conf.addgui"' BEFORE 'include: "/opt/share/unbound/configs/unbound.conf.add   # v3.07
    local CONFIG_ADD="/opt/share/unbound/configs/unbound.conf.addgui"  # v3.07
    if [ -f $CONFIG_ADD ];then
       if [ -f /opt/share/unbound/configs/unbound.conf.add ];then                                      # v3.08
           local CONFIG_ADD="/opt/share/unbound/configs/unbound.conf.add"   # Temporary override for purposes of delete function...
           # Delete existing 'include: "/opt/share/unbound/configs/unbound.conf.add"'
           [ "$VERBOSE" == "Y" ] && echo -e $cBCYA"Removing $cBGRE'include: \"$CONFIG_ADD\" ${cBCYA}from '${CONFIG_DIR}unbound.conf'"$cBGRA   # v3.07
           local TO="$(awk '/^include.*\/opt\/share\/unbound\/configs\/unbound\.conf\.add\"/ {print NR}' "${CONFIG_DIR}unbound.conf")";local FROM=$((TO - 1))
           [ -n "$TO" ] && sed -i "$FROM,$TO d" ${CONFIG_DIR}unbound.conf                     # v3.08 v3.07
           local CONFIG_ADD="/opt/share/unbound/configs/unbound.conf.addgui"   # Reinstate '.addgui
       fi
       [ "$VERBOSE" == "Y" ] && echo -e $cBCYA"Adding $cBGRE'include: \"$CONFIG_ADD\" ${cBCYA}to '${CONFIG_DIR}unbound.conf'"$cBGRA
       [ -z "$(grep "^include.*\"$CONFIG_ADD\"" ${CONFIG_DIR}unbound.conf)" ] && echo -e "server:\ninclude: \"$CONFIG_ADD\"\t\t# Custom server directives" >>  ${CONFIG_DIR}unbound.conf
    fi

    # If Custom 'server:' directives are to be included, append the 'include: "/opt/share/unbound/configs/unbound.conf.add"' directive so values will override any previous ones # v2.18 Hotfix
    local CONFIG_ADD="/opt/share/unbound/configs/unbound.conf.add"              # v2.10
    if [ -f $CONFIG_ADD ];then
        [ "$VERBOSE" == "Y" ] && echo -e $cBCYA"Adding $cBGRE'include: \"$CONFIG_ADD\" ${cBCYA}to '${CONFIG_DIR}unbound.conf'"$cBGRA
        [ -z "$(grep "^include.*\"$CONFIG_ADD\"" ${CONFIG_DIR}unbound.conf)" ] && echo -e "server:\ninclude: \"$CONFIG_ADD\"\t\t\t# Custom server directives" >>  ${CONFIG_DIR}unbound.conf    # v2.18 Hotfix @juched v2.10
    fi

    # If Custom 'server:' local host directives are to be included, append the 'include: "/opt/share/unbound/configs/unbound.conf.localhosts"'
    local CONFIG_ADD="/opt/share/unbound/configs/unbound.conf.localhosts"              # v2.10
    if [ -f $CONFIG_ADD ];then
        [ "$VERBOSE" == "Y" ] && echo -e $cBCYA"Adding $cBGRE'include: \"$CONFIG_ADD\" ${cBCYA}to '${CONFIG_DIR}unbound.conf'"$cBGRA
        [ -z "$(grep "^include.*\"$CONFIG_ADD\"" ${CONFIG_DIR}unbound.conf)" ] && echo -e "server:\ninclude: \"$CONFIG_ADD\"\t\t# Custom server directives" >>  ${CONFIG_DIR}unbound.conf    # v2.18 Hotfix @juched v2.10
    fi

    # If Custom 'server:' views: directives are to be included, append the 'include: "/opt/share/unbound/configs/unbound.conf.views"'
    local CONFIG_ADD="/opt/share/unbound/configs/unbound.conf.views"
    if [ -f $CONFIG_ADD ];then
        [ "$VERBOSE" == "Y" ] && echo -e $cBCYA"Adding $cBGRE'include: \"$CONFIG_ADD\" ${cBCYA}to '${CONFIG_DIR}unbound.conf'"$cBGRA
        [ -z "$(grep "^include.*\"$CONFIG_ADD\"" ${CONFIG_DIR}unbound.conf)" ] && echo -e "server:\ninclude: \"$CONFIG_ADD\"\t\t# Custom server directives" >>  ${CONFIG_DIR}unbound.conf    # v2.18 Hotfix @juched v2.10
    fi

    # If Custom 'server:' Safe Search (domain redirect) directives e.g. redirect "google.com" to "forcesafesearch.google.com" are to be included, append the 'include: "/opt/share/unbound/configs/unbound.conf.safesearch"'
    local CONFIG_ADD="/opt/share/unbound/configs/unbound.conf.safesearch"   # v3.22
    if [ -f $CONFIG_ADD ];then
        [ "$VERBOSE" == "Y" ] && echo -e $cBCYA"Adding $cBGRE'include: \"$CONFIG_ADD\" ${cBCYA}to '${CONFIG_DIR}unbound.conf'"$cBGRA
        [ -z "$(grep "^include.*\"$CONFIG_ADD\"" ${CONFIG_DIR}unbound.conf)" ] && echo -e "server:\ninclude: \"$CONFIG_ADD\"\t\t# Custom server directives" >>  ${CONFIG_DIR}unbound.conf    # v3.22 @Somewhereovertherainbow
    fi

    local POSTCONF_SCRIPT="/opt/share/unbound/configs/unbound.postconf"
    if [ -f $POSTCONF_SCRIPT ];then
        [ "$VERBOSE" == "Y" ] && echo -e $cBCYA"Executing $cBGRE'$POSTCONF_SCRIPT'"$cBGRA
        sh $POSTCONF_SCRIPT "${CONFIG_DIR}unbound.conf"
    fi

}
Customise_config() {

     echo -e $cBCYA"Generating unbound-anchor 'root.key'....."$cBGRA            # v1.07

    # Suppress
    # [1635840435] libunbound[16108:0] error: udp connect failed: Cannot assign requested address for 2001:503:c27::2:30 port 53
    # [1635840435] libunbound[16108:0] error: udp connect failed: Cannot assign requested address for 2001:dc3::35 port 53
    # [1635840436] libunbound[16108:0] error: udp connect failed: Cannot assign requested address for 2001:7fe::53 port 53
    # [1635840436] libunbound[16108:0] error: udp connect failed: Cannot assign requested address for 2001:500:12::d0d port 53
    # [1635840436] libunbound[16108:0] error: udp connect failed: Cannot assign requested address for 2001:dc3::35 port 53
    # [1635840436] libunbound[16108:0] error: udp connect failed: Cannot assign requested address for 2001:500:200::b port 53
    # [1635840436] libunbound[16108:0] error: udp connect failed: Cannot assign requested address for 2001:503:ba3e::2:30 port 53
    # [1635840436] libunbound[16108:0] error: udp connect failed: Cannot assign requested address for 2001:dc3::35 port 53
    # [1635840436] libunbound[16108:0] error: udp connect failed: Cannot assign requested address for 2001:503:c27::2:30 port 53

     /opt/sbin/unbound-anchor -a ${CONFIG_DIR}root.key
     #/opt/sbin/unbound-anchor -a ${CONFIG_DIR}root.key 2>/dev/null
     # or use IPv4 ONLY flag '-4'
     [ "$(nvram get ipv6_service)" == "disabled" ] && /opt/sbin/unbound-anchor -4 -a ${CONFIG_DIR}root.key || /opt/sbin/unbound-anchor -a ${CONFIG_DIR}root.key


     Get_RootDNS                                                                # v1.24                                                             # v1.24 Now a function

     # InterNIC Root DNS Servers cron job
     [ ! -f /jffs/scripts/services-start ] && { echo "#!/bin/sh" > /jffs/scripts/services-start; chmod +x /jffs/scripts/services-start; }           # v1.18
     if [ -z "$(grep "root_servers" /jffs/scripts/services-start)" ];then       # v1.18
        echo -e $cBCYA"Creating Daily (04:12) InterNIC Root DNS Servers cron job "$cRESET   # v1.24
        $(Smart_LineInsert "/jffs/scripts/services-start" "$(echo -e "cru a root_servers  \"12 4 * * * curl -o \/opt\/var\/lib\/unbound\/root\.hints https://www.internic.net/domain/named.cache\"\t# unbound_manager")" )  # v1.24
        cru a root_servers  "12 4 * * * curl -o /opt/var/lib/unbound/root.hints https://www.internic.net/domain/named.cache"    # v1.24 Daily again @04:12  :-( muppet!
        chmod +x /jffs/scripts/services-start
     fi

    if [ "$KEEPACTIVECONFIG" != "Y" ];then                              # v1.27
         echo -e $cBCYA"Retrieving Custom unbound configuration"$cBGRA
         if [ "$USE_GITHUB_DEV" != "Y" ];then                           # v2.06
            download_file $CONFIG_DIR unbound.conf martineau            # v2.04
         else
            download_file $CONFIG_DIR unbound.conf martineau dev        # v2.06
         fi
    else
         echo -e $cBCYA"Custom unbound configuration download ${cBRED}skipped$cRESET ('${cBMAG}keepconfig$cRESET' specified)"$cBGRA
    fi

    download_file /opt/share/unbound/configs doc/example.conf.in nlnetlabs  # v3.06

     # Entware creates a traditional '/opt/etc/unbound' directory structure so spoof it         # v1.07
     #[ -f /opt/etc/unbound/unbound.conf ] && mv /opt/etc/unbound/unbound.conf /opt/etc/unbound/unbound.conf.Example    # v2.05
     ln -s /opt/var/lib/unbound/unbound.conf /opt/etc/unbound/unbound.conf 2>/dev/null

     chown nobody /opt/var/lib/unbound                                  # v1.10

     if [ "$KEEPACTIVECONFIG" != "Y" ];then                             # v1.27

         local TAG="Date Loaded by unbound_manager "$(date)")"

         # Timestamp 'unbound.conf'
         [ -n "$(sed -n '1{/Date Loaded/p};q' /opt/var/lib/unbound/unbound.conf ${CONFIG_DIR}unbound.conf)" ] && sed -i "1s/Date.*Loaded.*$/$TAG/" ${CONFIG_DIR}unbound.conf

         # Backup the config to easily restore it 'rl reset[.conf]'
         cp -f ${CONFIG_DIR}unbound.conf /opt/share/unbound/configs/reset.conf      # v1.19
     fi

     echo -e $cBCYA"Checking IPv6....."$cRESET                          # v1.10
     if [ "$(nvram get ipv6_service)" != "disabled" ];then
         echo -e $cBCYA"Customising unbound IPv6 configuration....."$cRESET
            # integration IPV6
            #do-ip6: no                    # This is the default; must be explicitly commented out if IPv6 group ENABLED
            #do-ip6: yes                   #@From:
            #edns-buffer-size: 1232        # IPv6 1232 to override IPv4 1472 @Linux_chemist
            #interface: ::0
            #access-control: ::0/0 refuse
            #access-control: ::1 allow
            #private-address: fd00::/8
            #private-address: fe80::/10    #@@To:
         Edit_config_options "private-address: ::/0" "comment"                     # v3.21 Remove dropping of ALL IPv6 responses
         Edit_config_options "edns-buffer-size: 1472" "comment"                    # v3.21 Remove IPv4 default @Linux_chemist
         Edit_config_options "do-ip6: yes" "private-address: fe80::" "uncomment"   # v1.28
         Edit_config_options "do-ip6: no" "comment"                                # v1.28 Remove default IPv6

     fi

     # TLS Certificate usage https://www.ctrl.blog/entry/unbound-tls-forwarding.html
     # For @john9572's fork, 'tls-cert-bundle:' is in a different location
     #  e.g. http://www.snbforums.com/threads/release-v3-22.69886/post-662313

     #       Merlin:            tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt" # v1.01 as per @dave14305 minimal config
     #       @john9572 Fork:    tls-cert-bundle: "/tmp/mnt/Entware/entware/etc/ssl/certs/ca-certificates.crt" # 1.13 @john9572 Fork @Make Wifi Great Again
     if [ "$(/bin/uname -o)" == "ASUSWRT-Merlin-LTS" ];then                  # v3.23
        sed -i "/^tls-cert-bundle:/ s~[^ ]*[^ ]~\"/tmp/mnt/Entware/entware/etc/ssl/certs/ca-certificates.crt\"~2" ${CONFIG_DIR}unbound.conf # v3.23
        sed -i "/^tls-cert-bundle:/ s~#.*$~# 1\.13 \@john9572 Fork \@Make Wifi Great Again~"${CONFIG_DIR}unbound.conf   # v3.23
     fi

     echo -e $cBCYA"Customising unbound configuration Options:"$cRESET

     Check_config_add_and_postconf                              # Allow users to customise 'unbound.conf'

}
Restart_unbound() {

    local NOCACHE=$1
    local STATUS=0

    # v2.12 moved to Restart_unbound() function

    if [ "$2" != "nochk" ];then                                                     # v2.13
        echo -e ${cBCYA}$(date "+%H:%M:%S")" Checking 'unbound.conf' etc. for valid Syntax....."        # v3.23
        local CHK_Config_Syntax="$(unbound-checkconf $CHECKTHIS 2>&1)"                  # v3.23 v2.03
        if [ -z "$(echo "$CHK_Config_Syntax" | grep -o "no errors in" )" ];then             # v2.03
            echo -e $cBRED"\a"
            unbound-checkconf ${CONFIG_DIR}unbound.conf         # v2.03
            echo -e $cBRED"\n***ERROR ${cRESET}requested re(Start) of unbound ABORTed! - use option ${cBMAG}'vx'$cRESET to correct $cBMAG'unbound.conf'$cRESET or ${cBMAG}'rl'${cRESET} to load a valid configuration file"$cBGRE
            SayT "***ERROR requested re(Start) of unbound ABORTed! - use option 'vx'$cRESET to correct 'unbound.conf' or ${cBMAG}'rl' to load a valid configuration file"   # v2.14
            STATUS=1
        fi
        # v3.23 non-Fatal Warning errors are now reported e.g. duplicates in include files such as the Adblock domain names
        # e.g.
        #       [1614273457] unbound-checkconf[27734:0] warning: duplicate local-zone 76gmail.com.
        #       unbound-checkconf: no errors in /opt/var/lib/unbound/unbound.conf
        #
        if [ -n "$(echo "$CHK_Config_Syntax" | grep -o "warning: duplicate")" ];then    # v3.23
            local DUPLICATES=$(echo "$CHK_Config_Syntax" | awk '{$1="";print $0}' | sed "s~\n~; ~; s~\(no errors.*\)~\\${cRESET}- \\${cBGRE}\1~")           # v3.23
            echo -e $cBYEL"\a\n\tNon-Fatal: "$DUPLICATES"\n"$cRESET
            SayT "Non-Fatal: "$DUPLICATES                                               # v3.23
        fi

       # Pre-UP checks...... 'outgoing-interface' and 'interface:' will cause unbound to fail if they cannot bind

    fi

    if [ $STATUS -eq 0 ];then                                                           # v3.23

        # Don't save the cache if unbound is UP and 'rs nocache' requested.
        if [ -n "$(pidof unbound)" ] && [ "$NOCACHE" != "nocache" ];then                # v2.11
            Manage_cache_stats "save"                       # v2.11
        else
            # If unbound is DOWN and 'rs nocache' specified then ensure that the cache is not restored
            :
        fi

        #Check_config_add_and_postconf                       # v3.09 v2.15

        echo -e ${cBCYA}$(date "+%H:%M:%S")" Requesting unbound (${cRESET}S61unbound$cBCYA) restart....."$cBGRE
        SayT "Requesting unbound (/opt/etc/init.d/S61unbound$) restart....."            # v3.19
        /opt/etc/init.d/S61unbound restart

        local TAG="Date Loaded by unbound_manager "$(date)")"           # v3.06
        sed -i "1s/Date.*Loaded.*$/$TAG/" ${CONFIG_DIR}unbound.conf     # v3.06

        #Manage_cache_stats "restore"                        # v2.17 v2.11

        if [ -z "$1" ];then                                 # v2.15 If called by 'gen_adblock.sh' then skip the status check
            CHECK_GITHUB=1                                  # v1.27 force a GitHub version check to see if we are OK
            #echo -en $cRESET"\nPlease wait for up to ${cBYEL}10 seconds${cRESET} for status....."$cRESET
            echo -e ${cRESET}${cBCYA}$(date "+%H:%M:%S")" Checking status, please wait..... "$cRESET
            #WAIT=11     # 11 i.e. 10 secs should be adequate?
            WAIT=3                          # v3.00 Hopefully unbound initialization should be valid
            I=0
             while [ $I -lt $((WAIT-1)) ]
                do
                    sleep 1
                    I=$((I + 1))
                    if [ -z "$(pidof unbound)" ];then
                        echo -e $cBRED"\a\n\n\t${aREVERSE}***ERROR unbound went AWOL after $I seconds${cRESET}.....\n\n\t${cBRED}Try option ${cBMAG}'debug'$cRESET and check for unbound.conf or runtime errors!"$cRESET
                        SayT "***ERROR unbound went AWOL after $I seconds.... Try 'unbound -dv' and check for unbound.conf or runtime errors!"
                        STATUS=1
                        break
                    fi
                    [ $I -eq 2 ] && Manage_cache_stats "restore"        # v2.17
                done
            [ -n "$(pidof unbound)" ] && echo -e ${cRESET}${cBCYA}$(date "+%H:%M:%S")" unbound ${cBGRE}OK"$cRESET
        else
            echo -en $cBCYA
        fi
    fi

    return $STATUS
}
Skynet_BANNED_Countries() {

    # @skeal identified Skynet's Country blocks can hinder unbound performance and in some cases block sites e.g. Hulu etc.
    #   [URL="https://www.snbforums.com/threads/release-unbound_manager-manager-installer-utility-for-unbound-recursive-dns-server.61669/page-18#post-550376"]post #346[/URL]
    if [ -f /jffs/scripts/firewall ]; then                          # v2.09 @dave14305 Pull-request
        skynetloc="$(grep -ow "skynetloc=.* # Skynet" /jffs/scripts/firewall-start 2>/dev/null | grep -vE "^#" | awk '{print $1}' | cut -c 11-)"
        skynetcfg="${skynetloc}/skynet.cfg"
        if [ -f "$skynetcfg" ]; then
            # shellcheck disable=SC1090
            . "$skynetcfg"
            # shellcheck disable=SC2154
            [ -n "$countrylist" ] && echo "Y" || echo "N"   # v2.09
        fi
    fi
}
Option_Optimise_Performance() {

     local ANS=$1                                           # v1.20
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ];then
        echo -e "\nDo you want to optimise Performance/Memory parameters? (${cBCYA}YES$cRESET recommended)\n\n\tReply$cBRED 'y'$cBGRE or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     if [ "$ANS" == "y"  ];then
        Optimise_Performance
     else
        [ "$EASYMENU" == "Y" ] && Optimise_Performance "del"    # v3.00
     fi
}
Optimise_Performance() {

        local FN="/jffs/scripts/init-start"

        local Tuning_script="/jffs/addons/unbound/stuning"             # v2.00 v1.15 Would benefit from a meaningful name e.g.'unbound_tuning'

        if [ "$1" != "del" ];then
            echo -e $cBCYA"Customising unbound Performance/Memory 'proc/sys/net' parameters"$cGRA           # v1.15
            download_file /jffs/addons/unbound stuning martineau         # v3.23 v2.02 v2.00
            dos2unix $Tuning_script
            chmod +x $Tuning_script
            [ ! -f $FN ] && { echo "#!/bin/sh" > $FN; chmod +x $FN; }
            if [ -z "$(grep -F "$Tuning_script" $FN | grep -v "^#")" ];then
                $(Smart_LineInsert "$FN" "$(echo -e "sh $Tuning_script start\t\t\t# unbound_manager")" )  # v1.15
            fi
            chmod +x $FN
            echo -e $cBCYA"Applying unbound Performance/Memory tweaks using '$Tuning_script'"$cRESET

            # Enable TCP Fast Open on HND routers
            if [ "$(Is_HND)" == "Y" ];then                  # v2.04
                echo -e $cBGRE"TCP Fast Open ENABLED in '$Tuning_script'"$cRESET
                [ -z "$(grep "tcp_fastopen" "$Tuning_script")" ] && sed -i '/start()/a\\n\t# Enable TCP Fast Open on HND routers \- unbound_manager\n\techo 3 > /proc/sys/net/ipv4/tcp_fastopen\n' $Tuning_script
            fi

            sh $Tuning_script start
        else
             if [ -f $Tuning_script ] || [ -n "$(grep -F "unbound_manager" $FN)" ];then
                echo -e $cBCYA"Deleting Performance/Memory tweaks '$Tuning_script'"
                [ -f $Tuning_script ] && rm $Tuning_script
                sed -i '/#.*unbound_/d' $FN                 # v1.23
             fi
        fi
}
Optimise_CacheSize() {

    case "$1" in
        min)                                                        # v3.10 4M is unbound default
            unbound_Control "ox" "key-cache-size"   "4m"
            sed -i "/^key-cache-size:/ s/[^ ]*[^ ]/\"4m\"/2" ${CONFIG_DIR}unbound.conf
            unbound_Control "ox" "msg-cache-size"   "4m"
            sed -i "/^msg-cache-size:/ s/[^ ]*[^ ]/\"4m\"/2" ${CONFIG_DIR}unbound.conf
            unbound_Control "ox" "rrset-cache-size" "4m"
            sed -i "/^rrset-cache-size:/ s/[^ ]*[^ ]/\"4m\"/2" ${CONFIG_DIR}unbound.conf
            ;;
        calc)
            RESERVED=12582912
            AVAILABLEMEMORY=$((1024 * $( (grep -F MemAvailable /proc/meminfo || grep -F MemTotal /proc/meminfo) | sed 's/[^0-9]//g')))
            if [ $AVAILABLEMEMORY -le $((RESERVED * 2)) ]; then
                echo -e $cBRED"\a\nFree memory less than 25MB - Cache buffers 'msg/key/rrset-cache-size' not changed" >&2
            else
                AVAILABLEMEMORY=$((AVAILABLEMEMORY - RESERVED))
                MSG_CACHE_SIZE=$((AVAILABLEMEMORY / 4))
                # Show in BYTES, although option '?'  will round down to the nearest MB rather than '59.42m' for ease of copy'n'paste
                unbound_Control "ox" "msg-cache-size" "$MSG_CACHE_SIZE"
                unbound_Control "ox" "key-cache-size" "$MSG_CACHE_SIZE"
                RR_CACHE_SIZE=$((AVAILABLEMEMORY / 3))
                unbound_Control "ox" "rrset-cache-size" "$RR_CACHE_SIZE"
            fi
            ;;
        *)
            unbound_Control "ox" "key-cache-size"   "8m"
            sed -i "/^key-cache-size:/ s/[^ ]*[^ ]/\"8m\"/2" ${CONFIG_DIR}unbound.conf
            unbound_Control "ox" "msg-cache-size"   "8m"
            sed -i "/^msg-cache-size:/ s/[^ ]*[^ ]/\"8m\"/2" ${CONFIG_DIR}unbound.conf
            unbound_Control "ox" "rrset-cache-size" "16m"
            sed -i "/^rrset-cache-size:/ s/[^ ]*[^ ]/\"16m\"/2" ${CONFIG_DIR}unbound.conf
            ;;
    esac

}
Enable_Logging() {

    # ONLY called from install_unbound

     local STATUS=1                          # v3.08 Default DISABLE logging after unbound initialises for the first time

     local ANS=$1            # v1.20 v1.07
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ] || [ "$ANS" == "?" ];then         # v3.09
         # v1.16 allows dynamic Enable/Disable from unbound_manager main menu (Options lo/lx)
         #      but the log file needs to exist in the config so unbound will create it - ready to be used
         echo -e "\nDo you want to ENABLE unbound logging? (${cBCYA}NO$cRESET recommended)\n\n\tReply$cBRED 'y'$cBGRE or press ENTER $cRESET to skip" >&2
         read -r "ANS"
     fi

     # v3.09 'verbosity: X' directive is always ENABLED;
     #       we now just explicitly ensure X is always either '0' or '1' during  initial install
     Edit_config_options "verbosity:" "uncomment"                                        # v3.09
     sed -i "/^verbosity:/ s/[^ ]*[^ ]/1/2" ${CONFIG_DIR}unbound.conf                    # v3.09

     if [ "$ANS" == "y"  ];then
         if [ -z "$(grep -oE "#[[:space:]]*verbosity:" ${CONFIG_DIR}unbound.conf)" ];then       # v3.10 Fix v1.27
            Edit_config_options "log-queries:"         "uncomment"     # v3.08
            #Edit_config_options "log-replies:"         "uncomment"     # v3.08
            local STATUS=0    # retain logging AFTER unbound is UP
         fi
     else
        # For the initial install, ensure we log only the first 4-5 initialisation messages
        # v3.09 ensure after the first 4-5 lines are logged, logging is DISABLED
        :
     fi

     echo $STATUS

}
Generate_unbound_SSL_Keys() {

    # unbound-control-setup uses 'setup in directory /opt/var/lib/unbound' ???
    # generating unbound_server.key
    # Generating RSA private key, 3072 bit long modulus
    # ....................................++++
    # .......................................................................................................................................................................++++
    # e is 65537 (0x10001)
    # generating unbound_control.key-file
    echo -e $cBCYA"Initialising 'unbound-control-setup' to generate SSL Keys"$cBGRA
    unbound-control-setup
}
Manage_Extended_stats() {

    # v2.15 moved to function
    local CONFIG_VARIABLE="extended-statistics"

    [ "$1" == "s+" ] && local CONFIG_VALUE="yes" || local CONFIG_VALUE="no"

    local RESULT="$($UNBOUNCTRLCMD set_option $CONFIG_VARIABLE $CONFIG_VALUE)"
    [ "$RESULT" == "ok" ] && local COLOR=$cBGRE || local COLOR=$cBRED
    echo -e $cRESET"$UNBOUNCTRLCMD set_option $cBMAG'$CONFIG_VARIABLE $CONFIG_VALUE'$COLOR $RESULT"  2>&1

    if [ "$(Get_unbound_config_option "extended-statistics")" == "yes" ];then # v2.14
        if [ "$1" == "s-" ];then
            Edit_config_options "extended-statistics:"  "comment"
            #echo -e $cBMAG"\n\t'unbound.conf' set '$CONFIG_VARIABLE: $CONFIG_VALUE'"$cRESET
        fi
    else
        if [ "$1" == "s+" ];then                                # v2.14
            Edit_config_options "extended-statistics:"  "uncomment"
            #echo -e $cBMAG"\n\t'unbound.conf' set '$CONFIG_VARIABLE: $CONFIG_VALUE'"$cRESET
        fi
    fi
}
unbound_Control() {

    # Each call to unbound-control takes upto 2 secs;  use the -c' parameter            # v1.27
    #unbound-control -q status
    #if [ "$?" != 0 ]; then
    if [ -z "$(pidof unbound)" ];then
        [ "$NOMSG" != "NOMSG" ] && { echo -e $cBRED"\a\t***ERROR unbound NOT running! - option unavailable" 2>&1; return 1; }    # v2.15 v1.26
    fi
    #fi

    #[ -z "$" ] && { echo -e $cBRED"\a***ERROR unbound not installed!" 2>&1; return 1; }

    local RESET="_noreset"                  # v1.08
    local RETVAL=$3                         # v2.04
    local ADDFILTER=

    if [ $(echo "$@" | wc -w ) -eq 2 ];then
        local ADDFILTER=$(echo "$@" | awk '{print $2}')               # v2.07
    fi

    case $1 in

        dump|save|load|rest|delete)          # v2.12 v2.11

            local FN="/opt/share/unbound/configs/cache.txt"

            case "$1" in
                dump|save)
                    $UNBOUNCTRLCMD dump_cache > $FN
                    local TIMESTAMP=$(date -r $FN "+%Y-%m-%d %H:%M:%S")   # v3.08
                    local CACHE_MEM_MSG=$(unbound-control stats_noreset | grep "msg.cache" | cut -d'=' -f2)
                    local CACHE_MEM_RRSET=$(unbound-control stats_noreset | grep "rrset.cache" | cut -d'=' -f2)
                    local DUMPCACHE_MEM_MSG=$(grep -c "^msg" $FN)
                    local DUMPCACHE_MEM_RRSET=$(grep -c "^;rrset" $FN)
                    echo -e ${cBCYA}$(date "+%H:%M:%S")" Saving ${cRESET}unbound cache$cBCYA to $cBGRE'/opt/share/unbound/configs/cache.txt'"$cRESET "msg.cache="$CACHE_MEM_MSG"/"$DUMPCACHE_MEM_MSG "rrset.cache="$CACHE_MEM_RRSET"/"$DUMPCACHE_MEM_RRSET 2>&1   # v3.08
                    SayT "unbound cache SAVED to '"$FN"' - BEWARE, file will be DELETED on first RELOAD" $TIMESTAMP "msg.cache="$CACHE_MEM_MSG"/"$DUMPCACHE_MEM_MSG "rrset.cache="$CACHE_MEM_RRSET"/"$DUMPCACHE_MEM_RRSET
                ;;
                load|rest)
                    if [ -s $FN ];then # v2.13 Change '-f' ==> '-s' (Exists AND NOT Empty!)
                        local TIMESTAMP=$(date -r $FN "+%Y-%m-%d %H:%M:%S")   # v3.08
                        local CACHE_MEM_MSG=$(unbound-control stats_noreset | grep "msg.cache" | cut -d'=' -f2)
                        local CACHE_MEM_RRSET=$(unbound-control stats_noreset | grep "rrset.cache" | cut -d'=' -f2)
                        local DUMPCACHE_MEM_MSG=$(grep -c "^msg" $FN)
                        local DUMPCACHE_MEM_RRSET=$(grep -c "^;rrset" $FN)
                        echo -e ${cBCYA}$(date "+%H:%M:%S")" Restoring ${cRESET}unbound cache$cBCYA from $cBGRE'"$FN"'"$cRESET "("$TIMESTAMP")" "msg.cache="$CACHE_MEM_MSG"/"$DUMPCACHE_MEM_MSG "rrset.cache="$CACHE_MEM_RRSET"/"$DUMPCACHE_MEM_RRSET    # v3.08 v2.12
                        $UNBOUNCTRLCMD load_cache < $FN 1>/dev/null
                        SayT "unbound cache RESTORED from '"$FN"' ("$TIMESTAMP")" "msg.cache="$CACHE_MEM_MSG"/"$DUMPCACHE_MEM_MSG "rrset.cache="$CACHE_MEM_RRSET"/"$DUMPCACHE_MEM_RRSET
                        rm $FN 2>/dev/null                              # as per @JSewell suggestion as file is in plain text
                    fi
                ;;
                delete)
                    if [ -f $FN ];then
                        rm $FN
                        echo -e $cRESET"unbound cache file $cBGRE'$FN'$cRESET DELETED"$cRESET  2>&1
                    fi
                ;;
            esac
        ;;
        lookup*)                                                        # v2.11
            local DOMAIN=$(echo "$@" | awk '{print $2}')
            $UNBOUNCTRLCMD lookup $DOMAIN
        ;;
        "s+"|"s-")                                                      # v1.18
            Manage_Extended_stats "$menu1"                              # v2.15
        ;;
        sgui*)                                                          # v2.14 [ dev | all | uninstall [stats] ]

            local ARG2=                                                 # v2.16
            if [ "$(echo "$menu1" | wc -w)" -ge 3 ];then                # v2.16
                local ARG2="$(printf "%s" "$menu1" | cut -d' ' -f3)"
            fi

            local ARG=
            if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                local ARG="$(printf "%s" "$menu1"  | cut -d' ' -f2)"    # v2.16
            fi

            # @juched's GUI stats Graphical TAB requires 'extended-statistics: yes' and firmware must support 'addons'
            if [ "$(Unbound_Installed)" == "Y" ] && [ -n "$(grep -F "extended-statistics" ${CONFIG_DIR}unbound.conf)" ];then
                if [ "$ARG" != "uninstall" ];then
                    if [ -n "$(nvram get rc_support | grep -o "am_addons")" ];then  # v2.18 Hotfix v2.15

                        Manage_Extended_stats "s+"                      # v2.15 Ensure ENABLED
                        echo -en $cRESET                                # v2.15

                        if [ "$ARG2" == "all" ];then                                     # v3.12
                           echo -e $cBCYA"ALL logging/tracking options ENABLED (Log queries/Replies and AD Blocks"
                           [ -n "$(grep -E "^#log-queries:" ${CONFIG_DIR}unbound.conf)" ] && Edit_config_options "log-queries:"               "uncomment"   # v3.12
                           [ -n "$(grep -E "^#log-replies:" ${CONFIG_DIR}unbound.conf)" ] && Edit_config_options "log-replies:"               "uncomment"   # v3.12
                           [ -n "$(grep -E "^#log-local-actions:" ${CONFIG_DIR}unbound.conf)" ] && Edit_config_options "log-local-actions:"   "uncomment"   # v3.12
                        fi

                        AUTO_REPLY7="y"
                        Option_GUI_Stats_TAB          "$AUTO_REPLY7"    "$ARG"      # v3.00 Allow use of juched's 'dev' Github
                        local RC=$?

                        [ $RC -eq 0 ] && Check_GUI_NVRAM
                    else
                        echo -e $cBRED"\a\n\tFirmware does NOT support GUI TAB 'addons'?"$cRESET   # v2.15
                    fi
                else
                    [ "$ARG2" == "stats" ] && Manage_Extended_stats "s-"        # v2.16 DISABLE requested
                    GUI_Stats_TAB "uninstall"
                    local RC=0
                fi
            else
                echo -e $cBRED"\a\n\tunbound NOT installed! or 'extended-statistics:' template NOT defined in 'unbound.conf'?"$cRESET   # v2.15
            fi
            ;;
        sa*)                                                            # v2.07
            if [ -n "$(echo "$@" | sed -n "s/^.*filter=//p")" ];then    # v2.07 allow very basic 'or' 'filtering'
                local FILTER=$(echo "$@" | sed -n "s/^.*filter=//p" | awk '{print $1}') # v2.07
                # NOTE: 's+' aka 'extended-statistics: yes' must be active if you expect 'sa filter=thread|total' to work!
                $UNBOUNCTRLCMD stats$RESET  | sort | grep -E "$FILTER" | column # v2.07
            else
                $UNBOUNCTRLCMD stats$RESET  | column
            fi
        ;;
        s|s*)                                                               # v2.07
            # xxx-cache.count values won't be shown without 'extended-statistics: yes' see 's+'/'s-' menu option

            # If multi-threads then calculate cache hits per thread           # v3.10
            NUMTHREADS=$(unbound_Control "oq" "num-threads" "value")    # v3.10

            # If multi-threads defined then skip the original 'Average' display in lieu of the individual Thead reports
            if [ $NUMTHREADS -eq 1 ];then                                  # v3.10
                echo -en $cYEL
                $UNBOUNCTRLCMD stats$RESET | grep -E "total\.|cache\.count"  | column          # v1.08
                # Calculate %Cache HIT success rate
                local TOTAL=$($UNBOUNCTRLCMD stats$RESET | grep -oE "total.num.queries=.*" | cut -d'=' -f2)
                local CACHEHITS=$($UNBOUNCTRLCMD stats$RESET | grep -oE "total.num.cachehits=.*" | cut -d'=' -f2)
                if [ -n "$TOTAL" ] && [ $TOTAL -gt 0 ];then                 # v2.00
                    local PCT="$(Calculate_Percent "$TOTAL" "$CACHEHITS")"  # v3.07
                else
                    local PCT=0                                             # v2.00
                fi

                printf "\n%bSummary: Cache Hits success=%b%3.2f%%" "$cBCYA" "$cRESET" "$PCT"

            else
                echo -en $cYEL

                # grep cache $LOGFILE | tail -n $NUMTHREADS | awk '
                # {
                  # printf("   Thread %d=%02.2f%%",$12,($15/$13*100))
                # }'

                local THREAD=0
                while [ $THREAD -lt $NUMTHREADS ];do                        # v3.10
                    echo -en $cYEL
                    [ $THREAD -gt 0 ] && echo -e
                    $UNBOUNCTRLCMD stats$RESET | grep -E "thread$THREAD\.|cache\.count"  | column
                    local TOTAL=$($UNBOUNCTRLCMD stats$RESET | grep -oE "thread$THREAD.num.queries=.*" | cut -d'=' -f2)
                    local CACHEHITS=$($UNBOUNCTRLCMD stats$RESET | grep -oE "thread$THREAD.num.cachehits=.*" | cut -d'=' -f2)
                    if [ -n "$TOTAL" ] && [ $TOTAL -gt 0 ];then
                        local PCT="$(Calculate_Percent "$TOTAL" "$CACHEHITS")"
                    else
                        local PCT=0
                    fi
                    printf "\n%bThread $THREAD Summary: Cache Hits success=%b%3.2f%%\n" "$cBCYA" "$cRESET" "$PCT"

                    THREAD=$((THREAD + 1))
                done
            fi

            if [ -n "$ADDFILTER" ];then                                 # v2.07 allow display of additional stat value(s)
                # NOTE: 's+' aka 'extended-statistic[CODE][/CODE]s: yes' must be ACTIVE if you expect 's thread' to work!
                echo -e "\n"
                $UNBOUNCTRLCMD stats$RESET  | grep -E "$ADDFILTER" | column
            fi
        ;;
        oq|oq*)
            local CONFIG_VARIABLE
            if [ $(echo "$@" | wc -w ) -eq 1 ];then
                echo -e "\nEnter option name or press$cBGRE [Enter] $cRESET to skip"
                read -r "CONFIG_VARIABLE"
            else
                CONFIG_VARIABLE=$(echo "$@" | awk '{print $2}')
            fi
            if [ "$CONFIG_VARIABLE" != ""  ];then
                local RESULT="$($UNBOUNCTRLCMD get_option $CONFIG_VARIABLE)"
                if [ -z "$RETVAL" ];then                                # v2.04
                    [ -z "$(echo "$RESULT" | grep -ow "error" )" ] && echo -e $cRESET"unbound-control $cBMAG'$CONFIG_VARIABLE'$cRESET $cBGRE'$RESULT'"  2>&1 || echo -e $cRESET"unbound-control get_option $cBMAG'$CONFIG_VARIABLE:'$cBRED $RESULT" 2>&1
                else
                    echo "$RESULT"      # v2.04
                    return              # v2.04
                fi
            fi
            echo -en $cRESET 2>&1
        ;;
        ox|ox*)                                                         # v1.16
            local CONFIG_VARIABLE
            if [ "$(echo $@ | wc -w)" -eq 1 ];then
                echo -e "\nEnter option name or press$cBGRE [Enter]$cRESET to skip"
                read -r "CONFIG_VARIABLE" "CONFIG_VALUE"
            else
                CONFIG_VARIABLE=$(echo "$@" | awk '{print $2}')
                CONFIG_VALUE=$(echo "$@" | awk '{print $3}')
            fi

            if [ -n "$CONFIG_VARIABLE" ] && [ -n "$CONFIG_VALUE" ];then
                local RESULT="$($UNBOUNCTRLCMD set_option $CONFIG_VARIABLE $CONFIG_VALUE)"
                [ "$RESULT" == "ok" ] && local COLOR=$cBGRE || COLOR=$cBRED
                echo -e $cRESET"$UNBOUNCTRLCMD set_option $cBMAG'$CONFIG_VARIABLE $CONFIG_VALUE'$COLOR $RESULT"  2>&1
            fi
            echo -en $cRESET 2>&1
        ;;
        fs)
            $UNBOUNCTRLCMD flush_stats
        ;;
        q?)
            $UNBOUNCTRLCMD
        ;;
    esac

}
Install_Entware_opkg() {

        echo -en $cBGRA 2>&1
        if opkg install $1; then
            echo -e $cBGRE"Entware package '$1' successfully installed" 2>&1
            return 0
        else
            echo -e $cBRED"***ERROR occurred updating Entware package '$1'" 2>&1
            return 1
        fi

}
Script_alias() {

        if [ "$1" == "create" ];then
            # Create alias 'unbound_manager' for '/jffs/addons/unbound/unbound_manager.sh'  # v1.22
            rm -rf "/opt/bin/unbound_manager" 2>/dev/null                                   # v2.01
            if [ -d "/opt/bin" ] && [ ! -L "/opt/bin/unbound_manager" ]; then
                echo -e $cBGRE"Creating 'unbound_manager' alias" 2>&1
                ln -s /jffs/addons/unbound/unbound_manager.sh /opt/bin/unbound_manager    # v2.00 v1.04
            fi
        else
            # Remove Script alias - why?
            echo -e $cBCYA"Removing 'unbound_manager' alias" 2>&1
            rm -rf "/opt/bin/unbound_manager" 2>/dev/null
        fi
}
Check_SWAP() {

    local SWAPSIZE=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
    [ $SWAPSIZE -gt 0 ] && { echo $SWAPSIZE; return 0;} || { echo $SWAPSIZE; return 1; }
}
update_installer() {

    local UPDATED=1         # 0=Updated; 1=NOT Updated              # v1.18

    if [ "$1" == "uf" ] || [ "$localmd5" != "$remotemd5" ]; then
        if [ "$1" == "uf" ] || [ "$( awk '{print $1}' /jffs/addons/unbound/unbound_manager.md5)" != "$remotemd5" ]; then # v2.00 v1.18
            echo 2>&1

            [ "$2" != "dev" ] && local DEV= || local DEV="dev"          # v3.00

            download_file /jffs/addons/unbound unbound_manager.sh martineau "$DEV"            # v3.00 v2.00

            printf '\n%bunbound Manager UPDATE Complete! %s\n' "$cBGRE" "$remotemd5" 2>&1
            localmd5="$(md5sum "$0" | awk '{print $1}')"
            echo $localmd5 > /jffs/addons/unbound/unbound_manager.md5        # v2.00 v1.18
            UPDATED=0
        else
            echo -e $cRED_"\a\nScript update download DISABLED pending Push request to Github"$cRESET >&2
        fi
    else
        printf '\n%bunbound_manager.sh is already the latest version. %s\n' "$cBMAG" "$localmd5"
    fi

    echo -e $cRESET 2>&1

    return $UPDATED
}
remove_existing_installation() {

        echo -e $cBCYA"\nUninstalling unbound"$cRESET

        # Kill unbound process
        pidof unbound | while read -r "spid" && [ -n "$spid" ]; do
            echo -e $cBCYA"KILLing unbound PID=$spid"$cBRED             # v1.07
            kill "$spid"
        done

        # InterNIC Root DNS Servers cron job                            # v1.18
        if grep -qF "root_servers" /jffs/scripts/services-start; then
            echo -e $cBCYA"Removing InterNIC Root DNS Servers cron job"$cRESET
            sed -i '/root_servers/d' /jffs/scripts/services-start
        fi
        cru d root_servers 2>/dev/null

        # Remove Ad and Tracker cron job /jffs/scripts/services-start   # v1.07
        if grep -qF "gen_adblock" /jffs/scripts/services-start; then
            echo -e $cBCYA"Removing Ad and Tracker Update cron job"$cRESET
            sed -i '/gen_adblock/d' /jffs/scripts/services-start
        fi
        cru d adblock 2>/dev/null

        # Remove @juched's DNS Firewall
        if grep -qF "Unbound_RPZ" /jffs/scripts/services-start; then
            echo -e $cBCYA"@juched's"$cRESET  $(DNS_Firewall "disable") # v3.02
        fi

        # Remove @juched's Graphical Statistics GUI TAB                 # v3.00 HotFix
        if [ -f /tmp/menuTree.js ] && [ -n "$(grep -i "Unbound" /tmp/menuTree.js)" ];then
            echo -e $cBCYA"@juched's"$cRESET $(GUI_Stats_TAB "uninstall") # v3.00 HotFix
        fi

        # Remove YouTube Video Ad cron job /jffs/scripts/services-start # v3.14
        if grep -qF "gen_ytadblock" /jffs/scripts/services-start; then  # v3.14
            echo -e $cBCYA"Removing YouTube Video Ad Blocker Update cron job"$cRESET
            sed -i '/gen_ytadblock/d' /jffs/scripts/services-start      # v3.14
        fi

        cru d ytadblock 2>/dev/null                                     # v3.11

        # Remove 3rd Party scripts
        sed -i '/[Uu]nbound_/d' /jffs/scripts/services-start            # v2.18 HotFix
        sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /jffs/scripts/services-start   # v3.23 Strip trailing blank lines
        sed -i '/[Uu]nbound_/d' /jffs/scripts/service-event             # v2.18 HotFix
        sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /jffs/scripts/service-event    # v3.23 Strip trailing blank lines

        # Remove new-style Unbound start-up triggered by service diskmon    # v3.23 @dave14305
        sed -i '/[Uu]nbound_/d' /jffs/scripts/service-event-end        # v3.23
        sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /jffs/scripts/service-event-end    # v3.23 Strip trailing blank lines

        echo -en $cRESET

        mv /opt/etc/unbound/unbound.conf.Example /opt/etc/unbound/unbound.conf 2>/dev/null

        # Remove the unbound package
        Chk_Entware unbound
        if [ "$READY" -eq "0" ]; then
            echo -e $cBCYA"Existing unbound package found. Removing unbound"$cBGRA
            if opkg --force-depends --force-removal-of-dependent-packages remove $ENTWARE_UNBOUND; then echo -e $cBGRE"unbound Entware packages '$ENTWARE_UNBOUND' successfully removed"; else echo -e $cBRED"\a\t***Error occurred when removing unbound"$cRESET; fi # v2.07 v1.15
            #if opkg remove haveged; then echo "haveged successfully removed"; else echo "Error occurred when removing haveged"; fi
            #if opkg remove coreutils-nproc; then echo "coreutils-nproc successfully removed"; else echo "Error occurred when removing coreutils-nproc"; fi
            [ -n "$(which jitterentropy-rngd)" ] && opkg remove haveged >/dev/null  # v3.23 just in case we previously installed pre v3.23
        else
            echo -e $cRED"Unable to remove unbound - 'unbound' not installed?"$cRESET
        fi

        # Purge unbound directories
        for DIR in "/opt/var/lib/unbound/adblock" "/opt/var/lib/unbound" "/jffs/addons/unbound";  do     # v3.08 v2.00 v1.07
            if [ -d "$DIR" ]; then
                if ! rm "$DIR"/* >/dev/null 2>&1; then
                    printf '%bNo files found to remove in %b%s%b\n' "${cRESET}$cYEL" "$cBGRE" "$DIR" "$cRESET" # v3.09
                fi
                if ! rmdir "$DIR" >/dev/null 2>&1; then
                    printf '%b***ERROR trying to remove %b%s%b\n' "${cRESET}$cRED" "$cBGRE" "$DIR" "$cRESET"
                else
                    printf '%b%s%b folder and all files removed\n' "$cBGRE"  "$DIR" "$cRESET"
                fi
            else
                printf '%b%s%b folder does not exist. No directory to remove%b\n' "$cGRE" "$DIR" "$cRED" "$cRESET"
            fi
        done

        # Remove file /opt/etc/init.d/S61unbound
        if [ -d "/opt/etc/init.d" ]; then
            echo -e $cBCYA"Removing '/opt/etc/init.d/S61unbound'"$cBGRE
            /opt/bin/find /opt/etc/init.d -type f -name S61unbound\* -delete
        fi

        # Remove stubby files                               # v1.15 - Assumes this script installed Stubby!!!
        if [ -d "/opt/etc/init.d" ]; then
            echo -e $cBCYA"Uninstalling stubby"$cBGRA
            opkg remove stubby --autoremove
            /opt/bin/find /opt/etc/init.d -type f -name S62stubby\* -delete
            echo -e $cBCYA"Deleting  '/opt/etc/stubby'"
            rm -R /opt/etc/stubby 2>/dev/null
        fi
.
        Check_dnsmasq_postconf "del"

        # If bypass dnsmasq assume /jffs/addons/unbound.postconf won't be executed to remove 'port=0'etc. from /etc/dnsmasq.conf
        if [ -f /jffs/configs/dnsmasq.conf.add ] && [ -n "$(grep "port=0" /jffs/configs/dnsmasq.conf.add)" ];then   # v3.20 v3.15
            sed -i '/unbound_manager/d' /jffs/configs/dnsmasq.conf.add      # v3.14
            # Reinstate Diversion just-in-case
            if [ -n "$(which diversion)" ];then                            # v3.15
               if [ -f /opt/share/diversion/.conf/diversion.conf ] && [ "$(grep -E "^DIVERSION_STATUS" /opt/share/diversion/.conf/diversion.conf)" == "DIVERSION_STATUS=disabled" ];then
                  echo -e $cBCYA"\n"$(date "+%H:%M:%S")" Starting 'Diversion'....."$cRESET   # v3.15
                  /opt/bin/diversion enable                                 # v3.15
               fi
            fi
        fi

        echo -en $cBCYA"Restarting dnsmasq....."$cBGRE      # v1.14
        # If bypass dnsmasq assume /jffs/addons/unbound.postconf won't be executed to remove 'port=0' from /etc/dnsmasq.conf
        if [ -f /jffs/configs/dnsmasq.conf.add ];then                   #v.3.20
            sed -i '/unbound_manager/d' /jffs/configs/dnsmasq.conf.add   # v3.14
        fi
        service restart_dnsmasq             # v1.14 relocated - Just in case reboot is skipped!

        Script_alias "delete"                   # v2.01

        Optimise_Performance "del"              # v1.15

        # v2.00 now uses /jffs/addons/ but just in case we have a pre v2.00 install...
        if [ -f /jffs/scripts/unbound.postconf ] || [ -f /jffs/scripts/stuning ] || [ -f /jffs/scripts/unbound_manager.md5 ] || [ -f /jffs/scripts/unbound_manager.sh ] || [ -f /opt/bin/unbound_manager ];then    # v2.00
            echo -e $cBCYA"Removing legacy install files from '/jffs/scripts/'"$cBGRE
            [ -f /jffs/scripts/unbound.postconf ]       && rm /jffs/scripts/unbound.postconf        # v2.00
            [ -f /jffs/scripts/stuning ]                && rm /jffs/scripts/stuning                 # v2.00
            [ -f /jffs/scripts/unbound_manager.md5 ]    && rm /jffs/scripts/unbound_manager.md5     # v2.00
            [ -f /jffs/scripts/unbound_manager.sh ]     && rm /jffs/scripts/unbound_manager.sh      # v2.00
            [ -f /opt/bin/unbound_manager ]             && { echo -e $cBCYA"Removing 'unbound_manager' alias" 2>&1; rm -rf "/opt/bin/unbound_manager"; }    # v2.01

        fi

        if [ "$1" == "full" ];then                  # v2.09
            echo -e $cBCYA"Removing scribe logs"$cBGRE
            rm /opt/etc/syslog-ng.d/unbound /opt/var/log/unbound.log 2>/dev/null    # v2.11
            /opt/bin/scribe reload 2>/dev/null 1>/dev/null
        fi

        echo -e "Press$cBRED Y$cRESET to$cBRED delete ALL DATA files $cRESET('/opt/share/unbound/configs') or press$cBGRE [Enter] to keep custom DATA files."
        read -r "CONFIRM_DATA_DELETE"
        if [ "$CONFIRM_DATA_DELETE" == "Y" ];then
           echo -e $cBCYA"Removing ALL custom DATA"$cBGRE
           rm -rf /opt/share/unbound 2>/dev/null    # v3.19
        fi

        # Reboot router to complete uninstall of unbound
        echo -e $cBGRE"\n\tUninstall of unbound completed.\n"$cRESET

        echo -e "The router will now$cBRED REBOOT$cRESET to finalize the removal of unbound"
        echo -e "After the$cBRED REBOOT$cRESET, review the DNS settings on the WAN GUI and adjust if necessary"
        echo
        echo -e "Press$cBRED Y$cRESET to$cBRED REBOOT $cRESET or press$cBGRE [Enter] to ABORT"
        read -r "CONFIRM_REBOOT"
        [ "$CONFIRM_REBOOT" == "Y" ] && { echo -e $cBRED"\a\n\n\tREBOOTing....."; service start_reboot; } || echo -e $cBGRE"\tReboot ABORTED\n"$cRESET
}
install_unbound() {

        # Check if any Auto-Install options supplied        # v1.20
        shift

        local OPT=1
        while [ $# -gt 0 ]; do # Until you run out of parameters.....

            [ -n "$( echo "$1" | grep -v '[0-9]')" ] && { echo -e $cBRED"\a\n\tInvalid Option '$1' (Must be numeric Option in range 1-$MAX_OPTIONS)\n"$cRESET; exit 1; }
            [ $OPT -gt $MAX_OPTIONS ] && { echo -e $cBRED"\a\n\tToo many Auto-Reply Options specified! (Only $MAX_OPTIONS Options available)\n"$cRESET; exit 1; }
            [ "$1" -gt $MAX_OPTIONS ] && { echo -e $cBRED"\a\n\tOption '$1' out of range! (>$MAX_OPTIONS)\n"$cRESET; exit 1; }
            eval "AUTO_REPLY$1='y'"                         # v1.20

            [ -z "$(echo "$CURRENT_AUTO_OPTIONS" | grep -ow "$1" )" ] && CURRENT_AUTO_OPTIONS=$CURRENT_AUTO_OPTIONS" "$1    # v1.20

            USER_OPTION_PROMPTS=                            # Disable User manual Options prompts

            shift

            OPT=$((OPT + 1))

        done

        [ -n "$CURRENT_AUTO_OPTIONS" ] && CURRENT_AUTO_OPTIONS=$(echo $CURRENT_AUTO_OPTIONS | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/^[ \t]*//;s/[ \t]*$//') # v1.20 Old-skool strip leading/trailing spaces

        [ -z "$(which unbound)" ] && local ACTION="INSTALL" || local ACTION="UPDATE"

        Check_GUI_NVRAM "install"

        if [ $? -gt 0 ];then
            echo -e $cRESET"\n\tThe router does not currently meet ALL of the recommended pre-reqs as shown above."
            echo -e "\tHowever, whilst they are recommended, you may proceed with the unbound ${cBGRE}${ACTION}$cRESET"
            echo -e "\tas the recommendations are NOT usually FATAL if they are NOT strictly followed.\n"


            echo -e "\tPress$cBGRE Y$cRESET to$cBGRE continue unbound $ACTION $cRESET or press$cBRED [Enter] to ABORT"$cRESET
            read -r "CONTINUE_INSTALLATION"
            [ "$CONTINUE_INSTALLATION" != "Y" ] && { echo -e $cBRED"\a\n\tunbound $ACTION CANCELLED!....."$cRESET; return 1; }  # v2.06
        fi

        echo -en $cBCYA"\n${ACTION}ing unbound"$cRESET

        local START_TIME=$(date +%s)

        # if [ -d "/jffs/dnscrypt" ] || [ -f "/opt/sbin/dnscrypt-proxy" ]; then
            # echo "Warning! DNSCrypt installation detected"
            # printf 'Please remove this script to continue installing unbound\n\n'
            # exit 1
        # fi

        echo
        if Chk_Entware; then
            if opkg update >/dev/null 2>&1; then
                echo -e $cBGRE"Entware package list successfully updated"$cBGRA
            else
                echo -e $cBRED"***ERROR occurred updating Entware package list"$cRESET
                exit 1
            fi
        else
            echo -e $cBRED"You must first install Entware before proceeding see 'amtm'"$cRESET
            printf 'Exiting %s\n' "$(basename "$0")"
            exit 1
        fi

        if opkg install $ENTWARE_UNBOUND --force-downgrade; then
            echo -e $cBGRE"unbound Entware packages '$ENTWARE_UNBOUND' successfully installed"$cRESET
        else
            echo -e $cBRED"\a\n\n\t***ERROR occurred installing unbound\n"$cRESET
            exit 1
        fi

        # echo -e $cBCYA"Linking '${CONFIG_DIR}unbound.conf' --> '/opt/var/lib/unbound/unbound.conf'"$cRESET
        # ln -s ${CONFIG_DIR}unbound.conf /opt/var/lib/unbound/unbound.conf 2>/dev/null # Hack to retain '/opt/etc/unbound' for configs

        create_required_directories                             # v2.03

        Generate_unbound_SSL_Keys                               # Execute 'unbound-control'
        # Unfortunately 'openssl-util' is a dependency for 'unbound-control-setup' and Entware 'openssl-util' conflicts with 'diversion' Thanks @dave14305
        opkg remove unbound-control-setup                       # v2.09 - @dave14305
        opkg remove openssl-util                                # v2.09 - @dave14305

        Install_Entware_opkg "column"
        Install_Entware_opkg "diffutils"                        # v1.25
        Install_Entware_opkg "bind-dig"                         # v2.09

        # v386.2 installs '/usr/sbin/jitterentropy-rngd'        # v3.23
        # http://www.snbforums.com/threads/jitterentropy-rngd-high-cpu-use.72340/post-687202
        if [ "$(/bin/uname -o)" != "ASUSWRT-Merlin-LTS" ];then       # v2.10 v1.26 As per dave14305 http://www.snbforums.com/threads/unbound-authoritative-recursive-caching-dns-server.58967/post-542767
            # RMerlin now defaults to 'haveged' rather than 'jitterentropy-rngd' so don't install Entware 'haveged'
			if [ ! -f /usr/sbin/haveged ];then					# v3.24
				if [ -z "$(which jitterentropy-rngd)" ];then    # v3.23
					Install_Entware_opkg "haveged"
					S02haveged_update
				fi
			fi
        fi

        Check_dnsmasq_postconf

        S61unbound_update

        Customise_config                                        # v3.08 Hotfix

        local DISABLELOGGING=$(Enable_Logging "?")             # v3.09 v1.16 Always create the log file, but ask user if it should be ENABLED

        [ "$DISABLELOGGING" == "0" ] && echo -e $cBCYA"unbound Logging enabled - 'verbosity:" $(Get_unbound_config_option "verbosity:" ${CONFIG_DIR}unbound.conf)"'"$cRESET

        if [ "$(Valid_unbound_config_Syntax "${CONFIG_DIR}unbound.conf")" == "Y" ];then     # v2.03
            echo -en $cBGRE
            unbound-checkconf               # v2.03
            echo -en $cRESET
        else
            echo -en $cBRED"\a"
            unbound-checkconf               # v2.03
            echo -en $cBCYA"Restarting dnsmasq....."$cGRE       # v1.13
            service restart_dnsmasq                             # v1.13
            echo -e $cBRED"\a\n\t***ERROR FATAL...ABORTing!\n"$cRESET

            exit_message                    # v2.03
        fi

        Option_Optimise_Performance         "$AUTO_REPLY4"

        #Option_Stubby_Integration           "$AUTO_REPLY2"     # v3.00 Advanced users will use the Stubby menu command
        #echo -en $cBCYA"Restarting dnsmasq....."$cBGRE        # v1.13
        #service restart_dnsmasq                                # v1.13
        #echo -en $cRESET

        # The default in RMerlin dnsmasq is to disable FirefoxDoH, so replicate it if already ENABLED
        [ -n "$(grep -E "^address.*use-application-dns.net" /etc/dnsmasq.conf)" ] && Disable_Firefox_DoH "yes"    # v3.16 Hotfix v1.18

        # v3.00 running 'Easy' mode has explicit menu (toggle) options for both Ad Block and Stats TAB install/uninstall
        if [ "$EASYMENU" != "Y" ];then
            Option_GUI_Stats_TAB            "$AUTO_REPLY7"      # v2.18 Hotfix

            # v2.15 Ad Block MUST be last Option installed because    .....
            Option_Ad_Tracker_Blocker       "$AUTO_REPLY3"      # If installed, invokes 'unbound_manager restart'
        else
            # Easy mode v3.00 there are no option prompts for Ad Block/Stats GUI TAB so if unbound was just updated.....
            if [ -n "$(cru l | grep adblock)" ];then        # v3.00 Ad block cron job already exists ?
                if [ -n "$(grep -E "^#[\s]*include:.*adblock/adservers" ${CONFIG_DIR}unbound.conf)" ];then
                    sed -i "/adblock\/adservers/s/^#//" ${CONFIG_DIR}unbound.conf   # v3.00 Silently reinstate Ad Block
                fi
            fi

            if [ -f /tmp/menuTree.js ];then                 # v3.00 GUI TAB installed ?
                [ -n "$(grep -i "Unbound" /tmp/menuTree.js)" ] && Edit_config_options "extended-statistics:"  "uncomment"   # v3.00
            fi
        fi

        [ -z "$(pidof unbound)" ] && /opt/etc/init.d/S61unbound start || Restart_unbound # v2.17 Save/Restore cache by default.

        local END_TIME=$(date +%s)
        local DIFFTIME=$((END_TIME-START_TIME))

        # unbound apparently has a habit of taking its time to fully process its 'unbound.conf' and may terminate due to invalid directives
        # e.g. fatal error: could not open autotrust file for writing, /root.key.22350-0-2a0796d0: Permission denied
        [ "$USER_OPTION_PROMPTS" == "?" ] && local INSTALLMETHOD="Manual install" || local INSTALLMETHOD="Auto install"
        echo -e $cRESET"\n$INSTALLMETHOD unbound Customisation complete $cBGRE$(($DIFFTIME / 60)) minutes and $(($DIFFTIME % 60)) seconds elapsed - ${cRESET}Please wait for up to ${cBCYA}10$cRESET seconds for ${cBCYA}status.....\n"$cRESET
        local WAIT=3     # 16 i.e. 15 secs should be adequate?        # v3.00
        I=0
         while [ $I -lt $((WAIT-1)) ]
            do
                sleep 1
                I=$((I + 1))
                [ -z "$(pidof unbound)" ] && { echo -e $cBRED"\a\n\n\t${aREVERSE}***ERROR unbound went AWOL after $I seconds${cRESET}.....\n$cBRED"$cRESET ; break; }
            done                                                         # v1.06

        if pidof unbound >/dev/null 2>&1; then
            service restart_dnsmasq >/dev/null      # v1.18 Redundant? - S61unbound now reinstates 'POSTCMD=service restart_dnsmasq'

            if [ "$KEEPACTIVECONFIG" != "Y" ];then                       # v1.27
                #local TAG="# rgnldo User Install Custom Version vx.xx (Date Loaded by unbound_manager "$(date)")" # v1.19
                #echo -e $cBCYA"Tagged 'unbound.conf' '$TAG' and backed up to '/opt/share/unbound/configs/user.conf'"$cRESET
                # Backup the config to easily restore it 'rl user[.conf]'                 # v1.19
                cp -f ${CONFIG_DIR}unbound.conf /opt/share/unbound/configs/user.conf      # v1.19
                #sed -i "1i$TAG" /opt/share/unbound/configs/user.conf    # v1.19
                #cmp -s ${CONFIG_DIR}unbound.conf /opt/share/unbound/configs/reset.conf || sed -i "1i$TAG" ${CONFIG_DIR}unbound.conf # v1.19
                echo -e $cBGRE"\n\tInstallation of unbound completed\n"  # v1.04
            fi

            local LOGFILE="$(Get_unbound_config_option "logfile:"  | tr -d '"')"     # v3.09
            if [ -n "$LOGFILE" ];then
               [ "${LOGFILE:0:1}" != "/" ] && LOGFILE=${CONFIG_DIR}$LOGFILE        # v3.09 Ensure full pathname
            fi

            # v3.09 If User chose not to ENABLE logging, explicitly DISABLE it now unbound is UP
            if [ "$DISABLELOGGING" == "1" ];then                        # v3.10 Fix
               local LOGLEVEL=0
               $UNBOUNCTRLCMD -q verbosity 0
               $UNBOUNCTRLCMD -q set_option verbosity 0
               sed -i "/^verbosity:/ s/[^ ]*[^ ]/$LOGLEVEL/2" ${CONFIG_DIR}unbound.conf      # v3.09
               echo -e $(date "+%b %d %T") "unbound_manager: '--':  =================================================================================== Auto-Stopped Post-Install" >> $LOGFILE
            else
               echo -e $(date "+%b %d %T") "unbound_manager: '++':  =================================================================================== Started User-Install" >> $LOGFILE
            fi
        else
            echo -e $cBRED"\a\n\t***ERROR Unsuccessful installation of unbound detected\n" # v1.04
            echo -en ${cRESET}$cRED_
            grep unbound /tmp/syslog.log | tail -n 5                     # v1.07
            unbound -dvvv          # v1.06
            echo -e $cRESET"\n"
            printf '\n\tRerun %bunbound_manager nochk%b and select the %bRemove%b option to backout changes\n\n' "$cBGRE" "$cRESET" "$cBGRE" "$cRESET"
            exit_message                                                 # v1.18

        fi

        echo -en $cRESET

        Check_GUI_NVRAM

        return 0                                                    # v2.06

        #exit_message                                               # v1.18
}
Get_unbound_config_option() {

_quote() {
  echo $1 | sed 's/[]\/()$*.^|[]/\\&/g'
}

        local KEYWORD="$(_quote "$1")"  # v2.00

        # Ignore the comment/header entries                         # v2.14
        local POS="$(grep -Enw "[[:space:]]*server:" ${CONFIG_DIR}unbound.conf | head -n 1 | cut -d':' -f1)"   # Hotfix v2.18 v2.14
        local LINE="$(tail -n +$POS ${CONFIG_DIR}unbound.conf | grep -E "^[[:blank:]]*[^#]" | grep -E "$KEYWORD")"   # v2.14

        [ "$(echo "$LINE" | grep -E "^#" )" ] && local LINE=

        local VALUE="$(echo $LINE | awk -F':' '{print $2}')"
        local VALUE="$(echo $VALUE | awk -F'#' '{print $1}')"       # V2.04

        local VALUE=$(printf "%s" "$VALUE" | sed 's/^[ \t]*//;s/[ \t]*$//')

        [ -z "$LINE" ] && echo "?" || echo "$VALUE"
}
Valid_unbound_config_Syntax() {

    local VALID="Y"                       # v3.00
    local RC=0                            # v3.00

    local CHECKTHIS="$1"    # v2.03
    [ -z "$1" ] && CHECKTHIS="${CONFIG_DIR}unbound.conf"

    # If file doesn't exist then spoof 'Y' reply
    [ ! -f "$CHECKTHIS" ] && { echo "Y"; return 0; }

    #echo -e $cBCYA"\nChecking $cBMAG'$CHECKTHIS'$cBCYA for valid Syntax....."$cBGRE 2>&1

    # v3.00 Certain directives can explicitly be specified more than once e.g. 'server:', 'access-control:' etc.
    #       but detect duplicates (although last one wins?) that could be ambiguous
    #       e.g.
    #            ip-v6: no
    #            ip-v6: yes
    #
    local STATEMENTS="server:|access-control:|private-address:|private-domain:|domain-insecure:|forward-addr:|include:|\
interface:|outgoing-interface|name:|zonefile:|rpz.*:|url:|tags:|access-control-tag:|ipset:|name-v4:|name-v6:|local-data:|local-zone:"   # v3.22 @sfatula v3.20 v3.12 v3.00 Hotfix
    local DUPLICATES="$(sed '/^[[:space:]]*#/d' /opt/var/lib/unbound/unbound.conf | sed '/^[[:space:]]*$/d' | sed '/^$/d' | awk '{print $1}' | sort | uniq -cd | \
                       grep -vE "$STATEMENTS")"                                            # v3.07

    if [ -z "$DUPLICATES"  ];then   # v3.00
       local CHK_Config_Syntax="$(unbound-checkconf $CHECKTHIS 2>/dev/null)"            # v2.03
       if [ -z "$(echo "$CHK_Config_Syntax" | grep -o "no errors in" )" ];then          # v2.03
          local VALID="N"               # v3.00 Invalid Syntax detected
          local RC=1                    # v3.00
       fi
    else
       local VALID="D"                  # v3.00 Invalid duplicates detected
       local RC=1
    fi

    [ "$2" == "returndup" ] && echo "$DUPLICATES" || echo $VALID                   # v3.00 # v3.00

    return $RC                   # v3.00

}
Record_CNT() {

    # Files downloaded from GitHub could be in DOS format, so 'a logically empty file od0a' would appear as 1 record

    local FN="$1"   # v2.04

    if [ -f $FN ];then      # v2.17
        dos2unix $FN
        sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $FN               #Strip trailing blank lines
        echo $(grep -vE "^#" $FN | grep . | awk 'END{print NR}')   # v3.14
    else
        echo "n/a"              # v2.17
    fi
}

Manage_cache_stats() {

    case "$1" in            # v2.11
        save)
            unbound_Control "dump"
        ;;
        restore)
            unbound_Control "load"
        ;;
        delete)
            unbound_Control "flush"
        ;;
    esac
}
Options_DESC() {
    # v2.18 cosmetic display for cryptic numeric options e.g. 3=Ad Block

    local DESC=" "

    for OPT in $1
        do
            case $OPT in
                1) DESC=$DESC"unbound Logging,";;
                2) DESC=$DESC"Stubby Integration,";;
                3) DESC=$DESC"Ad Block,";;
                4) DESC=$DESC"Performance Tweaks,";;
                5) DESC=$DESC"Firefox DoH,";;
            esac
        done

    DESC=$(echo "$DESC" | sed 's/,$//g')
    echo "$DESC"
    return 0
}
Check_GUI_NVRAM() {

        local ERROR_CNT=0                           # v2.16 Hotfix
        local ENABLED_OPTIONS=" "                    # v2.18

        if [ "$1" == "active" ];then                # v2.18
            STATUSONLY="StatusOnly"                  # v2.18
        else
            echo -e $cBCYA"\n\tRouter Configuration recommended pre-reqs status:\n" 2>&1    # v1.04
            # Check Swap file
            [ $(Check_SWAP) -eq 0 ] && echo -e $cBRED"\t[✖] Warning SWAP file is not configured $cRESET - use amtm to create one!" 2>&1 || echo -e $cBGRE"\t[✔] Swapfile="$(grep "SwapTotal" /proc/meminfo | awk '{print $2" "$3}')$cRESET  2>&1    # v1.04

            #  Check GUI 'DNS Director' (388.1 replaced 'DNS Filter')		# v3.24 - @novusB reported 404 error
            if [ $(nvram get dnsfilter_enable_x) -eq 0 ];then
				#if [ $FIRMWARE -ge 38801 ] && [ -f /www/DNSDirector.asp ];then
				if [ -f /www/DNSDirector.asp ];then
					echo -e $cBRED"\a\t[✖] ***ERROR DNS Director is OFF! $cRESET \t\t\t\t\t\tsee $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/DNSDirector.asp LAN->DNS Director" 2>&1
                else
					echo -e $cBRED"\a\t[✖] ***ERROR DNS Filter is OFF! $cRESET \t\t\t\t\t\tsee $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/DNSFilter.asp LAN->DNS Filter" 2>&1
				fi
				ERROR_CNT=$((ERROR_CNT + 1))
            else
				if [ -f /www/DNSDirector.asp ];then
					echo -e $cBGRE"\t[✔] DNS Director=ON" 2>&1
				else
					echo -e $cBGRE"\t[✔] DNS Filter=ON" 2>&1
				fi
                #   DNS Director / DNS Filter: ON - Mode Router ?
                if [ $(nvram get dnsfilter_mode) != "11" ];then
					if [ -f /www/DNSDirector.asp ];then
						echo -e $cBRED"\a\t[✖] ***ERROR DNS Director is NOT = 'Router' $cRESET \t\t\t\t\tsee $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/DNSDirector.asp ->LAN->DNS Director"$cRESET 2>&1
					else
						echo -e $cBRED"\a\t[✖] ***ERROR DNS Filter is NOT = 'Router' $cRESET \t\t\t\t\tsee $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/DNSFilter.asp ->LAN->DNS Filter"$cRESET 2>&1
					fi
					ERROR_CNT=$((ERROR_CNT + 1))
				else
					if [ -f /www/DNSDirector.asp ];then
						echo -e $cBGRE"\t[✔] DNS Director=ROUTER" 2>&1
					else
						echo -e $cBGRE"\t[✔] DNS Filter=ROUTER" 2>&1
					fi
				fi
            fi

            if [ "$(/bin/uname -o)" == "ASUSWRT-Merlin-LTS" ];then               # v1.26 HotFix @dave14305
                    [ $(nvram get ntpd_server) == "0" ] && { echo -e $cBRED"\a\t[✖] ***ERROR Enable local NTP server=NO $cRESET \t\t\t\t\tsee $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/Advanced_System_Content.asp ->Basic Config"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] Enable local NTP server=YES" 2>&1
           else
                if [ $FIRMWARE -ne 38406 ] && [ "$HARDWARE_MODEL" != "RT-AC56U" ] ;then     # v2.10
                    #   Tools/Other WAN DNS local cache: NO # for the FW Merlin development team, it is desirable and safer by this mode.
                    [ $(nvram get dns_local_cache) != "0" ] && { echo -e $cBYEL"\a\t[✖] Warning WAN: Use local caching DNS server as system resolver=YES $cRESET \t\tsee $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/Tools_OtherSettings.asp ->Advanced Tweaks and Hacks"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] WAN: Use local caching DNS server as system resolver=NO" 2>&1
                fi

                # Originally, a check was made to ensure the native RMerlin NTP server is configured.
                # v3.20 v2.07, some wish to use ntpd/chronyd by @JackYaz
                #if [ "$(/usr/bin/which ntpd)" == "/opt/sbin/ntpd" ];then
                if [ -f /opt/etc/init.d/S77ntpd ] || [ -f /opt/etc/init.d/S77chronyd ];then     # v3.20
                    if [ -f /opt/etc/init.d/S77ntpd ];then                                      # v3.20
                       [ -n "$(/opt/etc/init.d/S77ntpd check | grep "dead")" ] && { echo -e $cBYEL"\a\t[✖] Warning Entware NTP Server ${cBWHT}'S77ntpd'$cBYEL installed but not running? $cRESET \t\t\t\t\t"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] Entware NTP server ${cBWHT}'S77ntpd'$cBGRE is running" 2>&1
                    else                                                                        # v3.20
                       [ -n "$(/opt/etc/init.d/S77chronyd check | grep "dead")" ] && { echo -e $cBYEL"\a\t[✖] Warning Entware NTP Server ${cBWHT}'S77chronyd'$cBYEL installed but not running? $cRESET \t\t\t\t\t"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] Entware NTP server ${cBWHT}'S77chronyd'$cBGRE is running" 2>&1
                    fi
                else
                    if [ "$HARDWARE_MODEL" != "RT-AC56U" ] && [ $FIRMWARE -ne 38406 ];then  # v2.10
                        [ $(nvram get ntpd_enable) == "0" ] && { echo -e $cBRED"\a\t[✖] ***ERROR Enable local NTP server=NO $cRESET \t\t\t\t\tsee $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/Advanced_System_Content.asp ->Basic Config"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] Enable local NTP server=YES" 2>&1
                    else
                        if [ ! -f /opt/etc/init.d/S77ntpd ];then                                # v2.10
                            echo -e $cBRED"\a\t[✖] Warning Entware NTP server not installed"$cRESET
                        fi
                    fi
                fi
            fi

            # Check GUI 'Enable DNS Rebind protection'          # v1.18
            [ "$(nvram get dns_norebind)" == "1" ] && { echo -e $cBRED"\a\t[✖] ***ERROR Enable DNS Rebind protection=YES $cRESET \t\t\t\t\tsee $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/Advanced_WAN_Content.asp ->WAN DNS Setting"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] Enable DNS Rebind protection=NO" 2>&1

            # Check GUI 'Enable DNSSEC support'                 # v1.15
            [ "$(nvram get dnssec_enable)" == "1" ] && echo -e $cBRED"\a\t[✖] Warning Enable DNSSEC support=YES $cRESET \t\t\t\t\t\tsee $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/Advanced_WAN_Content.asp ->WAN DNS Setting"$cRESET 2>&1 || echo -e $cBGRE"\t[✔] Enable DNSSEC support=NO" 2>&1

            [ "$USER_OPTION_PROMPTS" != "?" ] && local TXT="$cRESET Auto Reply='y' for User Selectable Options ('${cBYEL}${CURRENT_AUTO_OPTIONS}$cRESET')" || local TEXT=        # v1.20

            if [ "$ACTION" == "INSTALL" ] && [ "$USER_OPTION_PROMPTS" == "N" ];then
                local TXT="${cRESET}$cBGRE unbound ONLY install$cRESET - No User Selectable options will be configured"
            fi
            if [ "$ACTION" == "INSTALL" ] && [ "$USER_OPTION_PROMPTS" == "?" ];then
                local TXT="${cRESET}$cBGRE unbound Advanced install$cRESET - User will be prompted to install options"
            fi
            [ "$(Skynet_BANNED_Countries)" == "Y" ] && echo -e $cBRED"\a\t[✖] Warning Skynet's Country BAN feature is currently ACTIVE and may significantly reduce unbound performance and in some cases block sites" 2>&1         # v2.09

            local DESC=${cBYEL}$(Options_DESC "$CURRENT_AUTO_OPTIONS")              # v2.18
            [ "$EASYMENU" == "Y" ] && { CURRENT_AUTO_OPTIONS=; TXT=; DESC=; }
            echo -e $cBCYA"\n\tOptions:${TXT}$DESC\n" 2>&1                      # v2.18

        fi

        if [ -f ${CONFIG_DIR}unbound.conf ];then

            # Logging is deemed dynamic, so need to check both config and unbound-control??? or just unbound-control???
            # AUTO_REPLY 1
            if [ -n "$(pidof unbound)" ];then
                if [ "$(awk '/^verbosity:.*[1-9]/ {print $2}' ${CONFIG_DIR}unbound.conf)" -gt 0 ] || [ "$(unbound_Control "oq" "verbosity" "value")" != "0" ];then   # v3.08 v3.06 v2.04
                    # But are queries/replies being logged?                  # v3.06
                    local TXT=
                    if [ "$(Get_unbound_config_option "log-replies:" ${CONFIG_DIR}unbound.conf)" == "?" ] && [ "$(Get_unbound_config_option "log-queries:" ${CONFIG_DIR}unbound.conf)" == "?" ];then   # v3.06
                       TXT=" ${cRED}(Warning; DNS Queries/Replies logging is DISABLED)"   # v3.06
                    fi
                    [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] unbound Logging" $TXT 2>&1 || ENABLED_OPTIONS=$ENABLED_OPTIONS" 1"      #v2.18
                fi
            else
                if [ "$(awk '/^verbosity:.*[1-9]/ {print $2}' ${CONFIG_DIR}unbound.conf)" -gt 0 ];then # v3.08 v3.06
                    [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] unbound Logging" 2>&1
                fi
            fi

            # AUTO_REPLY 2
            if [ "$(Get_unbound_config_option "forward-addr: 127.0.0.1@5453" ${CONFIG_DIR}unbound.conf)" != "?" ];then      # v2.18
                echo -e $cBGRE"\t[✔] Stubby Integration" 2>&1 || ENABLED_OPTIONS=$ENABLED_OPTIONS" 2"    #v2.18
            fi

            # AUTO_REPLY 3
            if [ "$(Get_unbound_config_option "adblock/adservers" ${CONFIG_DIR}unbound.conf)" != "?" ];then
                if [ -z "$STATUSONLY" ];then                        # v2.18
                    [ -n "$(grep -m 1 "always_nxdomain" /opt/var/lib/unbound/adblock/adservers)" ] && PIXELSERVTXT= || PIXELSERVTXT="(via pixelserv-tls) " # v3.00
                    local CC=$(grep -cE "local\-zone: \".{2}\"" /opt/var/lib/unbound/adblock/adservers) # v3.20
                    local TXT="No. of Adblock ${PIXELSERVTXT}domains="$cBMAG"$(Record_CNT "${CONFIG_DIR}adblock/adservers"),"${cRESET}"Blocked Hosts="$cBMAG"$(Record_CNT  "/opt/share/unbound/configs/blockhost"),"${cRESET}"Allowlist="$cBMAG"$(Record_CNT "${CONFIG_DIR}adblock/permlist")",${cRESET}"Blocked Country="${cBMAG}$CC    # v3.20 v3.00 v2.14 v2.04

                    # Check if Diversion is also running
                    if [ -f /opt/share/diversion/.conf/diversion.conf ] && [ "$(grep -E "^DIVERSION_STATUS" /opt/share/diversion/.conf/diversion.conf)" == "DIVERSION_STATUS=enabled" ];then    # v3.11 Hotfix
                        local TXT=$TXT", "$cBRED"- Warning Diversion is also ACTIVE"    # v3.11 v2.18 Hotfix v1.24
                    fi
                fi
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] Ad and Tracker Blocking"$cRESET" ($TXT)" 2>&1 || ENABLED_OPTIONS=$ENABLED_OPTIONS" 3"     #v2.18
            fi

            # AUTO_REPLY 4
            if [ -f /jffs/addons/unbound/stuning ];then             # v2.18
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] unbound CPU/Memory Performance tweaks" 2>&1 || ENABLED_OPTIONS=$ENABLED_OPTIONS" 4"     #v2.18 v2.00
            fi

            # AUTO_REPLY 5
            if [ "$(Get_unbound_config_option "adblock/firefox_DOH" ${CONFIG_DIR}unbound.conf)" != "?" ];then       # v2.18
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] Firefox DNS-over-HTTPS (DoH) DISABLE/Blocker" 2>&1 || ENABLED_OPTIONS=$ENABLED_OPTIONS" 5"      #v2.18
            fi

            # AUTO_REPLY 6
            if [ "$(Get_unbound_config_option "forward-tls-upstream:" ${CONFIG_DIR}unbound.conf)" == "yes" ];then        # v2.12
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] DoT ENABLED. These third parties are used:" 2>&1          # v2.18 Hotfix
                local DOTLIST=$(grep -E "^forward-addr:" /opt/var/lib/unbound/unbound.conf | sed 's/forward-addr://')
                for DOT in $DOTLIST
                    do
                        echo -e $cBWHT"\t\t"$DOT 2>&1
                    done
            fi

            # AUTO_REPLY 7
            if [ -f /jffs/addons/unbound/unboundstats_www.asp ];then                                                    # v2.14
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] Router Graphical GUI statistics TAB installed" 2>&1
            fi

            # AUTO_REPLY 8
            if [ "$(Get_unbound_config_option "control-use-cert:" ${CONFIG_DIR}unbound.conf)" == "no" ];then            # v2.15
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] unbound-control FAST response ENABLED" 2>&1
            fi

            # AUTO_REPLY 9 (used by BIND_WAN as well!)
            if [ "$(Get_unbound_config_option "outgoing-interface:" ${CONFIG_DIR}unbound.conf)" != "?" ];then            # v3.00
                if [ -z "$STATUSONLY" ];then
                    local WAN_IF=$(Get_WAN_IF_Name)                                                     # v3.06 Hotfix
                    local WAN_IP=$(ip route | grep src | grep -v default | grep -E "dev $WAN_IF[[:space:]]" | awk '{print $NF}')   # v3.06
                    local BIND_IP=$(awk '/^outgoing-interface:/ {print $2}' ${CONFIG_DIR}unbound.conf)
                    local VPN_ID=$(ip route | grep "$BIND_IP" | awk '{print substr($3,5,1)}')    # v3.04 Hotfix
                    TXT="via VPN Client ${cBMAG}$VPN_ID ($BIND_IP)$cBGRE tunnel ENABLED"
                    [ "$WAN_IP" == "$BIND_IP" ] && TXT="force BIND via ${cBMAG}WAN ($WAN_IP) '${WAN_IF}'$cBGRE ENABLED"
                    echo -e $cBGRE"\t[✔] unbound requests $TXT" 2>&1
                fi
            fi

            # AUTO_REPLY 10
            if [ -n "$(grep -F "unbound.conf.firewall" ${CONFIG_DIR}unbound.conf)" ] || [ "$(Get_unbound_config_option "rpz:" ${CONFIG_DIR}unbound.conf)" != "?" ];then            # v3.03 v3.00
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] DNS Firewall ENABLED" 2>&1
            fi

            # AUTO_REPLY 11
            if [ "$(Get_unbound_config_option "port:" ${CONFIG_DIR}unbound.conf)" == "53" ];then            # v3.10
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] Unbound is the Primary DNS for ALL LAN Clients $cRED(dnsmaq DNS features DISABLED e.g. IPSET auto-populate)" 2>&1
            fi

            # AUTO_REPLY 12
            if [ -f /opt/var/lib/unbound/adblock/gen_ytadblock.sh ];then            # v3.11
                if [ -s /opt/share/unbound/configs/ipytforce ];then
                   local IPYT=$(cat /opt/share/unbound/configs/ipytforce)
                   local IPYTDOMAINS=$(awk 'END{print NR} ' /opt/var/lib/unbound/adblock/ytadblock)   # v3.11 Hotfix
                fi
                [ -n "$IPYT" ] && local TXT="${cRESET}(Forcing to use YT IP ${cBMAG}$IPYT$cRESET, No. of YouTube Video Ad ${cBGRE}domains=${cBMAG}${IPYTDOMAINS}${cRESET})" || local TXT=${cRESET}$cRED_".....Please play YouTube video to acquire YouTube Ad Server IP Address"$cRESET
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] YouTube Ad Blocking $TXT" 2>&1
            fi

            if [ -n "$(grep -F "unbound.conf.views" ${CONFIG_DIR}unbound.conf)" ];then            # v3.17
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] unbound 'views:' ENABLED ("${cBMAG}$(grep -c "name:" /opt/share/unbound/configs/unbound.conf.views )"$cRESET views$cBGRE)" 2>&1
            fi

            if [ -n "$(grep -F "unbound.conf.safesearch" ${CONFIG_DIR}unbound.conf)" ];then            # v3.22
                [ -z "$STATUSONLY" ] && echo -e $cBGRE"\t[✔] Safe Search ENABLED ("${cBMAG}$(grep -c "redirect" /opt/share/unbound/configs/unbound.conf.safesearch )"$cRESET domains ${cBGRE}e.g. ${cBWHT}$(grep "local-" /opt/share/unbound/configs/unbound.conf.safesearch | head -n 2 | tr -d "\n" | sed 's/local-zone://g ; s/local-data://g ; s/ CNAME /" to "/g' | awk '{print $2" "$3" "$4" "$5}')$cBGRE)" 2>&1
            fi
        fi

        local TXT=
        unset $TXT
        #echo -e $cRESET 2>&1

        if [ -z "$STATUSONLY" ];then                                     # v2.18
            [ $ERROR_CNT -ne 0 ] && { return 1; } || return 0          # v2.16 Hotfix
        else
            ENABLED_OPTIONS=$(echo "$ENABLED_OPTIONS" | sed 's/  //g')   # v2.18 Strip leading two space chars
            echo "$ENABLED_OPTIONS"                                       # v2.18
            return 0
        fi
}
exit_message() {

        local CODE=0
        [ -n "$1" ] && local CODE=$1

        rm -rf /tmp/unbound.lock

        if [ -n "$1" ] && [ $CODE -eq 0 ];then
            clear
            echo -e $cBWHT
            echo "_____  __      ______                     _________   ______  ___                                         ";
            echo "__  / / /_________  /___________  ______________  /   ___   |/  /_____ _____________ _______ _____________";
            echo "_  / / /__  __ \_  __ \  __ \  / / /_  __ \  __  /    __  /|_/ /_  __ \`/_  __ \  __ \`/_  __ \`/  _ \_  ___/";
            echo "/ /_/ / _  / / /  /_/ / /_/ / /_/ /_  / / / /_/ /     _  /  / / / /_/ /_  / / / /_/ /_  /_/ //  __/  /    ";
            echo "\____/  /_/ /_//_.___/\____/\__,_/ /_/ /_/\__,_/______/_/  /_/  \__,_/ /_/ /_/\__,_/ _\__, / \___//_/     ";
            echo "                                               _/_____/                              /____/               ";
            echo -e "I feel the need -- the need for DNS speed!"
        fi
        echo -e $cRESET
        exit $CODE
}
Option_Ad_Tracker_Blocker() {

        local ANS=$1        # v1.20
        shift               # v2.18 Hotfix
        if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
            echo -en $cBYEL"Option Auto Reply 'y'\t"
        fi

        if [ "$USER_OPTION_PROMPTS" == "?" ] || [  "$ANS" == "?" ];then
            echo -e "\nDo you want to install Ad and Tracker (Ad Block) blocking?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
            read -r "ANS"
        fi
        [ "$ANS" == "y"  ] && { Ad_Tracker_blocking "$@" ; return 0; } || return 1   # v2.18 Hotfix v2.15
}
Ad_Tracker_blocking() {

    local FN="/jffs/scripts/services-start"

    if [ "$1" != "uninstall" ];then                                                 # v2.18

        if [ "$1" != "update" ];then                       # v3.10
            echo -e $cBCYA"Installing Ads and Tracker (Ad Block) Blocking....."$cRESET     # v3.11 v1.06

            download_file ${CONFIG_DIR} adblock/gen_adblock.sh    juched       dos2unix   # v2.17 v2.14 v2.02 v1.17
            download_file ${CONFIG_DIR} adblock/permlist          juched       dos2unix   # v2.17 v2.14 v2.02 v1.17

            # Ad Block User customisable files...
            #       blocklist='/opt/share/unbound/configs/blockhost'
            #       allowlist='/opt/share/unbound/configs/allowhost'
            #   'gen_adblock.sh' v1.0.4 @jusched/@jumpsmm7 split config 'sites' file functionality into two separate files and changed the format
            #       blocksites='/opt/share/unbound/configs/blocksites'
            #       allowsites='/opt/share/unbound/configs/allowsites'
            if [ -n "$(grep blocksites ${CONFIG_DIR}adblock/gen_adblock.sh)" ];then  # v2.17 @jusched/@jumpsmm7 renamed 'sites' and only requires URL

                # Save the legacy Ad Block 'sites' config file, then migrate to new layout if possible   # v2.17
                if [ -f /opt/share/unbound/configs/sites ];then
                    cp /opt/share/unbound/configs/sites /opt/share/unbound/configs/sites.old
                    awk '/whitelist-domains/ {print $2}' /opt/share/unbound/configs/sites > /opt/share/unbound/configs/allowsites
                    sed -i '/whitelist-domains/d' /opt/share/unbound/configs/sites       # Delete the Whitlist entries
                    awk '{$1=""}1' /opt/share/unbound/configs/sites | awk '{$1=$1}1' > /opt/share/unbound/configs/blocksites   # v2.17 migrate legacy 'site' file to new format
                    rm /opt/share/unbound/configs/sites
                fi

                if [ ! -f /opt/share/unbound/configs/blocksites ];then                              # v2.17 @jusched/@jumpsmm7 renamed 'sites'
                    download_file /opt/share/unbound/configs adblock/blocksites  juched   dos2unix   # v2.17 v2.14
                    mv /opt/share/unbound/configs/adblock/blocksites /opt/share/unbound/configs     # v2.15 Hack
                else
                    echo -e $cBCYA"Custom '/opt/share/unbound/configs/blocksites' already exists - ${cBGRE}'adblock/blocksites'$cRESET download skipped"$cBGRA
                fi

                if [ ! -f /opt/share/unbound/configs/allowsites ];then
                    download_file /opt/share/unbound/configs adblock/allowsites  juched   dos2unix
                    mv /opt/share/unbound/configs/adblock/allowsites /opt/share/unbound/configs
                else
                    echo -e $cBCYA"Custom '/opt/share/unbound/configs/allowsites' already exists - ${cBGRE}'adblock/allowsites'$cRESET download skipped"$cBGRA
                fi
            else                                                                          # v2.17
                if [ ! -f /opt/share/unbound/configs/sites ];then                       # v2.14
                    download_file /opt/share/unbound/configs adblock/sites  juched   dos2unix   # v2.17 v2.14
                    mv /opt/share/unbound/configs/adblock/sites /opt/share/unbound/configs      # v2.15 Hack
                else
                    echo -e $cBCYA"Custom '/opt/share/unbound/configs/sites' already exists - ${cBGRE}'adblock/sites'$cRESET download skipped"$cBGRA
                fi
            fi

            if [ ! -f /opt/share/unbound/configs/blockhost ];then                          # v2.15
                download_file /opt/share/unbound/configs  adblock/blockhost juched   dos2unix   # v2.17 v2.14 v2.02 v1.17
                mv /opt/share/unbound/configs/adblock/blockhost /opt/share/unbound/configs # v2.15 Hack
            else
                echo -e $cBCYA"Custom '/opt/share/unbound/configs/blockhost' already exists - ${cBGRE}'adblock/blockhost'$cRESET download skipped"$cBGRA
            fi

            if [ ! -f /opt/share/unbound/configs/allowhost ];then                          # v2.15
                download_file /opt/share/unbound/configs  adblock/allowhost juched   dos2unix   # v2.17 v2.15
                mv /opt/share/unbound/configs/adblock/allowhost /opt/share/unbound/configs # v2.15 Hack
            else
                echo -e $cBCYA"Custom '/opt/share/unbound/configs/allowhost' already exists - ${cBGRE}'adblock/allowhost'$cRESET download skipped"$cBGRA
            fi

            rmdir /opt/share/unbound/configs/adblock  2>/dev/null                            # v2.18 v2.15 Hack

            if [ -n "$(grep -E "^#[\s]*include:.*adblock/adservers" ${CONFIG_DIR}unbound.conf)" ];then             # v1.07
                echo -e $cBCYA"Adding Ad and Tracker blocker (Ad Block)'include: ${CONFIG_DIR}adblock/adservers'"$cRESET
                sed -i "/adblock\/adservers/s/^#//" ${CONFIG_DIR}unbound.conf                                       # v1.11
            fi

            # Create cron job to refresh the Ads/Tracker lists  # v1.07
            echo -e $cBCYA"Creating Daily cron job for Ad and Tracker update"$cBGRA
            cru d adblock 2>/dev/null
            cru a adblock "0 5 * * *" ${CONFIG_DIR}adblock/gen_adblock.sh   # v1.0.3 Restarts unbound using 'unbound_manager restart' to save/restore cache

            [ ! -f $FN ] && { echo "#!/bin/sh" > $FN; chmod +x $FN; }           # v3.11
            if [ -z "$(grep -E "gen_adblock" /jffs/scripts/services-start | grep -v "^#")" ];then
                $(Smart_LineInsert "$FN" "$(echo -e "cru a adblock \"0 5 * * * ${CONFIG_DIR}adblock/gen_adblock.sh\"\t# unbound_manager")" )  # v3.11 Hotfix v1.13
            fi

            chmod +x $FN                                            # v1.11 Hack????

            echo -e $cBCYA"Executing '${CONFIG_DIR}adblock/gen_adblock.sh'....."$cBGRA
            chmod +x ${CONFIG_DIR}adblock/gen_adblock.sh
            [ -n "$(pidof unbound)" ] && sh ${CONFIG_DIR}adblock/gen_adblock.sh || { sh ${CONFIG_DIR}adblock/gen_adblock.sh; Restart_unbound; }   # v2.18 v1.0.3

            # v3.12 v2.18 Track Ad Block blocked domains to log (auto if 'sgui' ENABLED)
            if [ "$1" == "track" ] || [ -f /jffs/addons/unbound/unboundstats_www.asp ];then      # v3.12 v2.18 Hotfix
                echo -e $cBCYA"Logging Ad Block BLOCKED domains to log"$cRESET   # v3.12
                Edit_config_options "log-local-actions:"   "uncomment"          # v2.18 Hotfix Track blocked Ad Block domains
            fi

            echo -e $cBCYA
        else
            echo -e $cBCYA"Updating Ads and Tracker Blocking....."$cBGRA     # v3.10
            sh /opt/var/lib/unbound/adblock/gen_adblock.sh                    # v3.10
            echo -en $cRESET
        fi
    else
        # v2.18 uninstall Ad Block
        echo -e
        AUTO_REPLY3=
        if [ -n "$(grep -E "^include:.*adblock/adservers" ${CONFIG_DIR}unbound.conf)" ];then    # v2.18 Hotfix
            echo -e $cBCYA"Removing Ad and Tracker 'include: ${CONFIG_DIR}adblock/adservers'"$cRESET
            sed -i "/adblock\/adservers/s/^i/#i/" ${CONFIG_DIR}unbound.conf
        fi

        if [ -n "$(grep -E "^log-local-actions:" ${CONFIG_DIR}unbound.conf)" ];then
            Edit_config_options "log-local-actions:"   "comment"            # v2.18 Hotfix
        fi

        # Remove Ad and Tracker cron job /jffs/scripts/services-start   # v1.07
        echo -e $cBCYA"Removing Ad and Tracker (Ad Block) Update cron job"$cRESET   # v3.11
        if grep -qF "gen_adblock" $FN; then
            sed -i '/gen_adblock/d' $FN
        fi

        cru d adblock 2>/dev/null

        CURRENT_AUTO_OPTIONS=$(echo "$CURRENT_AUTO_OPTIONS" | sed 's/3//' | sed 's/^ //')   # v2.18 Hotfix Remove option from AUTO install
    fi

}
Option_YouTube_Adblock() {

    local ANS=$1
    shift
    if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
    fi

    if [ "$USER_OPTION_PROMPTS" == "?" ] || [  "$ANS" == "?" ];then
        echo -e "\nDo you want to install YouTube Video Ad blocking?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
        read -r "ANS"
    fi
    [ "$ANS" == "y"  ] && { YouTube_Adblock "$@" ; return 0; } || return 1   # v3.11
}
YouTube_Adblock() {                                                          # v3.11

    local FN="/jffs/scripts/services-start"

    if [ "$1" != "uninstall" ];then                                                 # v2.18

        if [ "$1" != "update" ];then
            echo -e $cBCYA"Installing YouTube Video Ad Blocking....."$cRESET     # v3.11

            download_file ${CONFIG_DIR} adblock/gen_ytadblock.sh  juched  dos2unix   # vv3.12 3.11

            # Create cron job to refresh the YouTub Ads/Tracker lists                         # v3.11
            echo -e $cBCYA"Creating Daily cron job for YouTube Ad Tracker update"$cBGRA       # v3.11
            cru d ytadblock 2>/dev/null
            cru a ytadblock "*/5 * * * *" ${CONFIG_DIR}adblock/gen_ytadblock.sh                 # v3.11 Hotfix v3.11

            [ ! -f $FN ] && { echo "#!/bin/sh" > $FN; chmod +x $FN; }
            if [ -z "$(grep -E "gen_ytadblock" /jffs/scripts/services-start | grep -v "^#")" ];then   # v3.11 Hotfix
                $(Smart_LineInsert "$FN" "$(echo -e "cru a ytadblock \"*/5 * * * * ${CONFIG_DIR}adblock/gen_ytadblock.sh\"\t# unbound_manager")" )   # v3.11 Hotfix
            fi

            chmod +x $FN                                            # v1.11 Hack????

            echo -e $cBCYA"Executing '${CONFIG_DIR}adblock/gen_ytadblock.sh'....."$cBGRA
            chmod +x ${CONFIG_DIR}adblock/gen_ytadblock.sh
            sh ${CONFIG_DIR}adblock/gen_ytadblock.sh                         # v3.11

            echo -e $cBCYA
        else
            echo -e $cBCYA"Updating YouTube Video Ad Blocking....."$cBGRA     # v3.11
            sh /opt/var/lib/unbound/adblock/gen_ytadblock.sh                  # v3.11
            echo -en $cRESET
        fi
    else
        # v3.11 uninstall YouTube Ad Block
        echo -e
        AUTO_REPLY12=

        # Remove YouTube Video Ad cron job /jffs/scripts/services-start # v3.11
        if grep -qF "gen_ytadblock" $FN; then
            sed -i '/gen_ytadblock/d' $FN
        fi

        cru d ytadblock 2>/dev/null                                     # v3.11
        echo -e $cBCYA"Removing YouTube Video Ad Server YT IP"$cRESET
        rm -rf /opt/share/unbound/configs/ipytforce 2>/dev/null
        rm -rf /opt/var/lib/unbound/adblock/gen_ytadblock.sh 2>/dev/null
        rm -rf /opt/var/lib/unbound/adblock/ytadblock 2>/dev/null

        Restart_unbound                                                 # v3.11 Hotfix
    fi
}
Option_Disable_Firefox_DoH() {

        local ANS=$1                                        # v1.20

        if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
            echo -en $cBYEL"Option Auto Reply 'y'\t"
        fi

        if [ "$USER_OPTION_PROMPTS" == "?" ];then
            echo -e "\nDo you want to DISABLE Firefox DNS-over-HTTPS (DoH)? (USA users)\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
            read -r "ANS"
        fi
        [ "$ANS" == "y"  ] && Disable_Firefox_DoH           # v1.18

}
Disable_Firefox_DoH() {

    if [ -z "$1" ] || [ "$1" == "yes" ];then                                               # v3.16
        echo -e $cBCYA"Installing Firefox DNS-over-HTTPS (DoH) DISABLE/Blocker...."$cRESET
        download_file ${CONFIG_DIR} adblock/firefox_DOH juched                                         # v3.23 v2.02 v1.18

        if [ -n "$(grep -E "^#[\s]*include:.*adblock/firefox_DOH" ${CONFIG_DIR}unbound.conf)" ];then    # v1.18
            echo -e $cBCYA"Adding Firefox DoH 'include: ${CONFIG_DIR}adblock/firefox_DOH'"$cRESET
            sed -i "/adblock\/firefox_DOH/s/^#//" ${CONFIG_DIR}unbound.conf
        fi
    else
        echo -e $cBCYA"Removing Firefox DNS-over-HTTPS (DoH) DISABLE/Blocker"$cRESET       # v3.16
        sed -i "s/\(^include:.*adblock\/firefox_DOH.*$\)/#\1/" ${CONFIG_DIR}unbound.conf   # v3.16
    fi

}
Option_Disable_dnsmasq() {                              # v3.10

        local ANS=$1
        shift

        if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y" ];then
            echo -en $cBYEL"Option Auto Reply 'y'\t"
        fi

        if [ "$USER_OPTION_PROMPTS" == "?" ] || [ "$ANS" == "?" ];then
            local TXT="\tIf you currently use or rely on dnsmasq features such as ${cBCYA}Diversion/x3mRouting${cRESET} etc., then re-consider."
            [ "$(nvram get ipv6_service)" != "disabled" ] && TXT=${TXT}$cRESET"\n\n\t\tWarning "$cBRED"IPv6 not fully supported."   # v3.16
            if [ -f /opt/share/diversion/.conf/diversion.conf ] && [ "$(grep -E "^DIVERSION_STATUS" /opt/share/diversion/.conf/diversion.conf)" == "DIVERSION_STATUS=enabled" ];then    # v3.11 Hotfix
               local TXTX="\n\n\t\t"$cRESET"Warning"$cBRED" Diversion is ACTIVE (It will be auto-DISABLED if Ad Block is ACTIVE)" # v3.15 v3.11
            fi
            echo -e ${cRESET}$cBWHT${TXT}${TXTX}
            echo -e $cRESET"\n\tDo you still want to ${cBRED}DISABLE dnsmasq${cRESET}?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
            read -r "ANS"
        fi
        [ "$ANS" == "y"  ] && Disable_dnsmasq "$@"

}
Disable_dnsmasq() {                                     # v3.10
_quote() {
  echo $1 | sed 's/[]\/()$*.^|[]/\\&/g'
}

        local ARG=$1
        local ROUTER="$(nvram get lan_ipaddr_rt)"      # v3.10 Hotfix
        [ $(echo "$ROUTER" | awk '{print NF}') -eq 2 ] && ROUTER=$(echo "$ROUTER" | tr " " ",")                             # v3.23 @juched
        local UNBOUND_LISTEN=$ROUTER                  # v3.11 Hotfix
        local UNBOUND_LISTENSED=$(_quote "$UNBOUND_LISTEN")

        local FN="/opt/share/unbound/configs/unbound.conf.localhosts"

        if [ "$ARG" == "disable" ];then
            echo -e $cBCYA"\n"$(date "+%H:%M:%S")" Configuring "$cRESET"unbound"$cBCYA" to be the "$cRESET"primary DNS"$cBCYA" for ALL LAN Clients....."$cRESET
            sed -i "/^port: 53535/ s/[^ ]*[^ ]/53/2" ${CONFIG_DIR}unbound.conf
            sed -i "/^interface: 127\.0\.0\.1@53535/ s/[^ ]*[^ ]/$UNBOUND_LISTENSED/2" ${CONFIG_DIR}unbound.conf
            Edit_config_options "interface: 127.0.0.1@53" "uncomment"
            [ "${ROUTER:0:8}" != "192.168." ] && sed -i "s~^#access-control: 0\.0\.0\.0/0 allow~access-control: $UNBOUND_LISTENSED/24 allow~1" ${CONFIG_DIR}unbound.conf
            #=====================================TEMPORARY HACK PENDING 'unbound.conf' v1.10 ===========================================
            #sed -i 's~access-control: 192.168.0.0/24 allow~access-control: 192.168.0.0/16 allow~' ${CONFIG_DIR}unbound.conf   # v3.22 v3.10 Hotfix
            #============================================================================================================================

            [ -z "$(grep -F "port=0" /jffs/configs/dnsmasq.conf.add)" ] && echo -e "port=0                           # unbound_manager" >> /jffs/configs/dnsmasq.conf.add
            [ -z "$(grep -F "dhcp-option=lan,6,$ROUTER" /jffs/configs/dnsmasq.conf.add)" ] && echo -e "dhcp-option=lan,6,$ROUTER      # unbound_manager" >> /jffs/configs/dnsmasq.conf.add

            # v386.xx Guest SSID VLANs need to ensure 'dhcp-option=brX,6,<dnsip>' to 'dnsmasq.conf.add' for DNS     # v3.22 @juched
            # see http://www.snbforums.com/threads/thread-1-386-1_alpha-build-s-testing-available-build-s.67101/post-631652     # v3.22 @juched
            # e.g brctl show
            #
            #   bridge name bridge id       STP enabled interfaces
            #   br0     8000.40xxxxxxxxxx   yes         eth1
            #                                           eth2
            #                                           eth3
            #                                           eth4
            #                                           eth5.0
            #                                           eth6.0
            #                                           wl0.2
            #                                           wl0.3
            #   br1     8000.40xxxxxxxxxx   yes         eth1.501
            #                                           eth2.501
            #                                           eth3.501
            #                                           eth4.501
            #                                           eth5.501
            #                                           eth6.501
            #                                           wl0.1
            #   br2     8000.40xxxxxxxxxx   yes         eth1.502
            #                                           eth2.502
            #                                           eth3.502
            #                                           eth4.502
            #                                           eth5.502
            #                                           eth6.502
            #                                           wl1.1

            if [ $FIRMWARE -ge 38600 ];then                                                     # v3.22
                    ROUTER=$(nvram get wan0_dns)                                                    # v3.22

                    if [ -n "$(brctl show | grep -E "^br[1-9].*\.50" | awk '{print $1}')" ];then     # v3.22
                            echo -e "# v386.xx Guest VLAN DNS" >> /jffs/configs/dnsmasq.conf.add    # v3.22
                            local VLAN_INTERFACES=$(brctl show | grep -E "^br[1-9].*\.50" | awk '{print $1}' | tr "\n" " ") # v3.22
                            local I=1
                            for BR in  $VLAN_INTERFACES  # v3.22
                                do
                                    if [ $I -eq 1 ];then
                                        local POS=$(grep -nE "^interface: 127.0.0.1@53" ${CONFIG_DIR}unbound.conf | cut -d':' -f1 | tail -n 1)  # v3.22
                                        sed -i '/AiMesh Guest SSID VLAN TAG/d' ${CONFIG_DIR}unbound.conf
                                        local I=$((I+1))
                                    fi
                                    [ -z "$(grep -F "dhcp-option=$BR,6,$ROUTER" /jffs/configs/dnsmasq.conf.add)" ] && echo -e "dhcp-option=$BR,6,$ROUTER      # unbound_manager" >> /jffs/configs/dnsmasq.conf.add  # v3.22
            # http://www.snbforums.com/threads/unbound_manager-manager-installer-utility-for-unbound-recursive-dns-server-general-questions-discussion-thread-2.67968/post-645861
                                    local VLAN_IPADDR=$(ifconfig $BR | grep inet  | tr ":" " " | awk ' {print $3}')
                                    [ -z "$(grep -F "interface: $VLAN_IPADDR" ${CONFIG_DIR}unbound.conf)" ] && sed -i "${POS}ainterface: $VLAN_IPADDR@53\t\t# v1.12 AiMesh Guest SSID VLAN TAG (dnsmasq disabled) @juched" ${CONFIG_DIR}unbound.conf  # v3.22 @juched
                                done
                    fi
            fi                                                                                  # v3.22
            #
            Convert_dnsmasq_LocalHosts                                              # v3.16

            # Migrate 'address=/' and 'server=/' directives                 # v3.15
            # e.g.
            #       address=/siteX.com/127.0.0.1            local-zone: "siteX.com. A 127.0.0.1"
            #       address=/use-application-dns.net/       local-zone: "use-application-dns.net." always_nxdomain
            #
            #       server=/uk.pool.ntp.org/1.1.1.1         forward-zone:
            #                                                   name: "uk.pool.ntp.org"
            #                                                   forward-addr: 1.1.1.1
            #                                                   forward-first: yes
            #
            echo -e ${cBCYA}$(date "+%H:%M:%S")" Converting dnsmasq 'address=/' and 'server=/' directives to 'unbound'....."$cRESET
            echo -e "\n\n# Replicate dnsmasq 'address=' and 'server='  directives\n" >> $FN
            if [ -n "$(grep -E "^server=|^local=|^address=" /etc/dnsmasq.conf)" ];then   # v3.16
                for LINE in $(awk '/^address=/ || /^server=/ {print $0}' /etc/dnsmasq.conf | sort | uniq)
                    do
                        local IP_ADDR=
                        local DOMAINS=
                        local LINE="$(echo "$LINE" | tr '=/' ' ')"

                        if [ "${LINE:0:7}" == "address" ];then
                            local LINE="$(echo "$LINE" | sed 's/^address //' )"
                            if [ $(echo "$LINE" | awk '{print NF}') -ne 1 ];then
                                local IP_ADDR=$(echo "$LINE" | awk '{print $NF}')
                                [ -n "$(echo "$IP_ADDR" | Is_IPv4)" ] && local RTYPE="A" || local RTYPE="AAAA"
                                local DOMAINS=$(echo "$LINE" | awk 'NF{--NF};1')
                            else
                                local DOMAINS=$(echo "$LINE" | awk '{print $NF}')
                            fi
                            for NAME in $DOMAINS
                                do
                                    [ "$NAME" == "#" ] && continue   # 'address=/#/xxx.xxx.xxx.xxx' --> 'local-zone ". xxx.xxx.xxx.xxx A" static' ???
                                    # Prevent duplicate Firefox DoH 'local-zone: "use-application-dns.net" always_nxdomain' if already implemented
                                    if [ "$NAME" == "use-application-dns.net" ] && [ -n "$(grep -E "^include:.*adblock/firefox_DOH" ${CONFIG_DIR}unbound.conf)" ];then   # v.315 Hotfix @tomsk v3.15 @ttgapers
                                       continue
                                    fi
                                    if [ -z "$IP_ADDR" ];then
                                       echo -e "local-zone: \""$NAME".\" always_nxdomain" >> $FN
                                    else
                                       echo -e "local-zone: \""$NAME". "$RTYPE $(echo "$IP_ADDR" | sed 's/#.*$//')"\" static" >> $FN
                                    fi
                                done
                        else
                            local LINE="$(echo "$LINE" | sed 's/^server // ; s/^local //' )"
                            if [ $(echo "$LINE" | awk '{print NF}') -ne 1 ];then
                                local IP_ADDR=$(echo "$LINE" | awk '{print $NF}')
                                local DOMAINS=$(echo "$LINE" | awk 'NF{--NF};1')
                                for NAME in $DOMAINS
                                    do
                                        [ "$NAME" == "127.0.0.1#53535" ] && continue
                                        echo -e "forward-zone:\n\tname: \""$NAME"\"\n\tforward-addr: "$(echo "$IP_ADDR" | sed 's/#.*$//')"\n\tforward-first: yes" >> $FN          # v3.16 @Slawek P
                                    done
                            fi
                        fi
                    done
            fi

            if [ -f /jffs/configs/dnsmasq.conf.add ];then                       # v3.22
                if [ $(grep -Ec "^host-record=[safe|force]" /jffs/configs/dnsmasq.conf.add) -gt 0 ];then
                    echo -e ${cBCYA}$(date "+%H:%M:%S")" Converting dnsmasq Safe search domains 'host-record=safe*/force*' directives to 'unbound'....."$cRESET
                    Configure_SafesearchDomains # v3.22
                fi
            fi

            # Must be processed last as 'dnsmasq {nointerfaces | interfaces} wipes every thing from first interface to EOF!
            Convert_dnsmasq_Interfaces

            echo -e $cBCYA"\n"$(date "+%H:%M:%S")" Checking 'include: unbound.conf.localhosts' ....."$cRESET
            Check_config_add_and_postconf                       # v3.10

            echo -en $cBCYA"\n"$(date "+%H:%M:%S")" Restarting "$cRESET"dnsmasq"$cBGRE   # v3.10 Hotfix
            service restart_dnsmasq
         else
            echo -e $cBCYA"\n"$(date "+%H:%M:%S")" Configuring "$cRESET"dnsmasq"$cBCYA" to be the "$cRESET"primary DNS"$cBCYA" for ALL LAN Clients.....\n"$cRESET
            [ -n "$(grep "^interface: 127.0.0.1@53 " ${CONFIG_DIR}unbound.conf)" ] && sed -i 's/\(^interface: 127\.0\.0\.1@53 \)/#\1/' ${CONFIG_DIR}unbound.conf   # v3.11 Hotfix
            sed -i "/^port: 53/ s/[^ ]*[^ ]/53535/2" ${CONFIG_DIR}unbound.conf
            sed -i "/^interface: $UNBOUND_LISTENSED/ s/[^ ]*[^ ]/127\.0\.0\.1@53535/2" ${CONFIG_DIR}unbound.conf
            if [ -n "$(grep "^access-control: $UNBOUND_LISTEN/24 allow" ${CONFIG_DIR}unbound.conf)" ];then
                sed -i "s~^access-control: $UNBOUND_LISTENSED/24 allow~#access-control: 0\.0\.0\.0/0 allow~1" ${CONFIG_DIR}unbound.conf   # v3.10 Hotfix
            fi

            [ -n "$(grep -F "port=0" /jffs/configs/dnsmasq.conf.add)" ] && sed -i '/port=0/d' /jffs/configs/dnsmasq.conf.add   # v3.10 Hotfix
            [ -n "$(grep -F "dhcp-option=lan,6,$ROUTER" /jffs/configs/dnsmasq.conf.add)" ] && sed -i "/dhcp-option=lan,6,$ROUTER/d" /jffs/configs/dnsmasq.conf.add   # v3.10 Hotfix

            local TO="$(awk '/^include.*\/opt\/share\/unbound\/configs\/unbound\.conf\.localhosts\"/ {print NR}' "${CONFIG_DIR}unbound.conf")";local FROM=$((TO - 1))
            [ -n "$TO" ] && sed -i "$FROM,$TO d" ${CONFIG_DIR}unbound.conf                     # v3.16

            sed -i '/AiMesh Guest SSID VLAN TAG/d' ${CONFIG_DIR}unbound.conf        # v3.22

            # Wipe the 'include: unbound.conf.localhosts'
            #true > $FN                                                     # v3.16
        fi

        Restart_unbound
        local RC=$?

        if [ $RC -eq 0 ];then
            # @tomsk , if bypass dnsmasq and Diversion is running then replace with Ad Block   # v3.10
            if [ "$ARG" == "disable" ];then
               if [ -f /opt/share/diversion/.conf/diversion.conf ] && [ "$(grep -E "^DIVERSION_STATUS" /opt/share/diversion/.conf/diversion.conf)" == "DIVERSION_STATUS=enabled" ];then    # v3.11 Hotfix

                  # If Ad Block not installed then install Ad Block
                  if [ "$(Get_unbound_config_option "adblock/adservers" ${CONFIG_DIR}unbound.conf)" == "?" ];then   # v3.16
                     Option_Ad_Tracker_Blocker "?"
                  fi

                  # If Ad Block installed then disable Diversion
                  if [ "$(Get_unbound_config_option "adblock/adservers" ${CONFIG_DIR}unbound.conf)" != "?" ];then
                     # Prompt to manually terminate Diversion or kill it dead?          # v3.10
                     echo -e $cBCYA"\n"$(date "+%H:%M:%S")" Terminating 'Diversion'....."$cRESET
                     /opt/bin/diversion disable
                  fi
               fi
            else
               # dnsmasq reinstated so restart Diversion if installed and it isn't already UP; then stop Ad Block
               if [ -n "$(which diversion)" ];then
                  if [ -f /opt/share/diversion/.conf/diversion.conf ] && [ "$(grep -E "^DIVERSION_STATUS" /opt/share/diversion/.conf/diversion.conf)" == "DIVERSION_STATUS=disabled" ];then    # v3.11 Hotfix
                     echo -e $cBCYA"\n"$(date "+%H:%M:%S")" Starting 'Diversion'....."$cRESET
                     /opt/bin/diversion enable
                  fi
                  Ad_Tracker_blocking "uninstall"                                   # v3.11 Only terminate if Diversion running
               fi
            fi
        fi

        echo -en $cRESET

}
Convert_dnsmasq_LocalHosts() {

        local FN="/opt/share/unbound/configs/unbound.conf.localhosts"

        local DOMAIN=$(nvram get lan_domain)
        if [ -n "$DOMAIN" ];then                                                # v3.10 Hotfix @dave14305/@milan
            echo -e $cBCYA"\n"$(date "+%H:%M:%S")" Converting NVRAM 'dhcp_staticlist' local hosts to 'unbound'....."$cRESET
            echo -e "# Replicate NVRAM 'dhcp_staticlist','/etc/hosts' and '/var/lib/misc/dnsmasq.leases' local hosts\n\nprivate-domain: \""$DOMAIN"\"\n\nlocal-zone: \""$DOMAIN".\" static\n\n" > $FN

            # If dnsmasq is no longer the DNS resolver for the LAN , we need to add the localhosts into unbound
            #   1. NVRAM dhcp_staticlist
            #   2. /etc/hosts
            #   3. /var/lib/misc/dnsmasq.leases - refrsh cron or dhcp lease script?
            for PAIR in $(nvram get dhcp_staticlist | tr '<' ' ')
                do
                    local NAME=                                             # v3.11
                    local MAC=$(echo "$PAIR" | cut -d'>' -f1)
                    local IP_ADDR=$(echo "$PAIR" | cut -d'>' -f2)
                    [ -f /etc/hosts.dnsmasq ] && local NAME="$(awk -v ip="${IP_ADDR}" '$1 == ip {print $2}' /etc/hosts.dnsmasq)"   # v3.11 Hotfix @glehel
                    [ -z "$NAME" ] && local NAME=$(nvram get dhcp_hostnames | tr '<>' ' ' | grep -oE "$MAC.*" | cut -d' ' -f2)
                    if [ -n "$NAME" ];then                                                                      # v3.11
                        echo -e $IP_ADDR";"$NAME >> /tmp/localhosts
                    else
                        echo -e $cBRED"\a\tWarning: $MAC ($IP_ADDR) not found in '/etc/hosts.dnsmasq' or 'nvram get dhcp_hostnames'"   # v3.11
                    fi
                done

            if [ -f /etc/hosts ] || [ -f /jffs/addons/YazDHCP.d/.staticlist ] || [ -f /var/lib/misc/dnsmasq.leases ];then      # v3.22 v3.16 v3.15
                [ -f /jffs/addons/YazDHCP.d/.staticlist ] && awk 'BEGIN { -F","; OFS = ";"; ORS = "\n"  } {print $3}' /var/lib/misc/dnsmasq.leases >> /tmp/localhosts    # v3.22
                [ -f /etc/hosts.dnsmasq ] && cat /etc/hosts.dnsmasq | tr ' ' ';' >> /tmp/localhosts               # v3.22 v3.16
                [ -f /var/lib/misc/dnsmasq.leases ] && awk 'BEGIN { OFS = ";"; ORS = "\n"  } {print $3,$4}' /var/lib/misc/dnsmasq.leases >> /tmp/localhosts   # v3.16
            fi
            if [ -f /tmp/localhosts ];then
                echo -e ${cBCYA}$(date "+%H:%M:%S")" Converting '/etc/hosts.dnsmasq'/'/var/lib/misc/dnsmasq.leases' local hosts to 'unbound'....."$cRESET
                for LINE in  $(sort -t. -g -k4 /tmp/localhosts | uniq)                # v3.16
                    do
                        IP_ADDR="$(echo "$LINE" | awk -F";" '{print $1}')"
                        [ -n "$(echo "$IP_ADDR" | Is_IPv4)" ] && local RTYPE="A" || local RTYPE="AAAA"
                        NAME="$(echo "$LINE" | awk -F";" '{print $2}')"
                        if [ "$NAME" != "*" ] && [ -n "$NAME" ];then
                           local VALID=
                        else
                           local VALID="#"
                        fi
                        echo -e $VALID"local-data: \""$NAME"."$DOMAIN". IN "$RTYPE $IP_ADDR"\"\n"$VALID"local-data-ptr: \""$IP_ADDR $NAME"\"\n" >> $FN
                    done
                rm /tmp/localhosts
            fi
        else
           echo -e $cBRED"\a\tWarning: Cannot replicate dnsmasq's local hosts; Blank router domain name; see $HTTP_TYPE://$(nvram get lan_ipaddr):$HTTP_PORT/Advanced_LAN_Content.asp LAN->LAN-IP $HARDWARE_MODEL's Domain Name\n" 2>&1
        fi
}
Convert_dnsmasq_Interfaces() {

        local FN="/opt/share/unbound/configs/unbound.conf.localhosts"

        # Add additional 'interfaces:'                                                              # v3.16
        echo -e ${cBCYA}$(date "+%H:%M:%S")" Converting dnsmasq 'interface=/' directives to 'unbound'....."$cRESET
        echo -e "\n\n# Replicate dnsmasq 'interface=' directives\n\nserver:\nip-freebind: yes\t\t# Allow interfaces DOWN during say reboot.\n" >> $FN       # v3.17 Hotfix @tomsk
        for INTERFACE in $(awk -F"=" '/^interface/ {print $2}' /etc/dnsmasq.conf | grep -v -E "br0$|pptp*")
            do
                local IP_ADDR=$(grep "$INTERFACE,3," /etc/dnsmasq.conf | cut -d',' -f3)     # v3.16
                # unbound only accepts ACTIVE interfaces?
                if [ -n "$(ip -o -4 addr | grep -o "inet $IP_ADDR/")" ];then
                   local VALID=
                else
                   local VALID="#"
                fi
                # 'access-control: xxx.xxx.xxx.0/nn allow' should already explicitly be in 'unbound.conf'
                [ -n "$IP_ADDR" ] && echo -e $VALID"interface: "$IP_ADDR"\t\t# "$INTERFACE >> $FN   # v3.16
            done
}
Manage_unbound_Views() {                                                   # 3.17
_quote() {
  echo $1 | sed 's/[]\/()$*.^|[]/\\&/g'
}
        # [ {viewname { '?' | 'remove' } ] | {viewname DOMAIN [ ip_address] } | {viewname ip_address ['del']} ]

        local VIEWNAME=$1
        local ARG2=$2
        local ACTIONDEL=$3

        local STATUS=0               # 0-Restart unbound;1- Don't Restart unbound
        local CREATED=0
        local ADD_DOMAIN_CNT=0;local ADD_IP_CNT=0

        local FN="/opt/share/unbound/configs/unbound.conf.views"

        local VALID_VIEW_TYPES="deny refuse static transparent redirect nodefault typetransparent inform inform_deny inform_redirect always_transparent always_refuse always_nxdomain noview"   # v3.17 Hotfix

        VIEW_TYPE="refuse"                  # v3.17 Hotfix

        if [ "$1" != "uninstall" ] && [ "$1" != "disable" ] && [ "$1" != "remove" ];then
            if [ "$VIEWNAME" == "?" ] || [ -n "$ARG2" ];then
                if [ "$1" != "?" ];then
                    if [ "$ARG2" == "remove" ] || [ "$ARG2" == "flush" ] || [ "$ARG2" == "erase" ] || [ "$ARG2" == "delete" ];then
                        if [ -n "$(grep "name:.*$VIEWNAME" $FN)" ];then
                           # Identify the actual 'types' used
                           local VALID_VIEW_TYPES=$(awk -v pattern="local-zone.*${VIEWNAME}\"" '$0 ~ pattern {print $3}' /opt/share/unbound/configs/unbound.conf.views | sort | uniq | tr '\n' ' ')
                           # Differentiate between the two main elements
                           local VIEW_ZONE_DOMAINS=$(awk -v pattern="local-zone.*${VIEWNAME}\"" '$0 ~ pattern {print $3}' /opt/share/unbound/configs/unbound.conf.views | tr '\n' ' ')
                           local VIEW_DATA_RRS=$(awk -v pattern="local-data.*${VIEWNAME}\"" '$0 ~ pattern {print $0}' /opt/share/unbound/configs/unbound.conf.views | tr '\n' ' ')
                           local VALID_DATA_DOMAINS=$(awk -v pattern="local-zone.*${VIEWNAME}\"" '$0 ~ pattern {print $2}' /opt/share/unbound/configs/unbound.conf.views | sort | uniq | tr '\n' ' ')
                           if [ -n "$VALID_VIEW_TYPES" ];then
                                echo -e $cBCYA"\n\tRemoving unbound view: name: ${cRESET}\"${VIEWNAME}\" $cBCYA'types='"$VALID_VIEW_TYPES
                           fi
                           for DOMAIN in $VIEW_ZONE_DOMAINS
                                do
                                    unbound-control -q view_local_zone_remove $VIEWNAME $DOMAIN
                                done
                           for DOMAIN in $VIEW_DATA_DOMAINS
                                do
                                    unbound-control -q view_local_data_remove $VIEWNAME $DOMAIN
                               done
                           sed -i "/^# View.*$VIEWNAME/,/^# EndView.*$VIEWNAME/d" $FN
                           sed -i "/^access-control-view:.*$VIEWNAME/d" $FN
                           echo -e $cBCYA"\n\tunbound view: name: \"$VIEWNAME\" deleted\n"$cRESET 2>&1
                        else
                            echo -e $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED doesn't exist!\n"$cRESET 2>&1
                            local STATUS=1
                        fi
                    else
                        if [ "$ARG2" != "?" ];then
                            if [ -n "$(echo "$ARG2" | sed 's~/.*$~~' | Is_IPv4)" ] || [ -n "$(echo "$ARG2" | Is_Private_IPv6)" ];then
                                if [ -n "$(echo "$ARG2" | Is_Private_IPv4)" ] || [ -n "$(echo "$ARG2" | Is_Private_IPv6)" ];then
                                    local IP_ADDR=$ARG2
                                    [ -z "$(echo "$IP_ADDR" | Is_IPv4_CIDR)" ] && local CIDR="/32" || local CIDR=
                                    if [ -n "$(grep "$VIEWNAME\"" $FN)" ];then
                                        if [ "$ACTIONDEL" == "del" ];then
                                            local IP_ADDR_SED=$(_quote "$IP_ADDR")
                                            sed -i "/^access-control-view:.*$IP_ADDR_SED/d" $FN
                                            echo -e $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA removed "${cBGRE}${IP_ADDR}${CIDR}$cBCYA"\n"$cRESET 2>&1
                                        else
                                            if [ -z "$(grep "access-control-view: ${IP_ADDR}$CIDR" $FN)" ];then
                                                # Can't use Smart_LineInsert
                                                sed -i "/# View: Clients/aaccess-control-view: ${IP_ADDR}$CIDR \"$VIEWNAME\"" $FN
                                                echo -e $cBCYA"\n\tView: name: $cRESET\"$VIEWNAME\"$cBCYA added "${IP_ADDR}$CIDR"\n"$cRESET 2>&1
                                            else
                                                echo -e $cBRED"\a\n\t***ERROR unbound view: ${cRESET}\"${VIEWNAME}\"$cBRED already contains '${cRESET}${IP_ADDR}$CIDR$cBRED'!\n"$cRESET 2>&1
                                                local STATUS=1
                                            fi
                                        fi
                                    else
                                        echo -en $cBRED"\a\n\t***ERROR view name: ${cRESET}\"${VIEWNAME}\"$cBRED doesn't exist!\n"$cRESET 2>&1
                                        local STATUS=1
                                    fi
                                else
                                    echo -e $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED IP Address '${cRESET}${2}$cBRED' not a Private IPv4/IPv6 Address?!\n"$cRESET 2>&1
                                    local STATUS=1
                                fi
                            else
                                if [ -z "$(echo "$VALID_VIEW_TYPES" | grep -w "$VIEWNAME")" ];then       # v3.17 Hotfix
                                    if [ "$ACTIONDEL" != "del" ];then
                                        local ARG_LIST="$(echo "$menu1" | cut -d' ' -f3- )"

                                        local MATCH=
                                        MATCH="$(grep "$VIEWNAME\"" $FN)"
                                        if [ -z "$MATCH" ];then
                                            cat >> $FN << EOF
# View: $VIEWNAME
view:
    name: "$VIEWNAME"
    view-first: yes
EOF
                                            local CREATED=1
                                            echo -e $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA created "${TXT}"\n"$cRESET 2>&1
                                        fi

                                        # We have created the 'view:' ....now add its domains and client IP addresses
                                        echo
                                        local ADD_DOMAIN_CNT=0;local ADD_IP_CNT=0      # v3.17 Hotfix
                                        for ITEM in $ARG_LIST
                                            do
                                                [ "$ITEM" == "del" ] && continue
                                                [ -n "$(echo "$VALID_VIEW_TYPES" | grep -w "$ITEM")" ] && { local VIEW_TYPE=$ITEM; continue ; }   # v3.17 Hotfix
                                                if [ -n "$(echo "$ITEM" | sed 's~/.*$~~' | Is_IPv4)" ];then
                                                    local IP_ADDR=$ITEM
                                                        if [ -n "$(echo "$IP_ADDR" | sed 's~/.*$~~' | Is_Private_IPv4)" ] || [ -n "$(echo "$IP_ADDR" | Is_Private_IPv6)" ];then
                                                            IP_ADDR=$ITEM
                                                            [ -z "$(echo "$IP_ADDR" | Is_IPv4_CIDR)" ] && local CIDR="/32" || local CIDR=
                                                            if [ -z "$(grep "access-control-view: ${IP_ADDR}$CIDR \"$VIEWNAME\"" $FN)" ];then
                                                                # Can't use Smart_LineInsert
                                                                sed -i "/# View: Clients/aaccess-control-view: ${IP_ADDR}$CIDR \"$VIEWNAME\"" $FN
                                                                echo -e $cBCYA"\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA added $cRESET\"${IP_ADDR}${CIDR}\""$cRESET 2>&1
                                                                local ADD_IP_CNT=$((ADD_IP_CNT+1))                      # v3.17 Hotfix
                                                            else
                                                                echo -e $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED IP Address '${cRESET}${IP_ADDR}$cBRED' already exists!\n"$cRESET 2>&1
                                                            fi
                                                        else
                                                            echo -e $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED IP Address '${cRESET}${3}$cBRED' not a Private IPv4/IPv6 Address?!\n"$cRESET 2>&1
                                                            local STATUS=1
                                                        fi
                                                else               # Insert
                                                    local DOMAIN=$ITEM
                                                    [ -n "$(echo "$VALID_VIEW_TYPES" | grep -w "$ITEM")" ] && { local VIEW_TYPE=$ITEM;local TXT='type='$VIEW_TYPE; continue ; }   # v3.17 Hotfix
                                                    if [ -z "$(grep -E "local-zone: \"$DOMAIN.\" $VIEW_TYPE.*\"$VIEWNAME\""  $FN)" ];then
                                                        echo -en $cBRED
                                                        unbound-control -q view_local_zone $VIEWNAME $DOMAIN $VIEW_TYPE       # v3.17 Hotfix
                                                        if [ $? -eq 0 ];then
                                                            echo -e $cBCYA"\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA added domain $cRESET\"${DOMAIN}\" 'type=${VIEW_TYPE}'"$cRESET 2>&1
                                                            local ADD_DOMAIN_CNT=$((ADD_DOMAIN_CNT+1))                      # v3.17 Hotfix
                                                            # if type='redirect'; ask for the matching RR
                                                            if [ "$VIEW_TYPE" == "redirect" ];then
                                                                local RR=
                                                                echo -en $cBCYA"\n\t\tEnter RR for $cRESET\"$DOMAIN\" redirect e.g. IN A 192.168.5.1 ==>: " $cRESET 2>&1
                                                                read -r "RR"
                                                                echo -en $cBRED
                                                                unbound-control -q view_local_data "$VIEWNAME ${DOMAIN}. $RR"
                                                                echo -e $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA added domain $cRESET\"${DOMAIN}\" redirect RR '${RR}'"$cRESET 2>&1
                                                            fi
                                                            if [ $CREATED -eq 1 ];then
                                                                echo -e "    local-zone: \"$DOMAIN.\" $VIEW_TYPE\t\t# \"$VIEWNAME\"" >> $FN
                                                                [ -n "$RR" ] && echo -e "    local-data: \"${DOMAIN}. $RR\"\t\t# \"$VIEWNAME\"" >> $FN
                                                            else
                                                               sed -i "/^# EndView:.*$VIEWNAME/i\    local-zone: \"$DOMAIN\.\" $VIEW_TYPE\t\t# \"$VIEWNAME\"" $FN
                                                               if [ -n "$RR" ];then
                                                                    local RR_SED=$(_quote "$RR")
                                                                    sed -i "/^# EndView:.*$VIEWNAME/i\    local-data: \"$DOMAIN\. $RR_SED\"\t\t# \"$VIEWNAME\"" $FN
                                                               fi
                                                            fi
                                                        else
                                                            echo -en $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED type ${cRESET}\"${VIEW_TYPE}\"$cBRED INVALID!\n"$cRESET 2>&1
                                                            local STATUS=1
                                                        fi
                                                    else
                                                        echo -en $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED domain ${cRESET}\"${DOMAIN}\"$cBRED duplicate found!\n"$cRESET 2>&1
                                                        local STATUS=1
                                                    fi
                                                fi
                                            done
                                        if [ $CREATED -eq 1 ];then
                                            echo -e "# EndView: $VIEWNAME" >> $FN
                                            echo
                                            [ -z "$(grep "^include.*\"$FN\"" ${CONFIG_DIR}unbound.conf)" ] && echo -e "server:\ninclude: \"$FN\"\t\t# Custom server directives" >>  ${CONFIG_DIR}unbound.conf
                                        fi
                                    else                           # 'del'
                                        local DOMAIN=$ARG2
                                        if [ -n "$(grep -E "local-zone:.*\"${DOMAIN}.\".*\"${VIEWNAME}\"" $FN)" ];then
                                            local VIEW_ZONE_TYPE=$(awk -v pattern="local-zone:.*${VIEWNAME}\"" '$0 ~ pattern {print $3}' /opt/share/unbound/configs/unbound.conf.views)
                                            unbound-control -q view_local_zone_remove $VIEWNAME $DOMAIN
                                            sed -i "/local-zone:.*\"${DOMAIN}.\".*${VIEWNAME}\"/d" $FN
                                            echo -en $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA domain ${cRESET}\"${ARG2}\" type='$VIEW_ZONE_TYPE'$cBRED deleted\n"$cRESET 2>&1
                                            # If 'redirect' then delete its associated local-data RR
                                            if [ "$VIEW_ZONE_TYPE" == "redirect" ];then
                                                local RR="$(awk -v pattern="local-data.*$DOMAIN.*${VIEWNAME}\"" '$0 ~ pattern { $1=""; print $0}' /opt/share/unbound/configs/unbound.conf.views | sed 's/ #.*$// ; s/\"//g ; s/^ //' )"
                                                unbound-control -q view_local_data_remove $VIEWNAME $DOMAIN
                                                sed -i "/local-data:.*\"${DOMAIN}\..*${VIEWNAME}\"/d" $FN
                                                echo -en $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA domain ${cRESET}\"${RR}\"$cBRED deleted\n"$cRESET 2>&1
                                            fi

                                        else
                                            echo -en $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED domain ${cRESET}\"${DOMAIN}\"$cBRED not found!\n"$cRESET 2>&1
                                        fi
                                        local STATUS=1        # Domain deletes don't require physical Restart_unbound ?
                                    fi
                                else
                                    echo -en $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED cannot be any of the following:\n\n\t$cRESET'${VALID_VIEW_TYPES}'\n"   # v3.18 Hotfix v3.17 Hotfix
                                    local STATUS=1                                            # v3.18 Hotfix
                                fi
                            fi
                        else
                            if [ -z "$(grep "\"$VIEWNAME\""  $FN)" ] ;then
                                echo -en $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED not found!\n"$cRESET 2>&1
                            else
                                echo -e $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA Client entries\n"$cRESET 2>&1
                                #awk -v pattern="${VIEWNAME}" '$0~pattern{t=1}; t==1{print "\t"$0; if (/name:/){c++}}; c==1{exit}' $FN
                                awk -v pattern="${VIEWNAME}" '$0~"access-control-view" && $0~pattern {print "\t"$0}' $FN
                                echo -e $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA local-data entries\n"$cRESET 2>&1
                                unbound-control view_list_local_data  $VIEWNAME
                                echo -e $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA local-zones entries\n"$cRESET 2>&1
                                unbound-control view_list_local_zones $VIEWNAME
                                echo
                            fi
                            local STATUS=1
                        fi
                    fi
                else
                    if [ -n "$(grep "name:" $FN)" ];then
                        echo -e $cBCYA"\n\tCurrent unbound 'views:'\n"$cRESET
                        awk -v msgcolor="$cBCYA" '/name:/ {print "\t"$2}' $FN
                        echo -en $cRESET
                    else
                        echo -e $cBCYA"\n\tNo Current unbound 'views:'"$cRESET
                    fi
                    local STATUS=1
                fi
            else
                if [ -n "$(echo "$VIEWNAME" | sed 's~/.*$~~' | Is_IPv4)" ];then
                    echo -e $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED cannot be IPv4/IPv6 Address!\n"$cRESET 2>&1
                elif [ -n "$(grep "$VIEWNAME\""  $FN)" ];then
                        echo -e $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA Client entries\n"$cRESET 2>&1
                        #awk -v pattern="${VIEWNAME}" '$0~pattern{t=1}; t==1{print "\t"$0; if (/name:/){c++}}; c==1{exit}' $FN
                        awk -v pattern="${VIEWNAME}" '$0~"access-control-view" && $0~pattern {print "\t"$0}' $FN
                        echo -e $cBCYA"\n\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA local-data entries\n"$cRESET 2>&1
                        unbound-control view_list_local_data  $VIEWNAME
                        echo -e $cBCYA"\tunbound view: name: ${cRESET}\"${VIEWNAME}\"$cBCYA local-zones entries\n"$cRESET 2>&1
                        unbound-control view_list_local_zones $VIEWNAME
                        echo
                elif [ -z "$(grep "$VIEWNAME\""  $FN)" ];then
                       echo -e $cBRED"\a\n\t***ERROR unbound view: name: ${cRESET}\"${VIEWNAME}\"$cBRED creation requires the domain name argument!$cRESET e.g. 'views NoYouTube youtube.com'\n"$cRESET 2>&1
                fi
                local STATUS=1
            fi
        else
            sed -i -e:b -e'$!{N;2,1bb' -e\} -e '/\n.*include.*views/!P;D' ${CONFIG_DIR}unbound.conf; sed -i '/^include.*views/d' ${CONFIG_DIR}unbound.conf
            [ -f $FN ] && rm $FN
            echo -e $cBCYA"\n\tunbound 'views:' DISABLED\n"$cRESET 2>&1
        fi

        # Does unbound really need to be restarted? i.e. deleting domains doesn't, so STATUS=1 will already be set.
        if [ $STATUS -eq 0 ];then                                # v3.17 Hotfix
            # If we haven't created the 'view:', we don't need to restart unbound if we have ONLY added domains.
            #    (Add/Delete IPs need a Restart!)
            if [ $CREATED -eq 0 ] && [ $ADD_IP_CNT -eq 0 ] && [ $ADD_DOMAIN_CNT -gt 0 ];then
                # Probably should check unbound.config here????
                echo -e "\n"${cBCYA}$(date "+%H:%M:%S")" Checking 'unbound.conf' for syntax errors....."
                local CHK_Config_Syntax="$(unbound-checkconf ${CONFIG_DIR}unbound.conf 2>/dev/null)"
                if [ -n "$(echo "$CHK_Config_Syntax" | grep -o "no errors in")" ];then         # v2.03
                    echo -en $cBGRE
                else
                    echo -en $cBRED"\a"
                    echo "$CHK_Config_Syntax"
                fi
                local STATUS=1
            fi
        fi

        return $STATUS
}
Diversion_to_unbound_list() {

    echo

    # Analyze/Convert the Diversion file(s) into unblock compatible format          # v1.25
    #
    #       /opt/share/diversion/list/blockinglist
    #       /opt/share/diversion/list/wc_blacklist
    #       /opt/share/diversion/list/blacklist
    #       /opt/share/diversion/list/hostslist
    #       /opt/share/diversion/list/whitelist
    #
    #
    #       Option ==> ad
    #
    #       Analyzed Diversion file: 'blockinglist'    Type=pixelserv, (Ablock Domains=63400) would add 705 entries
    #       Analyzed Diversion file: 'blacklist'       Type=pixelserv, (Ablock Domains=63400) would add 2 entries
    #
    # The unbound blockhost file is the user added urls as well as containing wildcard domains not found in other lists.
    # The unbound permlist  file is the user-added allowed urls file.
    #
    # https://nlnetlabs.nl/projects/unbound/about/
    # https://nlnetlabs.nl/documentation/unbound/
    #
    # Sadly Diversion mangles '/opt/etc/init.d/S80pixelserv-tls' so that if you take down Diversion, Diversion also takes down
    #       pixelserv-tls, and you can't then (re)start pixelsrv stand-alone unless you alter '/opt/etc/init.d/S80pixelserv-tls' :-{
    #
    #   #if [ "$DIVERSION_STATUS" = "enabled" ] && [ "$psState" = "on" ]; then
    #   if  [ -n "$(pidof unbound)" ] || { [ "$DIVERSION_STATUS" = "enabled" ] && [ "$psState" = "on" ]; }; then        # unbound_manager

_quote() {
  echo $1 | sed 's/[]\/()$*.^|[]/\\&/g'
}

    local REQUIRE_PIXELSERV=

    # Fix init.d/S80pixelserv-tls so it can start if either Unbound or Diversion is UP
    if [ -f /opt/etc/init.d/S80pixelserv-tls ];then                         # v1.25
        if [ -z "$(grep "pidof unbound" /opt/etc/init.d/S80pixelserv-tls)" ];then
            OLD_LINE="if \[ \"\$DIVERSION_STATUS\" = \"enabled\" \] \&\& \[ \"\$psState\" = \"on\" \]; then"
            NEW_LINE="if [ -n \"\$(pidof unbound)\" ] || { [ \"\$DIVERSION_STATUS\" = \"enabled\" ] \&\& [ \"\$psState\" = \"on\" ]; };then\t# unbound_manager/"
            sed -i "s/$OLD_LINE/$NEW_LINE" /opt/etc/init.d/S80pixelserv-tls
        fi
    fi

    local ACTION="Analyze"
    #local ACTION="Merge"
    local TYPE=$(echo "$@" | sed -n "s/^.*action=//p" | awk '{print $1}' | tr 'm' 'M')     # Force ACTION action=merge

    local MSG=$cRESET"Analysed Diversion file:$cBMAG" || local MSG=$cRESET"\nMerged Diversion file:$cBGRE"

    if [ "$1" != "all" ] || [ "${1:0:5}" != "type" ];then
        local DIVERSION_FILES=$1                                            # User specific file to be processed
    fi

    local TYPE=$(echo "$@" | sed -n "s/^.*type=//p" | awk '{print $1}')     # Force TYPE type=adblock or type=pixelserv

    if [ -z "$DIVERSION_FILES" ] || [ "$DIVERSION_FILES" == "all" ];then
        local DIVERSION_FILES="blockinglist blacklist whitelist"
    fi

    local ACTION=$(echo "$ACTION" | sed 's/e$//')
    echo -e $cBCYA"\n${ACTION}ing '$DIVERSION_FILES', please be patient.....may take 30 seconds" 2>&1

    local DIV_DIR="/opt/share/diversion/list/"

    local PIXELSERV_IP=$(ps -w | grep pixelserv-tls | grep -v grep | awk '{print $6}')

    for FN in $DIVERSION_FILES
        do
            if [ -z "$(echo "$FN" | grep -i "white" )" ];then
                local DIVERSION="/opt/tmp/diversion-"$FN".raw"
                local UNBOUND="/opt/tmp/unbound-"$FN".add"
                local UNBOUNDADBLOCK="/opt/var/lib/unbound/adblock/adservers"
            else
                local DIVERSION="/opt/tmp/diversion-"$FN".raw"
                local UNBOUND="/opt/tmp/unbound-"$FN".add"
                local UNBOUNDADBLOCK="/opt/var/lib/unbound/adblock/permlist"
                local URL="Y"
            fi

            [ "${FN:0:1}" != "/" ] && FN=${DIV_DIR}$FN

            if [ ! -f $FN ];then
                echo -e $cBRED"\n\aDiversion () file '$FN' NOT Found!"$cRESET 2>&1
                return 1
            fi

            if [ -z "$URL" ];then
                local IP=$(awk 'NR==1 {print $1}' $FN)

                if [ -z "$TYPE" ];then          # If user didn't specify 'type=', use the IP in the record to determine it
                    case "$IP" in
                        "0.0.0.0")
                            local TYPE="adblock"
                            ;;
                        *)
                            local TYPE="pixelserv"
                            ;;
                    esac
                fi

                # awk/cut  - Remove the EOL comments, and drop the first word;       sed - expand into individual lines
                awk -F# '{print $1}' $FN | cut -d' ' -f2- | sed 's/ /\n/g' | grep . | sort > ${DIVERSION}X
                if [ "$TYPE" == "adblock" ];then
                    awk '{print "local-zone: \""$1"\" always_nxdomain"}' ${DIVERSION}X > $DIVERSION

                    if [ -f $UNBOUNDADBLOCK ];then                  # v2.07
                        /opt/bin/diff -uZ --suppress-common-lines $UNBOUNDADBLOCK $DIVERSION  | sed '/^\+/!d s/^\+//' | grep -vF "++"  > $UNBOUND   # v1.25
                    fi
                else
                    # Pixelserv redirect records, but at this stage we only want to see if a site entry already exists,
                    #           rather than a 'redirect' pair
                    local IP=$PIXELSERV_IP

                    awk '{print "local-zone: \""$1"\" always_nxdomain"}' ${DIVERSION}X > $DIVERSION

                    if [ -f $UNBOUNDADBLOCK ];then                  # v2.07
                        /opt/bin/diff -uZ --suppress-common-lines $UNBOUNDADBLOCK $DIVERSION  | sed '/^\+/!d s/^\+//' | grep -vF "++" > $UNBOUND    # v1.25

                        # Now convert the new unbound entries in the 'redirect' pairs assuming dnsmasq isn't being used
                        awk -F'"' '{print $2}' $UNBOUND > ${DIVERSION}X

                        echo -e "#\n# Beware using the following for pixelserv-tls together with dnsmasq. Check DNS-rebind\n#" >> $UNBOUND
                        # @dave14305 found that 'local-zone' for pixelserv-tls uses less memory than the two 'redirect/local-data' pair
                        #awk -v pixelservip=${IP} '{print "local-zone: \""$1"\" redirect\nlocal-data: \""$1"\" A "pixelservip}' ${DIVERSION}X >> $UNBOUND
                        awk -v pixelservip=${IP} '{print "local-data: \""$1" 0 A "pixelservip"\""}' ${DIVERSION}X   >> $UNBOUND
                        cp $UNBOUND ${CONFIG_DIR}adblock/pixelserv
                    fi
                fi
            else
                # Allowlist of URLs
                # awk/cut  - Remove the EOL comments,
                awk -F# '{print $1}' $FN | grep . | sort > $DIVERSION
                # diff -uZ --suppress-common-lines /opt/var/lib/unbound/adblock/permlist  /opt/share/diversion/list/whitelist  | sed '/^\+/ s/^\+//' | sort
                # Only extract lines that start with '+' and delete the '+'
                if [ -f $UNBOUNDADBLOCK ];then
                    /opt/bin/diff -uZ --suppress-common-lines $UNBOUNDADBLOCK $DIVERSION | sed '/^\+/ s/^\+//' | sort > $UNBOUND
                    sed -i '1,/^@@.*/d' $UNBOUND    # Remove the DIFF info lines for the first file $UNBOUNDADBLOCK
                fi
            fi

        done

    # Print a report showing unbound Ad Block domains/URLs with diversion domains/URLs and the results of a possible merge
    for FN in $DIVERSION_FILES
        do
            if [ -z "$(echo "$FN" | grep -i "white" )" ];then
                local UNBOUND="/opt/tmp/unbound-"$FN".add"
                local DIVERSION="/opt/tmp/diversion-"$FN".raw"
                local UNBOUNDADBLOCK="/opt/var/lib/unbound/adblock/adservers"
                DESC="Domains"
            else
                local UNBOUND="/opt/tmp/unbound-"$FN".add"
                local DIVERSION="/opt/tmp/diversion-"$FN".raw"
                local UNBOUNDADBLOCK="/opt/var/lib/unbound/adblock/permlist"
                local URL="Y"
                local TYPE="URL"
                DESC="URLs"
            fi

            [ -f $UNBOUNDADBLOCK ] && local CNT_UNBOUNDADBLOCK=$(wc -l < $UNBOUNDADBLOCK ) || CNT_UNBOUNDADBLOCK=0  # v2.07

            if [ "$TYPE" == "adblock" ] || [ "$TYPE" == "URL" ];then
                [ -f $UNBOUNDADBLOCK ] && local CNT_DIVERSION=$(sort $UNBOUNDADBLOCK $UNBOUND | uniq | wc -l) || local CNT_DIVERSION=$(awk -F# '{print $1}' ${DIV_DIR}$FN | cut -d' ' -f2- | sed 's/ /\n/g' | grep .  | wc -l)      # v2.07
            else
                if [ -f $UNBOUND ];then                     # v2.07
                    cp $UNBOUND ${UNBOUND}X
                    sed -i 's/redirect/always_nxdomain/; '/local-data:/d'' ${UNBOUND}X
                fi

                [ -f $UNBOUNDADBLOCK ] && local CNT_DIVERSION=$(sort $UNBOUNDADBLOCK ${UNBOUND}X | uniq | wc -l) || local CNT_DIVERSION=$(awk -F# '{print $1}' ${DIV_DIR}$FN | cut -d' ' -f2- | sed 's/ /\n/g' | grep . | wc -l)    # v2.07
                rm ${UNBOUND}X  2>/dev/null
            fi

            rm $DIVERSION       2>/dev/null
            rm ${DIVERSION}X    2>/dev/null

            #sed -i "1i# Diversion $FN \($TYPE\)" $UNBOUND
            [ "${ACTION:0:4}" == "Merg" ] && { cat $UNBOUND >> $UNBOUNDADBLOCK; REQUIRE_PIXELSERV="Y"; }

            local CNT_DIFF=$((CNT_DIVERSION-CNT_UNBOUNDADBLOCK))
            if [ $CNT_DIFF -gt 0 ] && [ "$FN" == "blacklist" ];then
               local CNT_DIFF=$((CNT_DIFF/2))       # v3.12 We list both for pixelserv-tls ?
            fi
            local CNT_DIFF=$(printf "%5d" "$CNT_DIFF")

            echo -e $MSG "'"$FN"'\t ${cRESET}Type=$TYPE, (Adblock $DESC=$cBMAG"$CNT_UNBOUNDADBLOCK")${cRESET} would add$cBMAG" $CNT_DIFF $cRESET"entries" 2>&1
        done

    #Ensure merged duplicates are removed
    if [ "${ACTION:0:4}" == "Merg" ];then
        sort -k 2,1 /opt/var/lib/unbound/adblock/adservers | uniq > /opt/var/lib/unbound/adblock/adservers
        sort -k 2,1 /opt/var/lib/unbound/adblock/permlist  | uniq > /opt/var/lib/unbound/adblock/permlist
        echo -e $cBCYA"\n${ACTION}ed '$DIVERSION_FILES'" 2>&1
    fi

    if [ -f /opt/etc/init.d/S80pixelserv-tls ] && [ -n "$REQUIRE_PIXELSERV" ] && [ -z "$(pidof pixelserv-tls)" ];then
        /opt/etc/init.d/S80pixelserv-tls start
    fi
}
Configure_SafesearchDomains() {

    local ARG=$1

    if [ ! -f $CONFIG_ADD ]; then
        echo -e $cBCYA"\nGenerating Safe Search domains....."$cRESET
        [ "$ARG" != "dev" ] && download_file /jffs/addons/unbound unbound_SafeSearch.sh martineau || download_file /jffs/addons/unbound unbound_SafeSearch.sh martineau dev
        chmod +x /jffs/addons/unbound/unbound_SafeSearch.sh
        sh /jffs/addons/unbound/unbound_SafeSearch.sh
    fi
    if [ -z "$(grep "^include.*unbound\.conf\.safesearch" ${CONFIG_DIR}unbound.conf)" ];then
        echo -e $cBGRE"\nEnabling Safe Search....."$cRESET
        Check_config_add_and_postconf
    fi
}

#=============================================Main=============================================================
# shellcheck disable=SC2068
Main() { true; } # Syntax that is Atom Shellchecker compatible!

FIRMWARE=$(echo $(nvram get buildno) | awk 'BEGIN { FS = "." } {printf("%03d%02d",$1,$2)}')     # v2.10
HARDWARE_MODEL=$(Get_Router_Model)

# Global Router URL
HTTP_TYPE="http"                                                          # v2.16 v2.13
HTTP_PORT=$(nvram get http_lanport)                                       # v2.16 v2.13
[ "$(nvram get http_enable)" == "1" ] && { HTTP_TYPE="https"; HTTP_PORT=$(nvram get https_lanport) ; } # v2.16 Hotfix  v2.16 v2.13

ANSIColours

source /usr/sbin/helper.sh                                  # v2.07 Required for external 'am_settings_set()/am_settings_get()'

# Need assistance ?
if [ "$1" == "-h" ] || [ "$1" == "help" ];then
    clear                                                   # v1.21
    echo -e $cBWHT
    ShowHelp
    echo -e $cRESET3.23
    exit 0
fi

# If 'jitterentropy-rngd' installed in RMerlin firmware, then the 'haveged' package is redundant and should be removed  # v3.23
if [ "$(/bin/uname -o)" != "ASUSWRT-Merlin-LTS" ] && [ -n "$(which haveged)" ];then      # v3.23
    if [ -n "$(which jitterentropy-rngd)" ]; then
        if [ -n "$(ps -w | grep -v grep | grep "jitterentropy-rngd")" ];then        # v3.23
            [ -f /opt/etc/init.d/S02haveged ] && /opt/etc/init.d/S02haveged stop
        fi
        opkg remove haveged >/dev/null
    fi
fi

if [ "$1" == "debug" ] || [ "$1" == "debugall" ];then                          # v3.23 v3.10
    if [ "$1" == "debug" ];then
        DEBUGMODE="$(echo -e ${cRESET}$cWRED"Debug mode enabled"$cRESET)"
        shift
    fi
   [ "$1" == "debug" ] && set +x                    # v3.23
fi

[ ! -L "/opt/bin/unbound_manager" ] && Script_alias "create"                # v2.06 Hotfix for amtm v1.08

[ -n "$(echo "$@" | grep -oiw "advanced")" ] && EASYMENU="N" || EASYMENU="Y"                    # v2.07

[ -n "$(echo "$@" | grep -oiw "noreadline")" ] && READLINE="NoReadLine" || READLINE="ReadLine"  # v3.18 Hotfix

if [ -f ${CONFIG_DIR}Read.me ];then
    # Does the firmware support addons?                                         # v2.10
    if [ -n "$(nvram get rc_support | grep -o "am_addons")" ];then  # v2.18 Hotfix v2.15
        CUSTOM_NVRAM="$(am_settings_get unbound_mode)"                          # v2.07 Retrieve value saved across amtm sessions
    fi

    case "$CUSTOM_NVRAM" in                                                     # v2.07
        Advanced)
            EASYMENU="N"
        ;;
        Easy)
            EASYMENU="Y"
        ;;
    esac
fi

if [ -n "$(echo "$@" | grep -F "config=")" ];then                           # v2.17 Hotfix
    NEW_CONFIG=$(echo "$@" | sed -n "s/^.*config=//p" | awk '{print $1}')                       # v1.22
    [ -z "$NEW_CONFIG" ] && NEW_CONFIG="${CONFIG_DIR}unbound.conf"          # v2.17 Hotfix
fi

if [  -n "$NEW_CONFIG" ];then
    [ -z "$(echo "$NEW_CONFIG" | grep -E "\.conf$")" ] && NEW_CONFIG=$NEW_CONFIG".conf"     # v1.22
    [ "${NEW_CONFIG:0:1}" != "/" ] && NEW_CONFIG="/opt/share/unbound/configs/"$NEW_CONFIG    # v2.17 Hotfix v1.22
    if [ -f  $NEW_CONFIG ];then
        if [ -n "$(pidof unbound)" ];then
            TXT=" <<== $NEW_CONFIG"
            if [ -d $CONFIG_DIR ] && [ "$NEW_CONFIG" != "${CONFIG_DIR}unbound.conf" ];then      # v2.17 Hotfix
                cp $NEW_CONFIG ${CONFIG_DIR}unbound.conf
            fi
            TAG="(Date Loaded by unbound_manager "$(date)")"
            [ -f ${CONFIG_DIR}unbound.conf ] && sed -i "1s/(Date Loaded.*/$TAG/" ${CONFIG_DIR}unbound.conf
            if [ "$(Valid_unbound_config_Syntax "${CONFIG_DIR}unbound.conf")" == "Y" ];then # v2.17 Hotfix
                echo -en $cBCYA"\nReloading 'unbound.conf'$TXT status="$cRESET
                SayT "Reloading 'unbound.conf'$TXT"
                Manage_cache_stats "save"                               # v2.17 Hotfix
                $UNBOUNCTRLCMD reload
                Manage_cache_stats "restore"                            # v2.17 Hotfix
                TXT=
                unset $TAG
                unset $TXT
                unset $NEW_CONFIG
            else
                echo -e $cBRED"\a\n***ERROR Invalid Configuration file '$NEW_CONFIG'\n\n"$cRESET
                SayT "***ERROR Invalid Configuration file '$NEW_CONFIG'"
                exit_message 1
            fi
        else
            echo -e $cBRED"\a\n***ERROR unbound not ACTIVE to Load Configuration file '$NEW_CONFIG'\n\n"$cRESET
            SayT "***ERROR unbound not ACTIVE to Load Configuration file '$NEW_CONFIG'"          # v2.17 Hotfix
            exit_message 1
        fi
    else
        echo -e $cBRED"\a\nConfiguration file '$NEW_CONFIG' NOT found?\n\n"$cRESET
        exit_message 1
    fi
fi

case "$1" in
    localhosts)                                                         # v3.16
        Convert_dnsmasq_LocalHosts                                      # v3.16
        Restart_unbound
        echo -e $cRESET
        exit_message
        ;;
    update*)
        ARG=;ARG2=
        if [ -n "$(echo "$@" | grep -F "update=")" ];then               # v3.16 {'update'}[='uf'[ 'dev']
           ARGS=$(echo "$@" | sed -n "s/^.*update=//p")
           ARG=$(echo "$ARGS" | awk '{print $1}')
           ARG2=$(echo "$ARGS" | awk '{print $NF}')
        fi
        update_installer "$ARG" "$ARG2"                                  # v3.16
        echo -e $cRESET
        exit_message
        ;;
    recovery)              # v1.22
        NEW_CONFIG="/opt/share/unbound/configs/reset.conf"
        if [ -f  $NEW_CONFIG ];then
            TXT=" <<== $NEW_CONFIG"
            [ -d $CONFIG_DIR ] && cp $NEW_CONFIG ${CONFIG_DIR}unbound.conf
        else
            echo -e $cBCYA"Recovery: Retrieving Custom unbound configuration"$cBGRA
            download_file $CONFIG_DIR unbound.conf martineau           # v2.17 HotFix v2.02
        fi
        Edit_config_options "verbosity"       "uncomment"                   # v3.09
        sed -i "/^verbosity:/ s/[^ ]*[^ ]/0/2" ${CONFIG_DIR}unbound.conf   # v3.09
        TAG="(Date Loaded by unbound_manager "$(date)")"
        [ -f ${CONFIG_DIR}unbound.conf ] && sed -i "1s/(Date Loaded.*/$TAG/" ${CONFIG_DIR}unbound.conf
        if [ -f /opt/share/unbound/configs/unbound.conf.add ];then
            echo -e $cBRED"\a"
            mv /opt/share/unbound/configs/unbound.conf.add /opt/share/unbound/configs/unbound.conf.addRECOVERY
            Say "Recovery: 'unbound.conf.add' renamed to 'unbound.conf.addRECOVERY'"
        fi
        if [ -f /opt/share/unbound/configs/unbound.conf.addgui ];then
            echo -e $cBRED"\a"
            mv /opt/share/unbound/configs/unbound.conf.addgui /opt/share/unbound/configs/unbound.conf.addguiRECOVERY
            Say "Recovery: 'unbound.conf.addgui' renamed to 'unbound.conf.addguiRECOVERY'"
        fi
        echo -e $cRESET
        if [ -n "$(pidof unbound)" ];then
           echo -en $cBCYA"\nRecovery: Reloading 'unbound.conf'$TXT status="$cRESET
           Manage_cache_stats "save"                               # v2.17 Hotfix
           $UNBOUNCTRLCMD reload
           Manage_cache_stats "restore"                            # v2.17 HotFix
        else
           service restart_dnsmasq                                                    # v3.09
        fi
        exit_message
        ;;
    restart)                        # v2.14
        # Allow saving of cache - i.e. when called by '/adblock/gen_adblock.sh'
        NOMSG="NOMSG"               # v2.15 if unbound isn't running then suppress errors/messages i.e. 'unbound-control dump_cache'
        Restart_unbound "nochk"     # v2.15 skip the unbound restart status check
        exit_message
        ;;
    x|stop)                                                     # v3.23
        [ "$(Unbound_Installed)" == "N" ] && { echo -e $cBRED"\a\n\tunbound NOT installed! - option unavailable"$cRESET; exit_message; }    # v3.23

        echo
        Manage_cache_stats "save"                               # v3.23
        /opt/etc/init.d/S61unbound stop                         # v3.23
        echo -en $cBCYA"\nRestarting dnsmasq....."$cBGRE        # v3.23
        service restart_dnsmasq                                 # v3.23
        echo -en $cBCYA"\nunbound STOPPED."$cBGRE               # v3.23
        SayT "unbound STOPPED"                                  # v3.23
        ;;
    reload)                         # v2.17 Hotfix
        exit_message
        ;;
    status)                         # v2.18 Hotfix
        Show_status "syslog"
        exit_message
        ;;
    vpn*|bind|nobind)              # v3.08 v3.00

        case "$1" in
            vpn*)                   # v3.08
                VPN_ID=$(echo "$@" | sed -n "s/^.*vpn=//p" | awk '{print $1}')
                case $VPN_ID in
                1|2|3|4|5)
                        # Allow the asyncronous call from openvpn-event vpnclientX-up to ensure that the VPN Client has fully initialised
                        DELAY="$(echo "$@" | sed -n "s/^.*delay=//p")" # v3.05
                        if [ -n "$DELAY" ];then                        # v3.05
                            [ -n "$(echo $DELAY | grep -E "(^[1-9]$)|^[1-9][0-9]$")" ] && sleep $DELAY || { echo -e $cBRED"\a\n";Say "***ERROR Invalid arg 'delay=$DELAY' - must in range 1-99" ;exit_message 1;} # v3.06 Fix @ugandy v3.05
                        fi

                        if [ "$(nvram get vpn_client${VPN_ID}_state)" == "2"  ];then
                            Use_VPN_Tunnel "$VPN_ID"
                            [ $? -eq 0 ] && Restart_unbound
                        else
                            echo -e $cBRED"\n\a"
                            Say "***ERROR VPN Client '$VPN_ID' is NOT Connected?"
                        fi
                ;;
                disable)
                        # Remember, 'post-mount' initialises Entware then you must include the following:
                        #   [ -n "$(which unbound_manager)" ] && sh /jffs/addons/unbound/unbound_manager.sh vpn=disable
                        #
                        Use_VPN_Tunnel "disable"
                        [ $? -eq 0 ] && Restart_unbound
                ;;
                *)
                    echo -e $cBRED"\n\a"
                    Say "***ERROR Invalid argument '$VPN_ID' must be numeric '1-5' or 'disable'"
                esac
                echo -e $cRESET
                exit_message
                ;;
            *)                          # v3.08
                case "$1" in
                    bind)
                        # Called from event script 'wan0-connected'
                        BIND_WAN "wan"
                        [ $? -eq 0 ] && Restart_unbound
                        ;;
                    nobind)
                        # Remember, 'post-mount' initialises Entware then you must include the following:
                        #   [ -n "$(which unbound_manager)" ] && sh /jffs/addons/unbound/unbound_manager.sh nobind
                        #
                        BIND_WAN "any"
                        [ $? -eq 0 ] && Restart_unbound
                        ;;
                esac
                echo -e $cRESET
                exit_message
                ;;
        esac
esac

clear

Check_Lock "$1"                     # v2.15 moved to allow 'gen_adblock.sh' to invoke 'unbound_manager restart'

welcome_message "$@"

echo -e $cRESET

rm -rf /tmp/unbound.lock

exit 0
