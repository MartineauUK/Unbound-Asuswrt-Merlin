#!/bin/sh
#============================================================================================ © 2019-2020 Martineau v1.28
#  Install the unbound DNS over TLS resolver package from Entware on Asuswrt-Merlin firmware.
#
# Usage:    unbound_manager    ['help'|'-h'] | [ ['nochk'] ['easy'] ['install'] ['recovery'] ['config='config_file]
#
#           unbound_manager    easy
#                              Menu: Allow quick install options (3. Advanced Tools will be shown a separate page)
#                                    |   1 = Install unbound DNS Server                                     |
#                                    |                                                                      |
#                                    |   2 = Install unbound DNS Server - Advanced Mode                     |
#                                    |       o1. Enable unbound Logging                                     |
#                                    |       o2. Integrate with Stubby                                      |
#                                    |       o3. Install Ad and Tracker Blocking                            |
#                                    |       o4. Customise CPU/Memory usage (Advanced Users)                |
#                                    |       o5. Disable Firefox DNS-over-HTTPS (DoH) (USA users)           |
#                                    |                                                                      |
#                                    |   3 = Advanced Tools  (e.g '? About' and 'z Remove unbound' etc.)    |
#
#                              This may be toggled at any time using menu option [ 'advanced' | 'easy' ]
#
#           unbound_manager    advanced
#                              Menu: Allow custom selection of Optional features and Advanced Tools will be displayed as appropriate
#                                    |                                                                      |
#                                    |   i = Install unbound DNS Server - Advanced Mode                     |
#                                    |       o1. Enable unbound Logging                                     |
#                                    |       o2. Integrate with Stubby                                      |
#                                    |       o3. Install Ad and Tracker Blocking                            |
#                                    |       o4. Customise CPU/Memory usage (Advanced Users)                |
#                                    |       o5. Disable Firefox DNS-over-HTTPS (DoH) (USA users)           |
#                                    |                                                                      |
#                                    |   z  = Remove Existing unbound Installation                          |
#                                    |   ?  = About Configuration                                           |
#
#           unbound_manager    recovery
#                              Will attempt to reload a default 'unbound.config' to fix a corrupt config
#           unbound_manager    config=mytest
#                              Will attempt to load '/opt/share/unbound/configs/mytest.config'
#           unbound_manager    nochk
#                              The script on start-up attempts to check GitHub for any version update/md5 mismatch, but a
#                              failed install will look as if the script has stalled until cURL time-out expires (3 mins).
#                              Use of nochk disables the 'stall' to quickly allow access to the 'z  = Remove Existing unbound Installation' option
#
#
#  See https://github.com/MartineauUK/Unbound-Asuswrt-Merlin for additional help/documentation with this script.


# Maintainer: Martineau
# Last Updated Date: 27-Jan-2020
#
# Description:
#
# Acknowledgement:
#  Test team: rngldo
#  Contributors: rgnldo,dave14305,SomeWhereOverTheRainbow (Xentrk for this script template and thelonelycoder for amtm)
#  See https://github.com/rgnldo/Unbound-Asuswrt-Merlin for a description of unbound config/usage changes.
#
#   https://calomel.org/unbound_dns.html
#   https://wiki.archlinux.org/index.php/unbound
#   https://www.tumfatig.net/20190417/storing-unbound8-logs-into-influxdb/
#
####################################################################################################

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:$PATH             # v1.15 Fix by SNB Forum Member @Cam
logger -t "($(basename "$0"))" "$$ Starting Script Execution ($(if [ -n "$1" ]; then echo "$1"; else echo "menu"; fi))"
VERSION="1.28"
GIT_REPO="unbound-Asuswrt-Merlin"
GITHUB_RGNLDO="https://raw.githubusercontent.com/rgnldo/$GIT_REPO/master"
GITHUB_MARTINEAU="https://raw.githubusercontent.com/MartineauUK/$GIT_REPO/master"
GITHUB_DIR=$GITHUB_MARTINEAU                                # v1.08 default for script
CONFIG_DIR="/opt/var/lib/unbound/"
UNBOUNCTRLCMD="unbound-control -c ${CONFIG_DIR}unbound.conf"    # using the '-c' parameter is recommended v1.27
ENTWARE_UNBOUND="unbound-control-setup unbound-control unbound-anchor unbound-daemon"
SILENT="s"                                                  # Default is no progress messages for file downloads # v1.08
ALLOWUPGRADE="Y"                                            # Default is allow script download from Github      # v1.09
CHECK_GITHUB=1                                              # Only check Github MD5 every nn times
MAX_OPTIONS=5                                               # Available Installation Options 1 thru 5 see $AUTO_REPLYx
USER_OPTION_PROMPTS="?"                                     # Global reset if ANY Auto-Options specified
CURRENT_AUTO_OPTIONS=                                       # List of CURRENT Auto Reply Options
DIV_DIR="/opt/share/diversion/list/"                        # diversion directory v1.25
KEEPACTIVECONFIG="N"                                        # During install/update retrieve basic 'unbound.conf' from rgnldo GitHub


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
ANSIColours() {

    cRESET="\e[0m";cBLA="\e[30m";cRED="\e[31m";cGRE="\e[32m";cYEL="\e[33m";cBLU="\e[34m";cMAG="\e[35m";cCYA="\e[36m";cGRA="\e[37m"
    cBGRA="\e[90m";cBRED="\e[91m";cBGRE="\e[92m";cBYEL="\e[93m";cBBLU="\e[94m";cBMAG="\e[95m";cBCYA="\e[96m";cBWHT="\e[97m"
    aBOLD="\e[1m";aDIM="\e[2m";aUNDER="\e[4m";aBLINK="\e[5m";aREVERSE="\e[7m"
    cRED_="\e[41m";cGRE_="\e[42m"

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
            if [ -f "/opt/bin/opkg" ]; then
                if [ -n "$ENTWARE_UTILITY" ]; then            # Specific Entware utility installed?
                    if [ -n "$(opkg list-installed "$ENTWARE_UTILITY")" ]; then
                        READY="0"                                 # Specific Entware utility found
                    else
                        # Not all Entware utilities exists as a stand-alone package e.g. 'find' is in package 'findutils'
                        if [ -d /opt ] && [ -n "$(find /opt/ -name "$ENTWARE_UTILITY")" ]; then
                            READY="0"                               # Specific Entware utility found
                        fi
                    fi
                else
                    READY="0"                                     # Entware utilities ready
                fi
                break
            fi
            sleep 1
            logger -st "($(basename "$0"))" "$$ Entware $ENTWARE_UTILITY not available - wait time $((MAX_TRIES - TRIES-1)) secs left"
            TRIES=$((TRIES + 1))
        done
        return "$READY"
}
Convert_SECS_to_HHMMSS () {

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
Uncomment_config_options() {                                                # v1.27
_quote() {
  echo $1 | sed 's/[]\/()$*.^|[]/\\&/g'
}
    local FN="${CONFIG_DIR}unbound.conf"
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

    [ -z "$MATCH" ] && { echo -e $cBRED"\a\n***ERROR - Missing option name" 2>&1; exit 1; }

    case $ACTION in
        comment)
                if [ -z "$TO" ];then
                    #[ -z "$(grep "#$MATCH" $FN )" ] && sed $SEDACTION "/$MATCH/ s/\($MATCH.*$\)/#\1/" $FN|| echo -e $cRESET"\tAleady commented out '#$MATCH'"
                    [ -z "$(grep "#[[:space:]]*$MATCH" $FN )" ] && sed $SEDACTION "/$MATCH/ s/\($MATCH.*$\)/#\1/" $FN|| echo -e $cRESET"\tAleady commented out '#$MATCH'"
                else
                    sed $SEDACTION "/$MATCH/,/$TO/ s/\(^[[:space:]]*\)\(.\)/\1#\2/" $FN
                fi
                ;;
        uncomment)
                if [ -z "$TO" ];then
                    #sed $SEDACTION "/#$MATCH/ s/#//1" $FN
                    sed $SEDACTION "/#[[:space:]]*$MATCH/ s/#//1" $FN

                else
                    #sed $SEDACTION "/#$MATCH/,/#$TO/ s/\(^[[:space:]]*\)\(#\)/\1/" $FN
                    sed $SEDACTION "/#[[:space:]]*$MATCH/,/#[[:space:]]*$TO/ s/\(^[[:space:]]*\)\(#\)/\1/" $FN
                fi
                ;;
    esac

}
Show_Advanced_Menu() {
    printf "%s\t\t\t\t%s\n"         "$MENU_Z" "$MENU_L"
    printf "%s\t\t\t\t\t\t%s\n"     "$MENU__" "$MENU_VX"
    printf "%s\t\t\t\t\t\t\t%s\n"   "$MENUW_X" "$MENU_VB"
    printf "\t\t\t\t\t\t\t\t\t%s\n" "$MENU_RL"
    printf "\t\t\t\t\t\t\t\t\t%s\n" "$MENU_OQ"
    printf "%s\t\t\t\t\t%s\n"       "$MENU_SD" "$MENU_S"
    [ -n "$MENU_AD" ] && printf "\n\t\t\t\t\t\t\t\t\t%s\n"  "$MENU_AD"       #v1.25
    [ -n "$MENU_CA" ] && printf "\t\t\t\t\t\t\t\t\t%s\n"    "$MENU_CA"         #v1.26

    printf "\n%s\\n\n"              "$MENUW_DNSSEC"             # v1.28
    printf "%s\\n\n"                "$MENUW_DNSINFO"            # v1.28
    printf "\n%s\\n\n"              "$MENUW_LINKS"              # v1.28
    printf '\n%be %b = Exit Script\n' "${cBYEL}" "${cRESET}"
    printf '\n%b[Enter] %bLeave %bAdvanced Tools Menu\n' "${cBGRE}" "$cBCYA" "${cRESET}" # v1.21
}
welcome_message() {

        while true; do

            # No need to display the Header box every time....
            if [ -z "$HDR" ];then                               # v1.09

                printf '\n+======================================================================+\n'
                printf '|  Welcome to the %bunbound Manager/Installation script (Asuswrt-Merlin)%b |\n' "$cBGRE" "$cRESET"
                printf '|  Version %s by Martineau                                           |\n' "$VERSION"
                printf '|                                                                      |\n'
                printf '| Requirements: USB drive with Entware installed                       |\n'
                printf '|                                                                      |\n'
                if [ -z "$EASYMENU" ];then
                    printf '|   i = Install unbound DNS Server - Advanced Mode                     |\n'
                else
                    printf '|   1 = Install unbound DNS Server                                     |\n'
                    printf '|                                                                      |\n'
                    printf '|   2 = Install unbound DNS Server - Advanced Mode                     |\n'
                fi
                    printf '|       o1. Enable unbound Logging                                     |\n'
                    printf '|       o2. Integrate with Stubby                                      |\n'
                    printf '|       o3. Install Ad and Tracker Blocking                            |\n'
                    printf '|       o4. Customise CPU/Memory usage (%bAdvanced Users%b)                |\n' "$cBRED" "$cRESET"
                    printf '|       o5. Disable Firefox DNS-over-HTTPS (DoH) (USA users)           |\n'
                    printf '|                                                                      |\n'
                if [ -z "$EASYMENU" ];then
                    printf '|   z  = Remove Existing unbound Installation                          |\n'
                    printf '|   ?  = About Configuration                                           |\n'
                else
                    printf '|   3 = Advanced Tools                                                 |\n'
                fi
                printf '|                                                                      |\n'
                printf '| You can also use this script to uninstall unbound to back out the    |\n'
                printf '| changes made during the installation. See the project repository at  |\n'
                printf '|         %bhttps://github.com/rgnldo/unbound-Asuswrt-Merlin%b             |\n' "$cBGRE" "$cRESET"
                printf '|     for helpful user tips on unbound usage/configuration.            |\n'
                printf '+======================================================================+\n'

                HDR="N"                                     # v1.09
            else
                [ -z "$SUPPRESSMENU" ] && echo -e $cGRE_"\n"$cRESET 2>&1
            fi
            if [ "$1" = "uninstall" ]; then
                menu1="z"                                   # v1.21
            else

                # Show unbound uptime
                UNBOUNDPID=$(pidof unbound)
                if [ -n "$UNBOUNDPID" ];then
                    # Each call to unbound-control takes 2secs!!!
                    I=1
                    for LINE in $($UNBOUNCTRLCMD status)           # v1.26 so iterate word by word through the single call
                        do
                            case $I in
                                2)
                                    UNBOUNDVERS=$LINE
                                    ;;
                                14)
                                    UNBOUNDUPTIME=$LINE
                                    ;;
                            esac

                            I=$((I + 1))
                        done

                    UNBOUND_STATUS="unbound (pid $UNBOUNDPID) is running...  uptime: "$(Convert_SECS_to_HHMMSS "$UNBOUNDUPTIME" "days")" version: "$UNBOUNDVERS
                    # Display 'unbound.conf' header if present
                    UNBOUND_CONF_VER=$(head -n 1 ${CONFIG_DIR}unbound.conf) # v1.19
                    [ -z "$(echo "$UNBOUND_CONF_VER" | grep -iE "^#.*Version" )" ] && UNBOUND_CONF_VER_TXT= || UNBOUND_CONF_VER_TXT="("$UNBOUND_CONF_VER")"
                    echo -e $cBMAG"\n"$UNBOUND_STATUS $UNBOUND_CONF_VER_TXT"\n"$cRESET  # v1.19
                else
                    echo
                fi

                if [ $CHECK_GITHUB -eq 1 ];then             # v1.20

                    GITHUB_DIR=$GITHUB_MARTINEAU

                    localmd5="$(md5sum "$0" | awk '{print $1}')"

                    [ "$1" != "nochk" ] && remotemd5="$(curl -fsL --retry 3 --connect-timeout 5 "${GITHUB_DIR}/unbound_manager.sh" | md5sum | awk '{print $1}')"  # v1.11

                    [ "$1" != "nochk" ] && REMOTE_VERSION_NUMDOT="$(curl -fsLN --retry 3 --connect-timeout 5 "${GITHUB_DIR}/unbound_manager.sh" | grep -E "^VERSION" | tr -d '"' | sed 's/VERSION\=//')"  || REMOTE_VERSION_NUMDOT="?.??" # v1.11 v1.05

                    [ -z "$REMOTE_VERSION_NUMDOT" ] && REMOTE_VERSION_NUMDOT="?.?? $cRED - Unable to verify Github version"         # v1.15

                    LOCAL_VERSION_NUM=$(echo $VERSION | sed 's/[^0-9]*//g')             # v1.04
                    REMOTE_VERSION_NUM=$(echo $REMOTE_VERSION_NUMDOT | sed 's/[^0-9]*//g')  # v1.04

                    # As the developer, I need to differentiate between the GitHub md5sum hasn't changed, which means I've tweaked it locally
                    if [ -n "$REMOTE_VERSION_NUMDOT" ];then
                        [ ! -f /jffs/scripts/unbound_manager.md5 ] && echo $REMOTE_VERSION_NUM $remotemd5 > /jffs/scripts/unbound_manager.md5   # v1.09
                    fi

                    [ -z "$REMOTE_VERSION_NUM" ] && REMOTE_VERSION_NUM=0            # v1.11

                    # MD5 Mismatch due to local development?
                    if { [ "$(awk '{print $1}' /jffs/scripts/unbound_manager.md5)" == "$remotemd5" ]; } && [ "$localmd5" != "$remotemd5" ];then # v1.28
                        if [ $REMOTE_VERSION_NUM -lt $LOCAL_VERSION_NUM ];then      # v1.09
                            ALLOWUPGRADE="N"                                                # v1.09
                            UPDATE_SCRIPT_ALERT="$(printf '%bu  = Push to Github PENDING for %b(Major) %b%s%b %b update >>>> %b\n\n' "${cBRED}" "${cBGRE}" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION" "v$REMOTE_VERSION_NUMDOT")" # v1.21
                        else
                            ALLOWUPGRADE="N"
                            UPDATE_SCRIPT_ALERT="$(printf '%bu  = %bPush to Github PENDING for %b(Minor Hotfix) %b%s update >>>> %b%s\n\n' "${cBRED}" "$cBRED" "$cBGRE" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION")" # v11.21
                        fi
                    else
                        if [ "$localmd5" != "$remotemd5" ]; then
                            if [ $REMOTE_VERSION_NUM -ge $LOCAL_VERSION_NUM ];then      # v1.27
                                if [ $REMOTE_VERSION_NUM -gt $LOCAL_VERSION_NUM ];then  # v1.27
                                    UPDATE_SCRIPT_ALERT="$(printf '%bu%b  = %bUpdate (Major) %b%s %b%s -> %b\n\n' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION" "v$REMOTE_VERSION_NUMDOT")"   # v1.21
                                else
                                    UPDATE_SCRIPT_ALERT="$(printf '%bu%b  = %bUpdate (Minor Hotfix) %b%s %b%s -> %b\n\n' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION" "v$REMOTE_VERSION_NUMDOT")"
                                fi
                            fi
                        fi
                    fi
                fi

                [ -n "$UPDATE_SCRIPT_ALERT" ] && echo -e $UPDATE_SCRIPT_ALERT"\n"    # v1.25 Fix by SNB Forum Member @Cam
                CHECK_GITHUB=0                                                  # v1.27 Only check Github on first run of script or 'rl' a config

                if [ -z "$SUPPRESSMENU" ];then                                  # v1.11

                    if [ -f ${CONFIG_DIR}unbound.conf ]; then                   # v1.06

                        if [ -z "$EASYMENU" ] ;then
                            MENU_I="$(printf '%bi %b = Update unbound Installation %b%s%b\n' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET")"
                        else                                                    # v1.21
                            [ -z "$ADVANCED_TOOLS" ] && MENU_I="$(printf '%b1 %b = Update unbound Installation  %b%s%b\n%b2 %b = Update unbound Advanced Installation %b%s%b\n%b3 %b = Advanced Tools\n\n ' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET" "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET"  "${cBYEL}" "${cRESET}" )"
                        fi

                        MENU_RS="$(printf '%brs%b = %bRestart%b (or %bStart%b) unbound\n' "${cBYEL}" "${cRESET}" "$cBGRE" "${cRESET}" "$cBGRE" "${cRESET}")"
                        MENU_VX="$(printf '%bv %b = View %b%s %bunbound Configuration (vx=Edit; vh=View Example Configuration) \n' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')"  "$cRESET")"
                    else
                        if [ -z "$EASYMENU" ] ;then
                            MENU_I="$(printf '%bi %b = Begin unbound Installation Process %b%s%b\n' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET")"
                        else
                            [ -z "$ADVANCED_TOOLS" ] && MENU_I="$(printf '%b1 %b = Begin unbound Installation Process %b%s%b\n%b2 %b = Begin unbound Advanced Installation Process %b%s%b\n%b3 %b = Advanced Tools\n\n ' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET" "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET"  "${cBYEL}" "${cRESET}" )"
                        fi
                    fi

                    MENU_VB="$(printf '%bvb%b = Backup current %b(%s)%b Configuration\n' "${cBYEL}" "${cRESET}" "$cBGRE" "${CONFIG_DIR}unbound.conf" "${cRESET}")"  #v1.28
                    MENU_Z="$(printf '%bz %b = Remove Existing unbound Installation\n' "${cBYEL}" "${cRESET}")"
                    MENU_3="$(printf '%b3 %b = Advanced Tools\n' "${cBYEL}" "${cRESET}")"
                    MENU__="$(printf '%b? %b = About Configuration\n' "${cBYEL}" "${cRESET}")"  # v1.17
                    MENUW_X="$(printf '%bx %b = Stop unbound\n' "${cBYEL}" "${cRESET}")"  # v1.28
                    MENUW_SCRIBE="$(printf '%bscribe%b = Enable scribe (syslog-ng) unbound logging\n' "${cBYEL}" "${cRESET}")"  # v1.28
                    MENUW_DNSSEC="$(printf '%bdnssec%b = {url} Show DNSSEC Validation Chain e.g. dnssec www.snbforums.com\n' "${cBYEL}" "${cRESET}")"  # v1.28
                    MENUW_DNSINFO="$(printf '%bdnsinfo%b = {dns} Show DNS Server e.g. dnsinfo \n' "${cBYEL}" "${cRESET}")"  # v1.28
                    MENUW_LINKS="$(printf '%blinks%b = Show list of external links URLs\n' "${cBYEL}" "${cRESET}")"  # v1.28

                    if [ -n "$(which unbound-control)" ];then
                        if [ -n "$(pidof unbound)" ];then
                            if [ "$($UNBOUNCTRLCMD get_option log-replies)" == "yes" ] || [ "$($UNBOUNCTRLCMD get_option log-queries)" == "yes" ] ;then   # v1.16
                                LOGSTATUS=$cBGRE"LIVE "$cRESET
                                LOGGING_OPTION="(lx=Disable Logging)"
                            else
                                LOGSTATUS=
                                LOGGING_OPTION="(lo=Enable Logging)"
                            fi
                        fi
                        MENU_L="$(printf "%bl %b = Show unbound %blog entries $LOGGING_OPTION\n" "${cBYEL}" "${cRESET}" "$LOGSTATUS")"
                        MENU_CA="$(printf "%bca%b = Cache Size Optimisation  ([ 'reset' ])\n" "${cBYEL}" "${cRESET}")"
                    fi

                    if [ -n "$(pidof unbound)" ];then
                        [ -n "$(which unbound-control)" ] && MENU_OQ="$(printf "%boq%b = Query unbound Configuration option e.g 'oq verbosity' (ox=Set) e.g. 'ox log-queries yes'\n" "${cBYEL}" "${cRESET}")"
                        MENU_RL="$(printf "%brl%b = Reload Configuration (Doesn't halt unbound) e.g. 'rl test1[.conf]' (Recovery use 'rl reset/user')\n" "${cBYEL}" "${cRESET}")"
                        if [ "$($UNBOUNCTRLCMD get_option extended-statistics)" == "yes" ];then    # v1.18
                            EXTENDEDSTATS=$cBGRE" Extended"$cRESET
                            EXTENDEDSTATS_OPTION="s-=Disable Extended Stats"
                        else
                            EXTENDEDSTATS=
                            EXTENDEDSTATS_OPTION="s+=Enable Extended Stats"
                        fi
                        MENU_S="$(printf '%bs %b = Show unbound%b statistics (s=Summary Totals; sa=All; %s)\n' "${cBYEL}" "${cRESET}" "$EXTENDEDSTATS" "$EXTENDEDSTATS_OPTION")"
                    fi
                    MENU_SD="$(printf "%bsd%b = Show dnsmasq Statistics/Cache Size\n" "${cBYEL}" "${cRESET}")"

                    if [ -n "$(which diversion)" ] ;then
                        MENU_AD="$(printf '%bad%b = Analyse Diversion White/Black lists ([ file_name ['type=adblock'] ])\n' "${cBYEL}" "${cRESET}")"
                    fi

                    # v1.08 Use 'context aware' horizontal menu!!!! Radical eh?
                    if [ -z "$EASYMENU" ];then
                        if [ -z "$ADVANCED_TOOLS" ];then                           # v1.21
                            printf "%s\t\t%s\n"             "$MENU_I" "$MENU_L"
                        fi

                        if [ -n "$ADVANCED_TOOLS" ];then                           # v1.26
                            Show_Advanced_Menu
                        else                                                       # v1.26
                            printf "%s\t\t\t\t%s\n"        "$MENU_Z" "$MENU_VX"    # v1.11
                            printf "%s\t\t\t\t\t\t\t%s\n"  "$MENU_3" "$MENU_RL"    # v1.17
                            printf "%s\t\t\t\t\t\t%s\n"    "$MENU__" "$MENU_OQ"
                            echo
                            printf "%s\t\t\t\t\t\t%s\n"    "$MENU_RS" "$MENU_S"
                            printf '\n%be %b = Exit Script\n' "${cBYEL}" "${cRESET}"
                        fi
                    else
                        if [ -n "$ADVANCED_TOOLS" ];then                           # v1.21
                            Show_Advanced_Menu
                        else
                            printf "%s\t%s\n"               "$MENU_I"
                            printf '%be %b = Exit Script\n' "${cBYEL}" "${cRESET}"
                        fi
                    fi
                fi

                # Show 'aasy'/'adv[anced]' mode?
                [ -z "$EASYMENU" ] && TXT="A:" || TXT="E:"
                printf '\n%b%s%bOption ==>%b ' "$cBCYA" "$TXT" "${cBYEL}" "${cRESET}"
                read -r "menu1"
            fi
            local TXT=
            unset $TXT
            case "$menu1" in
                0)
                    HDR=                                            # v1.09
                ;;
                1|2|2*|i|iu|i*|"i?")

                KEEPACTIVECONFIG="N"                                # v1.27
                if [ -n "$(echo "$menu1" | grep -o "keepconfig")" ];then    # v1.27
                    KEEPACTIVECONFIG="Y"                            # v1.27 Explicitly keep current 'unbound.conf'
                    menu1="$(echo "$menu1" | sed 's/keepconfig//g')"
                fi

                    [ "$menu1" == "i?" ] && USER_OPTION_PROMPTS="?" # v1.20 Force Selectable User option prompts
                    [ "$menu1" == "1" ] && menu1="1 none"           # v1.21 EASYMENU unbound ONLY install (NO options)
                    [ "$menu1" == "2?" ] && USER_OPTION_PROMPTS="?" # v1.21 Force Selectable User option prompts
                    [ "$menu1" == "2" ] && menu1="2 all"            # v1.21 EASYMENU Force Auto Reply to Selectable User option prompts

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
                            KEEPACTIVECONFIG="Y"                    # v1,27 Explicitly keep current 'unbound.conf'
                            ;;
                    esac

                    local PREINSTALLCONFIG=
                    if [ -f ${CONFIG_DIR}unbound.conf ];then
                        local PREINSTALLCONFIG="$(Backup_unbound_config)"               # v1.27 Preserve any custom config.conf
                    fi

                    install_unbound $menu1

                    if [ "$KEEPACTIVECONFIG" != "Y" ];then                              # v1.27
                        if [ -n "$PREINSTALLCONFIG" ] && [ -f "/opt/share/unbound/configs/"$PREINSTALLCONFIG ] ;then
                            echo -e "\a\nDo you want to restore the pre-update 'unbound.conf'? ('${cBMAG}$PREINSTALLCONFIG'$cRESET)\n\n\tReply$cBRED 'y'$cBGRE or press [Enter] $cRESET to skip\n"
                            read -r "ANS"
                            if [ "$ANS" == "y"  ];then                      # v1.27
                                cp "/opt/share/unbound/configs/$PREINSTALLCONFIG" ${CONFIG_DIR}unbound.conf
                                local TAG="Date Loaded by unbound_manager "$(date)")"
                                sed -i "1s/Date.*Loaded.*$/$TAG/" ${CONFIG_DIR}unbound.conf
                                echo -en $cBCYA"\nReloading 'unbound.conf'$TXT status="$cRESET
                                $UNBOUNCTRLCMD reload

                            fi
                        fi
                    fi
                    local TXT=
                    unset $TXT
                    #break
                ;;
                3)
                    ADVANCED_TOOLS="Y"                              # v1.21
                    menu1=""
                    ;;
                z)
                    validate_removal
                    break
                ;;
                v|vx|vh|vb)
                    case $menu1 in
                        v|vh) ACCESS="--view"                           # v1.11 View/Readonly
                        ;;
                        vx) ACCESS="--unix"                             # Edit in Unix format
                        ;;
                        vb) echo -e "\n"$(Backup_unbound_config "msg")  # v1.27
                            continue
                        ;;
                    esac
                    [ "$menu1" != "vh" ] && nano $ACCESS ${CONFIG_DIR}unbound.conf || nano $ACCESS /opt/etc/unbound/unbound.conf.Example    # v1.17
                    #break
                ;;
                rl|rl*)
                    # 'reset' and 'user' are Recovery aliases
                    #       i.e. 'reset' is rgnldo's config, and 'user' is the customised install version
                    if [ "$(echo "$menu1" | wc -w)" -eq 2 ];then

                        NEW_CONFIG=$(echo "$menu1" | awk '{print $2}')
                        if [ "$NEW_CONFIG" != "?" ];then                            # v1.22
                            local PERFORMRELOAD="Y"
                            [ -z "$(echo "$NEW_CONFIG" | grep -E "\.conf$")" ] && NEW_CONFIG=$NEW_CONFIG".conf"
                            [ "${NEWCONFIG:0:1}" != "/" ] && NEW_CONFIG="/opt/share/unbound/configs/"$NEW_CONFIG    # v1.19
                            local TXT=
                            if [ -f $NEW_CONFIG ];then
                                cp $NEW_CONFIG ${CONFIG_DIR}unbound.conf
                                #local TXT=" <<== $NEW_CONFIG"
                            else
                                echo -e $cBRED"\a\nConfiguration file '$NEW_CONFIG' NOT found?\n"$cRESET
                                local PERFORMRELOAD="N"
                            fi
                        else
                            # List available .conf files
                            echo -e $cBMAG
                            ls -lAhC /opt/share/unbound/configs/                    # v1.22
                            echo -en $cRESET
                        fi

                    fi

                    if [ "$PERFORMRELOAD" == "Y" ];then                             # v1.19
                        local TAG="Date Loaded by unbound_manager "$(date)")"
                        sed -i "1s/Date.*Loaded.*$/$TAG/" ${CONFIG_DIR}unbound.conf
                        echo -en $cBCYA"\nReloading 'unbound.conf'$TXT status="$cRESET
                        $UNBOUNCTRLCMD reload                                      # v1.08
                        CHECK_GITHUB=1                                          # v1.27 force a GitHub version check to see if we are OK
                    fi
                    local TXT=
                    unset $TXT
                    #break
                ;;
                l|ln*|lo|lx)                                                    # v1.16

                    case $menu1 in

                        lo)                                                     # v1.16
                            $UNBOUNCTRLCMD -q verbosity 2
                            $UNBOUNCTRLCMD -q set_option log-queries: yes
                            $UNBOUNCTRLCMD -q set_option log-replies: yes
                            $UNBOUNCTRLCMD -q set_option log-time-ascii: yes
                            # NOTE: Viewing 'unbound.conf' may now be inaccurate
                            echo -e $cBCYA"\nunbound logging ENABLED"$cRESET
                            ;;
                        lx)                                                     # v1.16
                            $UNBOUNCTRLCMD -q verbosity 1
                            $UNBOUNCTRLCMD -q set_option log-queries: no
                            $UNBOUNCTRLCMD -q set_option log-replies: no
                            # NOTE: Viewing 'unbound.conf' may now be inaccurate
                            echo -e $cBCYA"\nunbound logging DISABLED"$cRESET
                            ;;
                        l|ln*)                                                  # v1.16
                            local TXT=
                            # logfile: "/opt/var/lib/unbound/unbound.log" or "unbound.log"
                            LOGFILE="$(grep -E "[^#]logfile:.*" ${CONFIG_DIR}unbound.conf | awk '{print $2}' | tr -d '"')"  # v1.25
                            [ "${LOGFILE:0:1}" != "/" ] && LOGFILE=${CONFIG_DIR}$LOGFILE            # v1.26
                            [ -n "$(grep -E "[^#]use-syslog: yes" "${CONFIG_DIR}unbound.conf")" ] && { LOGFILE="/opt/var/log/unbound.log"; local TXT=" (syslog-ng)"; }    # v1.25 syslog-ng/scribe
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
                s|sa|"q?"|fs|oq|oq*|ox|ox*|s+|s-|sp)                                        # v1.08
                    echo
                    unbound_Control "$menu1"                                    # v1.16
                    #break
                ;;
                u|uf)                                                           # v1.07
                    [ "$menu1" == "uf" ] && echo -e $cRED_"\n"Forced Update"\n"$cRESET              # v1.07
                    update_installer $menu1
                    [ $? -eq 0 ] && exec "$0"                                   # v1.18 Only exit if new script downloaded

                ;;
                rs|rsnouser)                                                    # v1.07
                    echo
                    [ "$menu1" == "rsnouser" ] &&  sed -i '/^username:.*\"nobody\"/s/nobody//' ${CONFIG_DIR}unbound.conf
                    /opt/etc/init.d/S61unbound restart
                    CHECK_GITHUB=1                                          # v1.27 force a GitHub version check to see if we are OK
                    echo -en $cRESET"\nPlease wait for up to ${cBYEL}10 seconds${cRESET} for status....."$cRESET
                    WAIT=11     # 16 i.e. 15 secs should be adequate?
                    INTERVAL=1
                    I=0
                     while [ $I -lt $((WAIT-1)) ]
                        do
                            sleep 1
                            I=$((I + 1))
                            [ -z "$(pidof unbound)" ] && { echo -e $cBRED"\a\n\t***ERROR unbound went AWOL after $aREVERSE$I seconds${cRESET}$cBRED.....\n\tTry debug mode and check for unbound.conf or runtime errors!"$cRESET ; break; }
                        done
                    [ -n "$(pidof unbound)" ] && echo -e $cBGRE"unbound OK"
                    [ "$menu1" == "rsnouser" ] &&  sed -i 's/^username:.*\"\"/username: \"nobody\"/' ${CONFIG_DIR}unbound.conf
                    #break
                ;;
                stop)
                    echo
                    /opt/etc/init.d/S61unbound stop
                    break
                ;;
                dd|ddnouser)                                                # v1.07
                    echo
                    [ "$menu1" == "ddnouser" ] &&  sed -i '/^username:.*\"nobody\"/s/nobody//' ${CONFIG_DIR}unbound.conf
                    echo -e $cBYEL
                    unbound -vvvd
                    echo -e $cRESET
                    [ "$menu1" == "ddnouser" ] &&  sed -i 's/username:.*\"\"/username: \"nobody\"/' ${CONFIG_DIR}unbound.conf
                    break
                ;;
                about|"?")                                                      # v1.17
                    echo -e $cBGRE"\n\tVersion="$VERSION
                    echo -e $cBMAG"\tLocal\t\t\\t\t\tmd5="$localmd5
                    echo -e $cBMAG"\tGithub\t\t\t\t\tmd5="$remotemd5
                    echo -e $cBMAG"\t/jffs/scripts/unbound_manager.md5\tmd5="$(cat /jffs/scripts/unbound_manager.md5)

                    Check_GUI_NVRAM

                    echo -e $cBCYA"\n\tunbound Memory/Cache:\n"                         # v1.26
                    CACHESIZE="$($UNBOUNCTRLCMD get_option key-cache-size)";echo -e $cRESET"\t'key-cache-size:'\t$cBMAG"$CACHESIZE" ("$(echo $(Size_Human "$CACHESIZE") | cut -d' ' -f1)"m)"
                    CACHESIZE="$($UNBOUNCTRLCMD get_option msg-cache-size)";echo -e $cRESET"\t'msg-cache-size:'\t$cBMAG"$CACHESIZE" ("$(echo $(Size_Human "$CACHESIZE") | cut -d' ' -f1)"m)"
                    CACHESIZE="$($UNBOUNCTRLCMD get_option rrset-cache-size)";echo -e $cRESET"\t'rrset-cache-size:'\t$cBMAG"$CACHESIZE" ("$(echo $(Size_Human "$CACHESIZE") | cut -d' ' -f1)"m)"

                    echo -e $cBCYA"\n\tSystem Memory/Cache:\n"
                    SYSTEMRAM="$(free -m | sed 's/^[ \t]*//;s/[ \t]*$//')"
                    SYSTEMRAM=$(echo "$SYSTEMRAM" | sed 's/Mem:/\\tMem:/' | sed 's/\-/\\t\-/' | sed "s/Swap:/\\tSwap:/")

                    echo -e $cRESET"\t             $SYSTEMRAM"
                    # No of processors/threads
                    #$UNBOUNCTRLCMD get_option thread
                    echo -e $cBCYA"\n\tClick ${cBYEL}https://rootcanary.org/test.html ${cRESET}to view Web DNSSEC Test"
                ;;
                sd|dnsmasqstats)                                            # v1.18

                    [ -n "$(ps | grep -v grep | grep -F "syslog-ng")" ] && SYSLOG="/opt/var/log/messages" || SYSLOG="/tmp/syslog.log"
                    # Is scribe / Diversion running?
                    if grep -q diversion /etc/dnsmasq.conf ;then
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
                easy|advanced)
                    [ "$menu1" == "easy"  ] && EASYMENU="Y" || EASYMENU=        # v1.21 Flip from 'Easy' to 'Advanced'
                    echo -e $cBGRA
                    ;;
                e)
                    exit_message
                    break

                ;;
                ad|ad*)
                    if [ "$(echo "$menu1" | wc -w)" -ge 2 ];then
                        local FN=$(echo "$menu1" | awk '{print $2}')
                        [ "${FN:0:5}" = "type=" ] && { TYPE=$(echo "$menu1" | awk '{print $2}'); FN="all"; }

                        [ "$(echo "$menu1" | wc -w)" -gt 2 ] && local TYPE=$(echo "$menu1" | awk '{print $3}')
                        Diversion_to_unbound_list "$FN" "$TYPE"             # v1.25
                    else
                        Diversion_to_unbound_list "all"                     # v1.25
                    fi
                ;;
                getrootdns)                                                 # v1.24
                    echo
                    Get_RootDNS
                ;;
                '')                                                         # v1.17
                    [ -n "$ADVANCED_TOOLS" ] && ADVANCED_TOOLS=             # v1.21
                ;;
                ca|ca*)                                                     # v1.26
                    # optional 'reset' will reset to minimum sizes
                    echo
                    [ "$(echo "$menu1" | awk '{print $2}')" == "reset" ] && Optimise_CacheSize "reset" || Optimise_CacheSize
                ;;
                scribe)                                                     # v1.27
                    local TXT=
                    if [ -d /opt/etc/syslog-ng.d ];then
                        if [ ! -f /opt/etc/syslog-ng.d/unbound ];then
                            local TXT="Created scribe 'unbound' file: "
                            cat > /opt/etc/syslog-ng.d/unbound << EOF       # Generate the missing unbound scribe file
# log all unbound logs to /opt/var/log/unbound.log and stop processing unbound logs

destination d_unbound {
    file("/opt/var/log/unbound.log");
};

filter f_unbound {
    program("unbound");
};

log {
    source(src);
    filter(f_unbound);
    destination(d_unbound);
    flags(final);
};
#eof
EOF
                            /opt/bin/scribe reload 2>/dev/null
                            /opt/etc/init.d/S61unbound restart

                        fi
                        Uncomment_config_options "use-syslog:"          "uncomment"     # v1.27
                        Uncomment_config_options "log-local-actions:"   "uncomment"     # v1.27
                        echo -en $cBGRE"\n$TXT${cRESET}Enabling syslog-ng logging (scribe) - Reloading 'unbound.conf' status="$cRESET
                        local TXT=
                        unset $TXT
                        $UNBOUNCTRLCMD reload

                    fi
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
                TESTHIS=
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
                echo -e $cBCYA"\nClick ${cBYEL}https://www.quad9.net/faq/#outer-wrap ${cRESET}to view QUAD9 FAQs/servers list etc."
                echo -e $cBCYA"\nClick ${cBYEL}https://1.1.1.1/help ${cRESET}to view Cloudflare."
                ;;
                *)
                    printf '\n\a\t%bInvalid Option%b "%s"%b Please enter a valid option\n' "$cBRED" "$cBGRE" "$menu1" "$cRESET"
                ;;
            esac
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

validate_removal () {

        while true; do
            printf '\n%bIMPORTANT: It is recommended to REBOOT in order to complete the removal of unbound\n             %bYou will be asked to confirm BEFORE proceeding with the REBOOT\n\n' "${cBRED}" "${cBRED}"
            printf '%by%b = Are you sure you want to uninstall unbound?\n' "${cBYEL}" "${cRESET}"
            printf '%bn%b = Cancel\n' "${cBYEL}" "${cRESET}"
            printf '%be%b = Exit Script\n' "${cBYEL}" "${cRESET}"
            printf '\n%bOption ==>%b ' "${cBYEL}" "${cRESET}"
            read -r "menu3"
            case "$menu3" in
                y)
                    remove_existing_installation
                    break
                ;;
                n)
                    welcome_message
                    break
                ;;
                e)
                    exit_message
                    break
                ;;
                *)
                    printf '%bInvalid Option%b %s%b Please enter a valid option\n' "$cBRED" "$cBGRE" "$menu3" "$cRESET"
                ;;
            esac
        done
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
    local TAB="\t"

    [ ! -f $FN ] && echo -e "#!/bin/sh" > $FN                       # v1.11

    if [ "$1" != "del" ];then
        echo -e $cBCYA"Customising 'dnsmasq.postconf' (aka '/jffs/scripts/unbound.postconf')"$cRESET       # v1.08
        # By conention only add one-liner....
        if [ -z "$(grep -E "sh \/jffs\/scripts\/unbound\.postconf" $FN)" ];then
            $(Smart_LineInsert "$FN" "$(echo -e "sh /jffs/scripts/unbound.postconf \"\$1\"\t\t# unbound_manager")" )  # v1.10
        fi

        # Create the actual commands in the file referenced by the one-liner i.e. 'unbound.postconf'
         echo -e "#!/bin/sh"                                                                >  /jffs/scripts/unbound.postconf   # v1.11
         echo -e "CONFIG=\$1"                                                               >> /jffs/scripts/unbound.postconf   # v1.11
         echo -e "source /usr/sbin/helper.sh"                                               >> /jffs/scripts/unbound.postconf   # v1.11
         echo -e "logger -t \"(dnsmasq.postconf)\" \"Updating \$CONFIG for unbound.....\"\t\t\t\t\t\t# unbound_manager"   >> /jffs/scripts/unbound.postconf
         echo -e "if [ -n \"\$(pidof unbound)\" ];then"                                     >> /jffs/scripts/unbound.postconf   # v1.12
         echo -e "${TAB}pc_delete \"servers-file\" \$CONFIG"                                >> /jffs/scripts/unbound.postconf   # v1.11
         echo -e "${TAB}pc_delete \"no-negcache\" \$CONFIG"                                 >> /jffs/scripts/unbound.postconf   # v1.11
         echo -e "${TAB}pc_delete \"domain-needed\" \$CONFIG"                               >> /jffs/scripts/unbound.postconf   # v1.11
         echo -e "${TAB}pc_delete \"bogus-priv\" \$CONFIG"                                  >> /jffs/scripts/unbound.postconf   # v1.11
         echo -e "${TAB}# By design, if GUI DNSSEC ENABLED then attempt to modify 'cache-size=0' results in dnsmasq start-up fail loop" >> /jffs/scripts/unbound.postconf
         echo -e "${TAB}#       dnsmasq[15203]: cannot reduce cache size from default when DNSSEC enabled" >> /jffs/scripts/unbound.postconf
         echo -e "${TAB}#       dnsmasq[15203]: FAILED to start up"                         >> /jffs/scripts/unbound.postconf
         echo -e "${TAB}if [ -n \"\$(grep \"^dnssec\" \$CONFIG)\" ];then"                   >> /jffs/scripts/unbound.postconf   # v1.16
         echo -e "${TAB}${TAB}pc_delete \"dnssec\" \$CONFIG"                                >> /jffs/scripts/unbound.postconf   # v1.16
         echo -e "${TAB}${TAB}logger -t \"(dnsmasq.postconf)\" \"**Warning: Removing 'dnssec' directive from 'dnsmasq' to allow DISABLE cache (set 'cache-size=0')\""   >> /jffs/scripts/unbound.postconf       # v1.16
         echo -e "${TAB}fi"                                                                 >> /jffs/scripts/unbound.postconf
         echo -e "${TAB}pc_replace \"cache-size=1500\" \"cache-size=0\" \$CONFIG"           >> /jffs/scripts/unbound.postconf   # v1.11
         echo -e "${TAB}UNBOUNDLISTENADDR=\"127.0.0.1#53535\""                              >> /jffs/scripts/unbound.postconf   # v1.12
         echo -e "#${TAB}UNBOUNDLISTENADDR=\"\$(netstat -nlup | awk '/unbound/ { print \$4 } ' | tr ':' '#')\"\t# unbound_manager"   >> /jffs/scripts/unbound.postconf    # v1.12
         echo -e "${TAB}pc_append \"server=\$UNBOUNDLISTENADDR\" \$CONFIG"                  >> /jffs/scripts/unbound.postconf   # v1.11
         echo -e "${TAB}if [ \"\$(uname -o)\" == \"ASUSWRT-Merlin-LTS\" ];then\t# Requested by @dave14305"  >> /jffs/scripts/unbound.postconf   # v1.26
         echo -e "${TAB}${TAB}pc_delete \"resolv-file\" \$CONFIG"                           >> /jffs/scripts/unbound.postconf    # v1.26
         echo -e "${TAB}${TAB}pc_append \"no-resolv\" \$CONFIG"                             >> /jffs/scripts/unbound.postconf    # v1.26
         echo -e "${TAB}fi"                                                                 >> /jffs/scripts/unbound.postconf    # v1.26
         echo -e "fi"                                                                       >> /jffs/scripts/unbound.postconf   # v1.12

    else
        echo -e $cBCYA"Removing unbound installer directives from 'dnsmasq.postconf'"$cRESET        # v1.08
        sed -i '/#.*unbound_/d' $FN                                                                 # v1.23
        [ -f /jffs/scripts/unbound.postconf ] && rm /jffs/scripts/unbound.postconf                  # v1.11
    fi

    [ -f $FN ] && chmod +x $FN          # v1.06
    [ -f /jffs/scripts/unbound.postconf ] && chmod +x /jffs/scripts/unbound.postconf                # v1.11
}
create_required_directories() {
        for DIR in  "/opt/etc/unbound" "/opt/var/lib/unbound" "/opt/var/lib/unbound/adblock" "/opt/var/log" "/opt/share/unbound/configs"; do
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

        DIR="$1"
        FILE="$2"
        case "$3" in                                            # v1.08
            martineau)
                GITHUB_DIR=$GITHUB_MARTINEAU
            ;;
            rgnldo)
                GITHUB_DIR=$GITHUB_RGNLDO
            ;;
        esac

        STATUS="$(curl --retry 3 -L${SILENT} -w '%{http_code}' "$GITHUB_DIR/$FILE" -o "$DIR/$FILE")"    # v1.08
        if [ "$STATUS" -eq "200" ]; then
            printf '\t%b%s%b downloaded successfully\n' "$cBGRE" "$FILE" "$cRESET"
        else
            printf '\n%b%s%b download FAILED with curl error %s\n\n' "\n\t\a$cBMAG" "'$FILE'" "$cBRED" "$STATUS"
            printf '\tRerun %bunbound_manager nochk%b and select the %bRemove Existing unbound Installation%b option\n\n' "$cBGRE" "$cRESET" "$cBGRE" "$cRESET"   # v1.17

            Check_GUI_NVRAM                                     # v1.17

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
    download_file /opt/etc/init.d S61unbound rgnldo                                         # v1.11

    chmod 755 /opt/etc/init.d/S61unbound >/dev/null 2>&1
}
S02haveged_update() {

    echo -e $cBCYA"Updating S02haveged"$cGRA

    if [ -d "/opt/etc/init.d" ]; then
        /opt/bin/find /opt/etc/init.d -type f -name S02haveged* | while IFS= read -r "line"; do
            rm "$line"
        done
    fi

    download_file /opt/etc/init.d S02haveged rgnldo                                         # v1.11

    chmod 755 /opt/etc/init.d/S02haveged >/dev/null 2>&1

    /opt/etc/init.d/S02haveged restart
}
Option_Stubby_Integration() {

     local ANS=$1                                           # v1.20
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ];then
        echo -e "\nDo you want to integrate Stubby with unbound?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     [ "$ANS" == "y"  ] && Stubby_Integration
}
Stubby_Integration() {

    echo -e $cBCYA"Integrating Stubby with unbound....."$cBGRA
    # Firmware may already contain stubby i.e. which stubby --> /usr/sbin/stubby '0.2.9' aka spoof 100002009
    ENTWARE_STUBBY_MAJVER=$(opkg info stubby | grep "^Version" | cut -d' ' -f2 | cut -d'-' -f1)
    [ -f /usr/sbin/stubby ] && FIRMWARE_STUBBY_MAJVER=$(/usr/sbin/stubby -V) || FIRMWARE_STUBBY_VER="n/a"

    echo -e $cBCYA"Entware stubby Major version="$ENTWARE_STUBBY_MAJVER", Firmware stubby Major version="${FIRMWARE_STUBBY_MAJVER}$cBGRA
    ENTWARE_STUBBY_MAJVER=$(opkg info stubby | grep "^Version" | cut -d' ' -f2 | tr '-' ' ' | awk 'BEGIN { FS = "." } {printf(1"%03d%03d%03d",$1,$2,$3)}')
    [ -f /usr/sbin/stubby ] && FIRMWARE_STUBBY_MAJVER=$(/usr/sbin/stubby -V | awk 'BEGIN { FS = "." } {printf(1"%03d%03d%03d",$1,$2,$3)}') || FIRMWARE_STUBBY_VER="000000000"
    opkg install stubby ca-bundle

    download_file /opt/etc/init.d S62stubby rgnldo          # v1.10
    chmod 755 /opt/etc/init.d/S62stubby                     # v1.11
    download_file /opt/etc/stubby/ stubby.yml rgnldo        # v1.08

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
        sed -i '/forward\-zone:/,/forward\-first: yes/s/^#//' ${CONFIG_DIR}unbound.conf     # v1.04
    fi

    if [ "$(nvram get ipv6_service)" != "disabled" ];then                       # v1.10
        echo -e $cBCYA"Customising unbound IPv6 Stubby configuration....."$cRESET
        # Options for integration with TCP/TLS Stubby
        #udp-upstream-without-downstream: yes
        sed -i '/udp\-upstream\-without\-downstream: yes/s/^#//g' ${CONFIG_DIR}unbound.conf
    fi

}
Get_RootDNS() {
     # https://www.iana.org/domains/root/servers
     # https://root-servers.org/ for live status
     echo -e $cBCYA"Retrieving the 13 InterNIC Root DNS Servers from 'https://www.internic.net/domain/named.cache'....."$cBGRA
     curl --progress-bar -o ${CONFIG_DIR}root.hints https://www.internic.net/domain/named.cache     # v1.17
     echo -en $cRESET
}
Backup_unbound_config() {                                                       # v1.27
    local NOW=$(date +"%Y%m%d-%H%M%S")
    local BACKUP_CONFIG=$NOW"_unbound.conf"
    cp -p ${CONFIG_DIR}unbound.conf /opt/share/unbound/configs/$BACKUP_CONFIG
    if [ "$1" == "msg" ];then
        echo -e $cRESET"\nActive $cBMAG'unbound.conf' ${cRESET}backed up to $cBMAG'/opt/share/unbound/configs/$BACKUP_CONFIG'"$cRESET
        #printf "%bActive '%bunbound.conf%b' backup up to '%b%s%b'" "$cRESET" "$cBMAG" "$cRESET" "$cBMAG" "/opt/share/unbound/configs/$BACKUP_CONFIG" "$cRESET"
    else
        echo $BACKUP_CONFIG
    fi
    return 0
}
Customise_config() {

     echo -e $cBCYA"Generating unbound-anchor 'root.key'....."$cBGRA            # v1.07
     /opt/sbin/unbound-anchor -a ${CONFIG_DIR}root.key

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
         download_file $CONFIG_DIR unbound.conf rgnldo
    else
         echo -e $cBCYA"Custom unbound configuration download ${cBRED}skipped$cRESET ('${cBMAG}keepconfig$cRESET' specified)"$cBGRA
    fi

     # Entware creates a traditional '/opt/etc/unbound' directory structure so spoof it         # v1.07
     [ -f /opt/etc/unbound/unbound.conf ] && mv /opt/etc/unbound/unbound.conf /opt/etc/unbound/unbound.conf.Example
     ln -s /opt/var/lib/unbound/unbound.conf /opt/etc/unbound/unbound.conf

     chown nobody /opt/var/lib/unbound                                          # v1.10

     if [ "$KEEPACTIVECONFIG" != "Y" ];then                                 # v1.27
         # Tag the 'unbound.conf' - useful when using multiple configs for testing  # v1.19

         local TAG="# rgnldo Github Version vx.xx (Date Loaded by unbound_manager "$(date)")" # v1.19

         #echo -e $cBCYA"Tagged 'unbound.conf' '$TAG' and backed up to '/opt/share/unbound/configs/reset.conf'"$cRESET   # v1.19
         #sed -i "1i$TAG" ${CONFIG_DIR}unbound.conf                                  # v1.19
         # Backup the config to easily restore it 'rl reset[.conf]'
         cp -f ${CONFIG_DIR}unbound.conf /opt/share/unbound/configs/reset.conf      # v1.19
     fi

     echo -e $cBCYA"Checking IPv6....."$cRESET                              # v1.10
     if [ "$(nvram get ipv6_service)" != "disabled" ];then
         echo -e $cBCYA"Customising unbound IPv6 configuration....."$cRESET
            # integration IPV6
            #do-ip6: no                    # This the default
            #do-ip6: yes                   #@From:
            #interface: ::0
            #access-control: ::0/0 refuse
            #access-control: ::1 allow
            #private-address: fd00::/8
            #private-address: fe80::/10    #@@To:
         #sed -i '/do\-ip6: yes/,/private\-address: fe80::\/10/s/^#//g' ${CONFIG_DIR}unbound.conf    # v1.10
         #sed -i '/do-ip6: no/d' ${CONFIG_DIR}unbound.conf   # v1.12 Remove conflicting IPv6
         Uncomment_config_options "do-ip6: yes" "private-address: fe80::" "uncomment"   # v1.28
         Uncomment_config_options "do-ip6: no" "comment"                                # v1.28 Remove default IPv6
     fi

     echo -e $cBCYA"Customising unbound configuration Options:"$cRESET

     Enable_Logging "$1"                                            # v1.16 Always create the log file, but ask user if it should be ENABLED

}
Option_Optimise_Performance() {

     local ANS=$1                                           # v1.20
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ];then
        echo -e "\nDo you want to optimise Performance/Memory parameters? (Advanced Users)\n\n\tReply$cBRED 'y'$cBGRE or press [Enter] $cRESET to skip"
        read -r "ANS"
     fi
     [ "$ANS" == "y"  ] && Optimise_Performance
}
Optimise_Performance() {

        local FN="/jffs/scripts/init-start"

        local Tuning_script="/jffs/scripts/stuning"             # v1.15 Would benefit from a meaningful name e.g.'unbound_tuning'

        if [ "$1" != "del" ];then
            echo -e $cBCYA"Customising unbound Performance/Memory 'proc/sys/net' parameters"$cGRA           # v1.15
            download_file /jffs/scripts stuning rgnldo
            dos2unix $Tuning_script
            chmod +x $Tuning_script
            [ ! -f $FN ] && { echo "#!/bin/sh" > $FN; chmod +x $FN; }
            if [ -z "$(grep -F "$Tuning_script" $FN | grep -v "^#")" ];then
                $(Smart_LineInsert "$FN" "$(echo -e "sh $Tuning_script start\t\t\t# unbound_manager")" )  # v1.15
            fi
            chmod +x $FN
            echo -e $cBCYA"Applying unbound Performance/Memory tweaks using '$Tuning_script'"$cRESET
            sh $Tuning_script start
        else
             if [ -f $Tuning_script ] || [ -n "$(grep -F "unbound_manager" $FN)" ];then
                echo -e $cBCYA"Deleting Performance/Memory tweaks '$Tuning_script'"
                [ -f $Tuning_script ] && rm $Tuning_script
                sed -i '/#.*unbound_/d' $FN                 # v1.23
             fi
        fi
}
Optimise_CacheSize() {                                      # v1.26

    if [ "$1" != "reset" ];then
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
    else
        unbound_Control "ox" "key-cache-size"   "8m"
        unbound_Control "ox" "msg-cache-size"   "8m"
        unbound_Control "ox" "rrset-cache-size" "16m"

    fi
}
Enable_Logging() {                                          # v1.07

     local ANS=$1                                           # v1.20
     if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
        echo -en $cBYEL"Option Auto Reply 'y'\t"
     fi

     if [ "$USER_OPTION_PROMPTS" == "?" ];then
         # v1.16 allows dynamic Enable/Disable from unbound_manager main menu (Options lo/lx)
         #      but the log file needs to exist in the config so unbound will create it - ready to be used
         echo -e "\nDo you want to ENABLE unbound logging? (You can dynamically ENABLE/DISABLE Logging later from the main menu)\n\n\tReply$cBRED 'y'$cBGRE or press ENTER $cRESET to skip"
         read -r "ANS"
     fi
     if [ "$ANS" == "y"  ];then
         if [ -n "$(grep -oE "#[[:space:]]*verbosity:" ${CONFIG_DIR}unbound.conf)" ];then       # v1.27
            sed -i '/# verbosity:/,/# log-replies: yes/s/^# //' ${CONFIG_DIR}unbound.conf
            Uncomment_config_options "verbosity:" "log-replies:" "uncomment"                    # v1.27
            echo -e $cBCYA"unbound Logging enabled - $(grep -F 'verbosity:' ${CONFIG_DIR}unbound.conf)"$cRESET
         fi
     else
        sed -i '/# logfile:/s/^# //' ${CONFIG_DIR}unbound.conf
     fi

     # @dave14305 recommends 'log-time-ascii: yes'                          # v1.16
     [ -z "$(grep "log-time-ascii:" ${CONFIG_DIR}unbound.conf)" ] && sed -i '/^logfile: /alog-time-ascii: yes' ${CONFIG_DIR}unbound.conf    #v1.19
}
Enable_unbound_statistics() {

    # unbound-control-setup uses 'setup in directory /opt/var/lib/unbound' ???
    # generating unbound_server.key
    # Generating RSA private key, 3072 bit long modulus
    # ....................................++++
    # .......................................................................................................................................................................++++
    # e is 65537 (0x10001)
    # generating unbound_control.key-file
    echo -e $cBCYA"Initialising 'unbound-control-setup'"$cBGRA
    unbound-control-setup
    #echo -e $cBMAG"Use '$UNBOUNCTRLCMD stats_noreset' to monitor unbound performance"$cRESET
}
unbound_Control() {

    # Each call to unbound-control takes upto 2 secs;  use the -c' parameter            # v1.27
    #unbound-control -q status
    #if [ "$?" != 0 ]; then
    [ -z "$(pidof unbound)" ] && { echo -e $cBRED"\a***ERROR unbound not running!" 2>&1; return 1; }    # v1.26
    #fi

    #[ -z "$" ] && { echo -e $cBRED"\a***ERROR unbound not installed!" 2>&1; return 1; }

    local RESET="_noreset"                  # v1.08

    case $1 in
        s)
            # xxx-cache.count values won't be shown without 'extended-statistics: yes' see 's+'/'s-' menu option
            $UNBOUNCTRLCMD stats$RESET | grep -E "total\.|cache\.count"  | column          # v1.08
            # Calculate %Cache HIT success rate
            local TOTAL=$($UNBOUNCTRLCMD stats$RESET | grep -oE "total.num.queries=.*" | cut -d'=' -f2)
            local CACHEHITS=$($UNBOUNCTRLCMD stats$RESET | grep -oE "total.num.cachehits=.*" | cut -d'=' -f2)
            local PCT=$((CACHEHITS*100/TOTAL))
            printf "\n%bSummary: Cache Hits success=%3.2f%%" "$cRESET" "$PCT"
        ;;
        sa)
            $UNBOUNCTRLCMD stats$RESET  | column
        ;;
        "s+"|"s-")                                                      # v1.18
            CONFIG_VARIABLE="extended-statistics"
            [ "$1" == "s+" ] && CONFIG_VALUE="yes" || CONFIG_VALUE="no"
            local RESULT="$($UNBOUNCTRLCMD set_option $CONFIG_VARIABLE $CONFIG_VALUE)"
            [ "$RESULT" == "ok" ] && local COLOR=$cBGRE || COLOR=$cBRED
            echo -e $cRESET"$UNBOUNCTRLCMD set_option $cBMAG'$CONFIG_VARIABLE $CONFIG_VALUE'$COLOR $RESULT"  2>&1
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
                [ -z "$(echo "$RESULT" | grep -ow "error" )" ] && echo -e $cRESET"unbound-control $cBMAG'$CONFIG_VARIABLE'$cRESET $CBGRE'$RESULT'"  2>&1 || echo -e $cRESET"unbound-control get_option $cBMAG'$CONFIG_VARIABLE:'$cBRED $RESULT" 2>&1
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
                CONFIG_VALUE=$(echo "$@" | awk '{print $3'})
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

        #if [ "$1" == "create" ];then
            # Create alias 'unbound_manager' for '/jffs/scripts/unbound_manager.sh' # v1.22
            if [ -d "/opt/bin" ] && [ ! -L "/opt/bin/unbound_manager" ]; then
                echo -e $cBGRE"Creating 'unbound_manager' alias" 2>&1
                ln -s /jffs/scripts/unbound_manager.sh /opt/bin/unbound_manager    # v1.04
            fi
        #else
            # Remove Script alias - why?
            #echo -e $cBCYA"Removing 'unbound_manager' alias" 2>&1
            #rm -rf "/opt/bin/unbound_manager" 2>/dev/null
        #fi
}
Check_SWAP() {

    local SWAPSIZE=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
    [ $SWAPSIZE -gt 0 ] && { echo $SWAPSIZE; return 0;} || { echo $SWAPSIZE; return 1; }
}
update_installer() {

    local UPDATED=1         # 0=Updated; 1=NOT Updated              # v1.18

    if [ "$1" == "uf" ] || [ "$localmd5" != "$remotemd5" ]; then
        if [ "$1" == "uf" ] || [ "$( awk '{print $1}' /jffs/scripts/unbound_manager.md5)" != "$remotemd5" ]; then # v1.18
            echo 2>&1
            download_file /jffs/scripts unbound_manager.sh martineau
            printf '\n%bunbound Manager UPDATE Complete! %s\n' "$cBGRE" "$remotemd5" 2>&1
            localmd5="$(md5sum "$0" | awk '{print $1}')"
            echo $localmd5 > /jffs/scripts/unbound_manager.md5        # v1.18
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
        echo -e $cBCYA"Removing InterNIC Root DNS Servers cron job"$cRESET
        if grep -qF "root_servers" /jffs/scripts/services-start; then
            sed -i '/root_servers/d' /jffs/scripts/services-start
        fi
        cru d root_servers 2>/dev/null

        # Remove Ad and Tracker cron job /jffs/scripts/services-start   # v1.07
        echo -e $cBCYA"Removing Ad and Tracker Update cron job"$cRESET
        if grep -qF "gen_adblock" /jffs/scripts/services-start; then
            sed -i '/gen_adblock/d' /jffs/scripts/services-start
        fi
        cru d adblock 2>/dev/null

        echo -en $cRESET

        ln -f /opt/etc/unbound/unbound.conf 2>/dev/null
        mv /opt/etc/unbound/unbound.conf.Example /opt/etc/unbound/unbound.conf 2>/dev/null

        # Remove the unbound package
        Chk_Entware unbound
        if [ "$READY" -eq "0" ]; then
            echo -e $cBCYA"Existing unbound package found. Removing unbound"$cBGRA
            if opkg remove $ENTWARE_UNBOUND; then echo -e $cBGRE"unbound Entware packages '$ENTWARE_UNBOUND' successfully removed"; else echo -e $cBRED"\a\t***Error occurred when removing unbound"$cRESET; fi # v1.15
            #if opkg remove haveged; then echo "haveged successfully removed"; else echo "Error occurred when removing haveged"; fi
            #if opkg remove coreutils-nproc; then echo "coreutils-nproc successfully removed"; else echo "Error occurred when removing coreutils-nproc"; fi
        else
            echo -e $cRED"Unable to remove unbound - 'unbound' not installed?"$cRESET
        fi

        # Purge unbound directories
        #(NOTE: Entware installs to '/opt/etc/unbound' but some kn*b-h*d wants '/opt/var/lib/unbound'
        for DIR in "/opt/var/lib/unbound/adblock" "/opt/var/lib/unbound" "/opt/etc/unbound"; do     # v1.07
            if [ -d "$DIR" ]; then
                if ! rm "$DIR"/* >/dev/null 2>&1; then
                    printf '%bNo files found to remove in %b%s%b\n' "${cRESET}$cRED" "$cBGRE" "$DIR" "$cRESET"
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

        Check_dnsmasq_postconf "del"
        echo -en $cBCYA"Restarting dnsmasq....."$cBGRE      # v1.14
        service restart_dnsmasq             # v1.14 relocated - Just in case reboot is skipped!

        #Script_alias "delete"

        Optimise_Performance "del"              # v1.15

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
            [ "$CONTINUE_INSTALLATION" != "Y" ] && { echo -e $cBRED"\a\n\tunbound $ACTION CANCELLED!.....\n"$cRESET; exit 1; }
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
            echo -e $cBGRE"unbound Entware packages '$ENTWARE_UNBOUND' successfully installed"$cBGRA
        else
            echo -e $cBRED"\a\n\n\t***ERROR occurred installing unbound\n"$cRESET
            exit 1
        fi

        # echo -e $cBCYA"Linking '${CONFIG_DIR}unbound.conf' --> '/opt/var/lib/unbound/unbound.conf'"$cRESET
        # ln -s ${CONFIG_DIR}unbound.conf /opt/var/lib/unbound/unbound.conf 2>/dev/null # Hack to retain '/opt/etc/unbound' for configs

        Enable_unbound_statistics                               # Install Entware opkg 'unbound-control'

        Install_Entware_opkg "column"
        Install_Entware_opkg "diffutils"                         #v1.25

        if [ "$(uname -o)" != "ASUSWRT-Merlin-LTS" ];then          # v1.26 AS per dave14305
            Install_Entware_opkg "haveged"
            S02haveged_update
        fi

        Check_dnsmasq_postconf

        create_required_directories

        S61unbound_update
        Customise_config                    "$AUTO_REPLY1"

        Option_Optimise_Performance         "$AUTO_REPLY4"

        Option_Stubby_Integration           "$AUTO_REPLY2"

        echo -en $cBCYA"Restarting dnsmasq....."$cBGRE          # v1.13
        service restart_dnsmasq                                 # v1.13
        echo -en $cRESET

        Option_Ad_Tracker_Blocker           "$AUTO_REPLY3"

        Option_Disable_Firefox_DoH          "$AUTO_REPLY5"      # v1.18

        local END_TIME=$(date +%s)
        local DIFFTIME=$((END_TIME-START_TIME))

        # unbound apparently has a habit of taking its time to fully process its 'unbound.conf' and may terminate due to invalid directives
        # e.g. fatal error: could not open autotrust file for writing, /root.key.22350-0-2a0796d0: Permission denied
        [ "$USER_OPTION_PROMPTS" == "?" ] && local INSTALLMETHOD="Manual install" || local INSTALLMETHOD="Auto install"
        echo -e $cRESET"\n$INSTALLMETHOD unbound Customisation complete $cBGRE$(($DIFFTIME / 60)) minutes and $(($DIFFTIME % 60)) seconds elapsed - ${cRESET}Please wait for up to ${cBCYA}10$cRESET seconds for ${cBCYA}status.....\n"$cRESET
        WAIT=11     # 16 i.e. 15 secs should be adequate?
        INTERVAL=1
        I=0
         while [ $I -lt $((WAIT-1)) ]
            do
                sleep 1
                I=$((I + 1))
                [ -z "$(pidof unbound)" ] && { echo -e $cBRED"\a\n\t***ERROR unbound went AWOL after $aREVERSE$I seconds${cRESET}$cBRED.....\n"$cRESET ; break; }
            done                                                                            # v1.06

        if pidof unbound >/dev/null 2>&1; then
            service restart_dnsmasq >/dev/null      # v1.18 Redundant? - S61unbound now reinstates 'POSTCMD=service restart_dnsmasq'

            if [ "$KEEPACTIVECONFIG" != "Y" ];then                              # v1.27
                local TAG="# rgnldo User Install Custom Version vx.xx (Date Loaded by unbound_manager "$(date)")" # v1.19
                #echo -e $cBCYA"Tagged 'unbound.conf' '$TAG' and backed up to '/opt/share/unbound/configs/user.conf'"$cRESET
                # Backup the config to easily restore it 'rl user[.conf]'   # v1.19
                cp -f ${CONFIG_DIR}unbound.conf /opt/share/unbound/configs/user.conf    # v1.19

                #sed -i "1i$TAG" /opt/share/unbound/configs/user.conf    # v1.19

                cmp -s ${CONFIG_DIR}unbound.conf /opt/share/unbound/configs/reset.conf || sed -i "1i$TAG" ${CONFIG_DIR}unbound.conf # v1.19
                echo -e $cBGRE"\n\tInstallation of unbound completed\n"     # v1.04
            fi
        else
            echo -e $cBRED"\a\n\t***ERROR Unsuccessful installation of unbound detected\n"      # v1.04
            echo -en ${cRESET}$cRED_
            grep unbound /tmp/syslog.log | tail -n 5            # v1.07
            unbound -dvvv          # v1.06
            echo -e $cRESET"\n"
            printf '\n\tRerun %bunbound_manager nochk%b and select the %bRemove%b option to backout changes\n\n' "$cBGRE" "$cRESET" "$cBGRE" "$cRESET"
            exit_message                                            # v1.18

        fi

        echo -en $cRESET

        Check_GUI_NVRAM

        #exit_message                                               # v1.18
}
Check_GUI_NVRAM() {

        local ERROR_CNT=0

        echo -e $cBCYA"\n\tRouter Configuration recommended pre-reqs status:\n" 2>&1    # v1.04
        # Check Swap file
        [ $(Check_SWAP) -eq 0 ] && echo -e $cBRED"\t[✖] Warning SWAP file is not configured $cRESET - use amtm to create one!" 2>&1 || echo -e $cBGRE"\t[✔] Swapfile="$(grep "SwapTotal" /proc/meminfo | awk '{print $2" "$3}')$cRESET  2>&1    # v1.04

        #   DNSFilter: ON - mode Router
        if [ $(nvram get dnsfilter_enable_x) -eq 0 ];then
            echo -e $cBRED"\a\t[✖] ***ERROR DNS Filter is OFF! $cRESET \t\t\t\t\t\tsee http://$(nvram get lan_ipaddr)/DNSFilter.asp LAN->DNSFilter Enable DNS-based Filtering" 2>&1
            ERROR_CNT=$((ERROR_CNT + 1))
        else
            echo -e $cBGRE"\t[✔] DNS Filter=ON" 2>&1
            #   DNSFilter: ON - Mode Router ?
            [ $(nvram get dnsfilter_mode) != "11" ] && { echo -e $cBRED"\a\t[✖] ***ERROR DNS Filter is NOT = 'Router' $cRESET \t\t\t\tsee http://$(nvram get lan_ipaddr)/DNSFilter.asp ->LAN->DNSFilter"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] DNS Filter=ROUTER" 2>&1
        fi

        if [ "$(uname -o)" == "ASUSWRT-Merlin-LTS" ];then               # v1.26 HotFix @dave14305
            [ $(nvram get ntpd_server) == "0" ] && { echo -e $cBRED"\a\t[✖] ***ERROR Enable local NTP server=NO $cRESET \t\t\t\t\tsee http://$(nvram get lan_ipaddr)/Advanced_System_Content.asp ->Basic Config"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] Enable local NTP server=YES" 2>&1
        else
            #   Tools/Other WAN DNS local cache: NO # for the FW Merlin development team, it is desirable and safer by this mode.
            [ $(nvram get dns_local_cache) != "0" ] && { echo -e $cBRED"\a\t[✖] ***ERROR WAN: Use local caching DNS server as system resolver=YES $cRESET \t\tsee http://$(nvram get lan_ipaddr)/Tools_OtherSettings.asp ->Advanced Tweaks and Hacks"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] WAN: Use local caching DNS server as system resolver=NO" 2>&1

            #   Configure NTP server Merlin
            [ $(nvram get ntpd_enable) == "0" ] && { echo -e $cBRED"\a\t[✖] ***ERROR Enable local NTP server=NO $cRESET \t\t\t\t\tsee http://$(nvram get lan_ipaddr)/Advanced_System_Content.asp ->Basic Config"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] Enable local NTP server=YES" 2>&1
        fi

        # Check GUI 'Enable DNS Rebind protection'          # v1.18
        [ "$(nvram get dns_norebind)" == "1" ] && { echo -e $cBRED"\a\t[✖] ***ERROR Enable DNS Rebind protection=YES $cRESET \t\t\t\t\tsee http://$(nvram get lan_ipaddr)/Advanced_WAN_Content.asp ->WAN DNS Setting"$cRESET 2>&1; ERROR_CNT=$((ERROR_CNT + 1)); } || echo -e $cBGRE"\t[✔] Enable DNS Rebind protection=NO" 2>&1

        # Check GUI 'Enable DNSSEC support'                 # v1.15
        [ "$(nvram get dnssec_enable)" == "1" ] && echo -e $cBRED"\a\t[✖] Warning Enable DNSSEC support=YES $cRESET \t\t\t\t\t\tsee http://$(nvram get lan_ipaddr)/Advanced_WAN_Content.asp ->WAN DNS Setting"$cRESET 2>&1 || echo -e $cBGRE"\t[✔] Enable DNSSEC support=NO" 2>&1

        #if [ "$1" != "install" ];then                      # v1.18 Don't bother reporting the options on "install"
            [ "$USER_OPTION_PROMPTS" != "?" ] && local TXT="$cRESET Auto Reply='y' for User Selectable Options ('$CURRENT_AUTO_OPTIONS')" || local TEXT=        # v1.20

            if [ "$ACTION" == "INSTALL" ] && [ "$USER_OPTION_PROMPTS" == "N" ];then
                local TXT="${cRESET}$cBGRE unbound ONLY install$cRESET - No User Selectable options will be configured"
            fi
            if [ "$ACTION" == "INSTALL" ] && [ "$USER_OPTION_PROMPTS" == "?" ];then
                local TXT="${cRESET}$cBGRE unbound Advanced install$cRESET - User will be prompted to install options"
            fi

            echo -e $cBCYA"\n\tOptions:$TXT\n" 2>&1

            if [ -f ${CONFIG_DIR}unbound.conf ];then
                if [ -n "$(grep -E "^[[:blank:]]*[^#]" ${CONFIG_DIR}unbound.conf | grep -o "log-replies:" ${CONFIG_DIR}unbound.conf)" ] || [ -n "$(grep -E "[^#]log-queries:" ${CONFIG_DIR}unbound.conf)" ] ;then
                    echo -e $cBGRE"\t[✔] unbound Logging" 2>&1
                fi
                [ -n "$(grep -E "^[[:blank:]]*[^#]" ${CONFIG_DIR}unbound.conf | grep -o "forward-zone:" ${CONFIG_DIR}unbound.conf)" ] && echo -e $cBGRE"\t[✔] Stubby Integration" 2>&1

                if [ -n "$(grep -E "^[[:blank:]]*[^#]" ${CONFIG_DIR}unbound.conf | grep -o "include:.*adblock/adservers" ${CONFIG_DIR}unbound.conf)" ];then
                    local TXT="No. of Adblock domains="$cBMAG"$(wc -l <${CONFIG_DIR}adblock/adservers),"${cRESET}"Blocked Hosts="$cBMAG"$(wc -l <${CONFIG_DIR}adblock/blockhost),"${cRESET}"Whitelist="$cBMAG"$(wc -l <${CONFIG_DIR}adblock/permlist)"$cRESET
                    # Check if Diversion is also running
                    [ -n "$(grep diversion /etc/dnsmasq.conf)" ] && local TXT=$TXT", "$cBRED"- Warning Diversion is also ACTIVE"    # v1.24
                    echo -e $cBGRE"\t[✔] Ad and Tracker Blocking"$cRESET" ($TXT)" 2>&1
                fi
                [ -f /jffs/scripts/stuning ] && echo -e $cBGRE"\t[✔] unbound CPU/Memory Performance tweaks" 2>&1
                [ -n "$(grep -E "^[[:blank:]]*[^#]" ${CONFIG_DIR}unbound.conf | grep -o "include:.*adblock/firefox_DOH" ${CONFIG_DIR}unbound.conf)" ] && echo -e $cBGRE"\t[✔] Firefox DNS-over-HTTPS (DoH) DISABLE/Blocker" 2>&1
            fi
        #fi

        [ $ERROR_CNT -ne 0 ] && { $ERRORCNT; return 1; } || return 0

        local TXT=
        unset $TXT
        echo -e $cRESET 2>&1
}
exit_message() {

        rm -rf /tmp/unbound.lock
        echo -e $cRESET
        exit 0
}
Option_Ad_Tracker_Blocker() {

        local ANS=$1                                        # v1.20
        if [ "$USER_OPTION_PROMPTS" != "?" ] && [ "$ANS" == "y"  ];then
            echo -en $cBYEL"Option Auto Reply 'y'\t"
        fi

        if [ "$USER_OPTION_PROMPTS" == "?" ];then
            echo -e "\nDo you want to install Ad and Tracker blocking?\n\n\tReply$cBRED 'y' ${cBGRE}or press [Enter] $cRESET to skip"
            read -r "ANS"
        fi
        [ "$ANS" == "y"  ] && Ad_Tracker_blocking           # v1.06

        # ....but just in case ;-)
        [ -z "$(pidof unbound)" ] && /opt/etc/init.d/S61unbound start || /opt/etc/init.d/S61unbound restart # Will also restart dnsmasq
}
Ad_Tracker_blocking() {

    local FN="/jffs/scripts/services-start"

    echo -e $cBCYA"Installing Ads and Tracker Blocking....."$cRESET     # v1.06
    #download_file ${CONFIG_DIR} unbound_adblock.tar.bz2 rgnldo         # v1.08
    #echo -e $cBCYA"Unzipping 'unbound_adblock.tar.bz2'....."$cBGRA
    #tar -jxvf ${CONFIG_DIR}unbound_adblock.tar.bz2 -C ${CONFIG_DIR}    # v1.07

    download_file ${CONFIG_DIR} adblock/gen_adblock.sh  rgnldo          # v1.17
    download_file ${CONFIG_DIR} adblock/blockhost       rgnldo          # v1.17
    download_file ${CONFIG_DIR} adblock/permlist        rgnldo          # v1.17

    # FFS! Make sure the downloaded script doesn't use '/jffs'
    if [ -n "$(grep -F "/jffs/" ${CONFIG_DIR}adblock/gen_adblock.sh)" ];then
        echo -e ${aBLINK}$cRED"Sanitising '/jffs/' references in ${CONFIG_DIR}adblock/gen_adblock.sh)...."${cRESET}$cBGRA
        sed -i "s~/jffs/~${CONFIG_DIR}~" ${CONFIG_DIR}adblock/gen_adblock.sh
    fi

    echo -e $cBCYA"Executing '${CONFIG_DIR}adblock/gen_adblock.sh'....."$cBGRA
    chmod +x ${CONFIG_DIR}adblock/gen_adblock.sh
    sh ${CONFIG_DIR}adblock/gen_adblock.sh              # Apparently requests '/opt/etc/init.d/S61unbound restart'
                                                        # and deletes '/opt/var/lib/unbound/unbound.log' WTF!

    if [ -n "$(grep -E "^#[\s]*include:.*adblock/adservers" ${CONFIG_DIR}unbound.conf)" ];then              # v1.07
        echo -e $cBCYA"Adding Ad and Tracker 'include: ${CONFIG_DIR}adblock/adservers'"$cRESET
        sed -i "/adblock\/adservers/s/^#//" ${CONFIG_DIR}unbound.conf                                       # v1.11
    fi

    # Create cron job to refresh the Ads/Tracker lists      # v1.07
    echo -e $cBCYA"Creating Daily cron job for Ad and Tracker update"$cBGRA
    cru d adblock 2>/dev/null
    cru a adblock "0 5 * * *" ${CONFIG_DIR}adblock/gen_adblock.sh       # EVERY day Deletes '/opt/var/lib/unbound/unbound.log'
                                                                        #           Restarts S61unbound
    [ ! -f /jffs/scripts/services-start ] && { echo "#!/bin/sh" > $FN; chmod +x $FN; }
    if [ -z "$(grep -E "gen_adblock" /jffs/scripts/services-start | grep -v "^#")" ];then
        $(Smart_LineInsert "$FN" "$(echo -e "cru a adblock \"0 5 * * *\" ${CONFIG_DIR}adblock/gen_adblock.sh\t# unbound_manager")" )  # v1.13
    fi

    chmod +x $FN                                            # v1.11 Hack????

    echo -e $cRESET
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

    echo -e $cBCYA"Installing Firefox DNS-over-HTTPS (DoH) DISABLE/Blocker...."$cRESET
    download_file ${CONFIG_DIR} adblock/firefox_DOH rgnldo  # v1.18

    if [ -n "$(grep -E "^#[\s]*include:.*adblock/firefox_DOH" ${CONFIG_DIR}unbound.conf)" ];then    # v1.18
        echo -e $cBCYA"Adding Firefox DoH 'include: ${CONFIG_DIR}adblock/firefox_DOH'"$cRESET
        sed -i "/adblock\/firefox_DOH/s/^#//" ${CONFIG_DIR}unbound.conf
    fi

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

    local MSG=$cRESET"Analysed Diversion file:$cBMAG" || local MSG=$cRESET"\nMerged Diversion file:$cBGRE"

    if [ "$1" != "all" ] || [ "${1:0:5}" != "type" ];then
        local DIVERSION_FILES=$1                                            # User specific file to be processed
    fi
    local TYPE=$(echo "$@" | sed -n "s/^.*type=//p" | awk '{print $1}')     # Force TYPE type=adblock or type=pixelserv

    if [ -z "$DIVERSION_FILES" ] || [ "$DIVERSION_FILES" == "all" ];then
        local DIVERSION_FILES="blockinglist blacklist whitelist"
    fi

    local DIV_DIR="/opt/share/diversion/list/"

    for FN in $DIVERSION_FILES
        do
            if [ -z "$(echo "$FN" | grep -i "white" )" ];then
                local DIVERSION="/tmp/diversion-"$FN".raw"
                local UNBOUND="/tmp/unbound-"$FN".add"
                local UNBOUNDADBLOCK="/opt/var/lib/unbound/adblock/adservers"
            else
                local DIVERSION="/tmp/diversion-"$FN".raw"
                local UNBOUND="/tmp/unbound-"$FN".add"
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

                if [ -z "$TYPE" ];then
                    case "$IP" in
                        "0.0.0.0")
                            local TYPE="adblock"
                            ;;
                        *)
                            local TYPE="pixelserv"
                            ;;
                    esac
                fi

                local THIS="$(_quote "$IP")"

                # awk/cut  - Remove the EOL comments, and drop the first word;       sed - expand into individual lines
                awk -F# '{print $1}' $FN | cut -d' ' -f2- | sed 's/ /\n/g' | grep . | sort > ${DIVERSION}X
                if [ "$TYPE" == "adblock" ];then
                    awk '{print "local-zone: \""$1"\" always_nxdomain"}' ${DIVERSION}X > $DIVERSION
                    /opt/bin/diff -uZ --suppress-common-lines $UNBOUNDADBLOCK $DIVERSION  | sed '/^\+/!d s/^\+//' | grep -vF "++"  > $UNBOUND   # v1.25
                else
                    # Pixelserv redirect records, but at this stage we only want to see if a site entry already exists,
                    #           rather than a 'redirect' pair
                    awk '{print "local-zone: \""$1"\" always_nxdomain"}' ${DIVERSION}X > $DIVERSION
                    /opt/bin/diff -uZ --suppress-common-lines $UNBOUNDADBLOCK $DIVERSION  | sed '/^\+/!d s/^\+//' | grep -vF "++" > $UNBOUND    # v1.25
                    # Now convert the new unbound entries in the 'redirect' pairs
                    awk -F'"' '{print $2}' $UNBOUND > ${DIVERSION}X
                    awk -v pixelservip=${IP} '{print "local-zone: \""$1"\" redirect\nlocal-data: \""$1"\" A "pixelservip}' ${DIVERSION}X > $UNBOUND
                fi
            else
                # Whitelist of URLs
                # awk/cut  - Remove the EOL comments,
                awk -F# '{print $1}' $FN | grep . | sort > $DIVERSION
                # diff -uZ --suppress-common-lines /opt/var/lib/unbound/adblock/permlist  /opt/share/diversion/list/whitelist  | sed '/^\+/ s/^\+//' | sort
                # Only extract lines that start with '+' and delete the '+'
                /opt/bin/diff -uZ --suppress-common-lines $UNBOUNDADBLOCK $DIVERSION | sed '/^\+/ s/^\+//' | sort > $UNBOUND
                sed -i '1,/^@@.*/d' $UNBOUND    # Remove the DIFF info lines for the first file $UNBOUNDADBLOCK
            fi

        done

    # Print a report showing unbound Ad Block domains/URLs with diversion domains/URLs and the results of a possible merge
    for FN in $DIVERSION_FILES
        do
            if [ -z "$(echo "$FN" | grep -i "white" )" ];then
                local UNBOUND="/tmp/unbound-"$FN".add"
                local DIVERSION="/tmp/diversion-"$FN".raw"
                local UNBOUNDADBLOCK="/opt/var/lib/unbound/adblock/adservers"
                DESC="Domains"
            else
                local UNBOUND="/tmp/unbound-"$FN".add"
                local DIVERSION="/tmp/diversion-"$FN".raw"
                local UNBOUNDADBLOCK="/opt/var/lib/unbound/adblock/permlist"
                local URL="Y"
                local TYPE="URL"
                DESC="URLs"
            fi

            local CNT_UNBOUNDADBLOCK=$(wc -l < $UNBOUNDADBLOCK )
            if [ "$TYPE" == "adblock" ] || [ "$TYPE" == "URL" ] ;then
                local CNT_DIVERSION=$(sort $UNBOUNDADBLOCK $UNBOUND | uniq | wc -l)
            else
                cp $UNBOUND ${UNBOUND}X
                sed -i 's/redirect/always_nxdomain/; '/local-data:/d'' ${UNBOUND}X
                local CNT_DIVERSION=$(sort $UNBOUNDADBLOCK ${UNBOUND}X | uniq | wc -l)
                rm ${UNBOUND}X  2>/dev/null
            fi

            rm $DIVERSION       2>/dev/null
            rm ${DIVERSION}X    2>/dev/null

            #sed -i "1i# Diversion $FN \($TYPE\)" $UNBOUND
            [ "$ACTION" == "Merge" ] && { cat $UNBOUND >> $UNBOUNDADBLOCK; REQUIRE_PIXELSERV="Y"; }

            echo -e $MSG "'"$FN"'\t ${cRESET}Type=$TYPE, (Adblock $DESC=$cBMAG"$CNT_UNBOUNDADBLOCK")${cRESET} would add$cBMAG" $(printf "%5d" "$((CNT_DIVERSION-CNT_UNBOUNDADBLOCK))") $cRESET"entries" 2>&1
        done

    if [ -f /opt/etc/init.d/S80pixelserv-tls ] && [ -n "$REQUIRE_PIXELSERV" ] && [ -z "$(pidof pixelserv-tls)" ];then
        /opt/etc/init.d/S80pixelserv-tls start
    fi
}


#=============================================Main=============================================================
# shellcheck disable=SC2068
Main() { true; } # Syntax that is Atom Shellchecker compatible!


ANSIColours

# Need assistance ?
if [ "$1" == "-h" ] || [ "$1" == "help" ];then
    clear                                                   # v1.21
    echo -e $cBWHT
    ShowHelp
    echo -e $cRESET
    exit 0
fi
#echo -e $cBGRE"⚛️"

#exit

Check_Lock "$1"

Script_alias "create"               # v1.08

[ -z "$(echo "$@" | grep -oiw "easy")" ] && EASYMENU= || EASYMENU="Y"
NEW_CONFIG=$(echo "$@" | sed -n "s/^.*config=//p" | awk '{print $1}')                       # v1.22
if [    -n "$NEW_CONFIG" ];then
    [ -z "$(echo "$NEW_CONFIG" | grep -E "\.conf$")" ] && NEW_CONFIG=$NEW_CONFIG".conf"     # v1.22
    [ "${NEWCONFIG:0:1}" != "/" ] && NEW_CONFIG="/opt/share/unbound/configs/"$NEW_CONFIG    # v1.22
    if [ -f  $NEW_CONFIG ];then
        if [ -n "$(pidof unbound)" ];then
            TXT=" <<== $NEW_CONFIG"
            [ -d $CONFIG_DIR ] && cp $NEW_CONFIG ${CONFIG_DIR}unbound.conf
            TAG="(Date Loaded by unbound_manager "$(date)")"
            [ -f ${CONFIG_DIR}unbound.conf ] && sed -i "1s/(Date Loaded.*/$TAG/" ${CONFIG_DIR}unbound.conf
            echo -en $cBCYA"\nReloading 'unbound.conf'$TXT status="$cRESET
            $UNBOUNCTRLCMD reload
            TXT=
            unset $TAG
            unset $TXT
            unset $NEW_CONFIG
        else
            echo -e $cBRED"\a\nunbound not ACTIVE to Load Configuration file '$NEW_CONFIG'\n\n"$cRESET
            rm -rf /tmp/unbound.lock
            exit 1
        fi
    else
        echo -e $cBRED"\a\nConfiguration file '$NEW_CONFIG' NOT found?\n\n"$cRESET
        rm -rf /tmp/unbound.lock
        exit 1
    fi
else
    if [ "$1" == "recovery" ];then                              # v1.22
        NEW_CONFIG="/opt/share/unbound/configs/reset.conf"
        if [ -f  $NEW_CONFIG ];then
            TXT=" <<== $NEW_CONFIG"
            [ -d $CONFIG_DIR ] && cp $NEW_CONFIG ${CONFIG_DIR}unbound.conf
        else
            echo -e $cBCYA"Recovery: Retrieving Custom unbound configuration"$cBGRA
            download_file $CONFIG_DIR unbound.conf rgnldo
        fi
        TAG="(Date Loaded by unbound_manager "$(date)")"
        [ -f ${CONFIG_DIR}unbound.conf ] && sed -i "1s/(Date Loaded.*/$TAG/" ${CONFIG_DIR}unbound.conf
        echo -en $cBCYA"\nRecovery: Reloading 'unbound.conf'$TXT status="$cRESET
        $UNBOUNCTRLCMD reload
        unset $TAG
        TXT=
        unset $TXT
        unset $NEW_CONFIG
    fi
fi

clear
welcome_message "$@"

echo -e $cRESET

rm -rf /tmp/unbound.lock

exit 0
