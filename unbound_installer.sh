#!/bin/sh
####################################################################################################
# Script: unbound_installer.sh
# Original Author: Martineau
# Maintainer:
# Last Updated Date: 27-Dec-2019
#
# Description:
#  Install the unbound DNS over TLS resolver package from Entware on Asuswrt-Merlin firmware.
#  See https://github.com/rgnldo/Unbound-Asuswrt-Merlin for a description of Unbound config/usage changes.
#  See https://github.com/MartineauUK/Unbound-Asuswrt-Merlin for a description of changes to this script,
#
# Acknowledgement:
#  Test team: rngldo
#  Contributors: rgnldo (Xentrk for this script template, thelonelycoder)
#
#
####################################################################################################
export PATH=/sbin:/bin:/usr/sbin:/usr/bin$PATH
logger -t "($(basename "$0"))" "$$ Starting Script Execution ($(if [ -n "$1" ]; then echo "$1"; else echo "menu"; fi))"
VERSION="1.10"
GIT_REPO="unbound-Asuswrt-Merlin"
GITHUB_RGNLDO="https://raw.githubusercontent.com/delusion2019/$GIT_REPO/master"
GITHUB_MARTINEAU="https://raw.githubusercontent.com/MartineauUK/$GIT_REPO/master"
GITHUB_DIR=$GITHUB_MARTINEAU								# v1.08 default for script
CONFIG_DIR="/opt/var/lib/unbound/"
ENTWARE_UNBOUND="unbound-control-setup unbound-control unbound-anchor unbound-daemon"
SILENT="s"													# Default is no progress messages for file downloads # v1.08
ALLOWUPGRADE="Y"											# Default is allow script download from Github		# v1.09

# Uncomment the line below for debugging
#set -x
welcome_message() {
		while true; do

			# No need to display the Header box every tim....
			if [ -z "$HDR" ];then							# v1.09

				printf '\n+======================================================================+\n'
				printf '|  Welcome to the %bunbound-Installer-Asuswrt-Merlin%b installation script |\n' "$cBGRE" "$cRESET"
				printf '|  Version %s by Martineau                                           |\n' "$VERSION"
				printf '|                                                                      |\n'
				printf '| Requirements: USB drive with Entware installed                       |\n'
				printf '|                                                                      |\n'
				printf '| The install script will:                                             |\n'
				printf '|   1. Install the unbound Entware package                             |\n'
				printf '|   2. Override how the firmware manages DNS                           |\n'
				printf '|   3. Optionally Integrate with Stubby                                |\n'
				printf '|   4. Optionally Install Ad and Tracker Blocking                      |\n'
				printf '|   5. Optionally Customise CPU/Memory usage (%bAdvanced Users%b)          |\n' "$cBRED" "$cRESET"
				printf '|                                                                      |\n'
				printf '| You can also use this script to uninstall unbound to back out the    |\n'
				printf '| changes made during the installation. See the project repository at  |\n'
				printf '|         %bhttps://github.com/rgnldo/Unbound-Asuswrt-Merlin%b             |\n' "$cBGRE" "$cRESET"
				printf '|     for helpful user tips on unbound usage/configuration.            |\n'
				printf '+======================================================================+\n'

				HDR="N"										# v1.09
			else
			    echo -e $cGRE_"\n"$cRESET
			fi
			if [ "$1" = "uninstall" ]; then
				menu1="2"
			else
				localmd5="$(md5sum "$0" | awk '{print $1}')"
				remotemd5="$(curl -fsL --retry 3 "${GITHUB_DIR}/unbound_installer.sh" | md5sum | awk '{print $1}')"

				# As I'm the developer, need to differentiate between the GitHub md5sum has'nt changed, which means I've tweaked it locally
				[ ! -f /jffs/scripts/unbound_installer.md5 ] && echo $remotemd5 > /jffs/scripts/unbound_installer.md5	# v1.09

				REMOTE_VERSION_NUMDOT="$(curl -fsLN --retry 3 "${GITHUB_DIR}/unbound_installer.sh" | grep -E "^VERSION" | tr -d '"' | sed 's/VERSION\=//')"	# v1.05

				LOCAL_VERSION_NUM=$(echo $VERSION | sed 's/[^0-9]*//g')				# v1.04
				REMOTE_VERSION_NUM=$(echo $REMOTE_VERSION_NUMDOT | sed 's/[^0-9]*//g')	# v1.04

				if [ -n "$(pidof unbound)" ];then
					UNBOUND_STATUS=$(unbound-control status | grep pid)" uptime: "$(Convert_SECS_to_HHMMSS "$(unbound-control status | grep uptime | awk '{print $2}')" "days")" "$(unbound-control status | grep version)
					echo -e $cBMAG"\n"$UNBOUND_STATUS"\n"$cRESET
				else
					echo
				fi

				#[ -n "$(pidof unbound)" ] && UNBOUND_STATUS="ACTIVE (PID="$(pidof unbound)") " || UNBOUND_STATUS=		# v1.06

				if [ "$localmd5" != "$remotemd5" ]; then
					if [ $REMOTE_VERSION_NUM -gt $LOCAL_VERSION_NUM ];then
						printf '%bu%b  = %bUpdate (Major) %b%s %b%s -> %s\n\n' "${cBYEL}" "${cRESET}" "$cBGRE" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION" "v$REMOTE_VERSION_NUMDOT"	# v1.04
					else
						if [ $REMOTE_VERSION_NUM -lt $LOCAL_VERSION_NUM ];then		# v1.09
							ALLOWUPGRADE="N"												# v1.09
							printf '%bu  = Push to Github PENDING for %b%s%b %s >>>> %s\n\n' "${cBRED}" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION" "v$REMOTE_VERSION_NUMDOT"	# v1.04
						else
							# MD5 Mismatch due to local development?
							if [ "$(awk '{print $1}' /jffs/scripts/unbound_installer.md5)" != "$remotemd5" ];then
								printf '%bu  = %bUpdate (Minor) %b%s %b%s\n\n' "${cYEL}" "$cBGRE" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION"	# v1.07
							else
								if [ $REMOTE_VERSION_NUM -le $LOCAL_VERSION_NUM ];then
									ALLOWUPGRADE="N"												# v1.09
									printf '%bu  = %bPush to Github PENDING for %b(Minor) %b%s %b%s\n\n' "${cBRED}" "$cBRED" "$cBGRE" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION"	# v1.09
								else
									printf '%bu  =  %b%s%b %s <- %s\n\n' "${cBRED}" "$cRESET" "$(basename $0)" "$cBMAG" "v$VERSION" "v$REMOTE_VERSION_NUMDOT"	# v1.04
								fi
							fi
						fi
					fi
				fi


				if [ -f ${CONFIG_DIR}unbound.conf ]; then					# v1.06
					MENU_RS="$(printf '%brs%b = %bRestart%b (or %bStart%b) unbound\n' "${cBYEL}" "${cRESET}" "$cBGRE" "${cRESET}" "$cBGRE" "${cRESET}")"
					MENU_1="$(printf '%b1 %b = Update %b%s %bunbound Configuration\n' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')"  "$cRESET")"
				else
					MENU_1="$(printf '%b1 %b = Begin unbound Installation Process %b%s%b\n' "${cBYEL}" "${cRESET}" "$cBGRE" "('$CONFIG_DIR')" "$cRESET")"
				fi
				MENU_2="$(printf '%b2 %b = Remove Existing unbound Installation\n' "${cBYEL}" "${cRESET}")"
				MENU_L="$(printf "%bl %b = Show unbound log entries\n" "${cBYEL}" "${cRESET}")"

				if [ -n "$(pidof unbound)" ];then
					[ -n "$(which unbound-control)" ] && MENU_QO="$(printf "%bqo%b = Query unbound Configuration option e.g 'qo verbosity' or 'qo logfile'\n" "${cBYEL}" "${cRESET}")"
					MENU_RL="$(printf "%brl%b = Reload unbound Configuration (Doesn't interrupt/halt unbound)\n" "${cBYEL}" "${cRESET}")"
					MENU_S="$(printf '%bs %b = Display unbound statistics (s=Summary Totals; sa=All)\n' "${cBYEL}" "${cRESET}")"
				fi

				# v1.08 use horizontal menu!!!! Radical eh?
				printf "%s\t\t%s\n"             "$MENU_1" "$MENU_L"
				printf "%s\t\t\t\t%s\n"         "$MENU_2" "$MENU_RL"
				printf "\t\t\t\t\t\t\t\t\t%s\n" "$MENU_QO"
				echo
				printf "%s\t\t\t\t\t\t%s\n"     "$MENU_RS" "$MENU_S"

				printf '\n%be %b = Exit Script\n' "${cBYEL}" "${cRESET}"
				printf '\n%bOption ==>%b ' "${cBYEL}" "${cRESET}"
				read -r "menu1"
			fi

			case "$menu1" in
				0)
					HDR=											# v1.09
				;;

				1|1v)
					[ "$menu1" == "1v" ] && { echo -e $cRED_"\nVerbose Download progress messages ENABLED"$cRESET; SILENT=; }				# v1.08
					install_unbound "$@"
					break
				;;
				2)
					validate_removal
					break
				;;
				rl)
					echo -en $cBCYA"\nReloading 'unbound.conf'..... status="$cRESET
					unbound-control reload										# v1.08
					#break
				;;
				l)																# v1.08
					# logfile: "/opt/var/lib/unbound/unbound.log"
					if [ -n "$(grep -E "^logfile:" ${CONFIG_DIR}unbound.conf)" ];then
						echo -e $cBGRE"\a\n\t\tPress CTRL-C to stop\n"$cRESET
						trap 'welcome_message' INT
						tail -F "$(grep -E "^logfile:.*" ${CONFIG_DIR}unbound.conf | awk '{print $2}' | tr -d '"')"								# v1.08
					else
						echo -e $cBRED"\a\nunbound logging not ENABLED\n"$RESET
					fi
					#break
				;;
				s|sa|"q?"|fs|qo|qo*)											# v1.08
					echo
					Query_unbound_control "$menu1"
					#break
				;;
				u|uf)															# v1.07
					[ "$menu1" == "uf" ] && echo -e $cRED_"\n"Forced Update"\n"$cRESET				# v1.07
					update_installer $menu1
					#break
				;;
				rs|rsnouser)													# v1.07
					echo
					[ "$menu1" == "rsnouser" ] &&  sed -i '/^username:.*\"nobody\"/s/nobody//' ${CONFIG_DIR}unbound.conf
					/opt/etc/init.d/S61unbound restart
					echo -en $cRESET"\nPlease wait for up to ${cBYEL}30 seconds${cRESET} for status....."$cRESET
					WAIT=31		# 16 i.e. 15 secs should be adequate?
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
				dd|ddnouser)												# v1.07
					echo
					[ "$menu1" == "ddnouser" ] &&  sed -i '/^username:.*\"nobody\"/s/nobody//' ${CONFIG_DIR}unbound.conf
					echo -e $cBYEL
					unbound -dd
					echo -e $cRESET
					[ "$menu1" == "ddnouser" ] &&  sed -i 's/username:.*\"\"/username: \"nobody\"/' ${CONFIG_DIR}unbound.conf
					break
				;;
				nouser)														# v1.08 debugging Hack
					if [ -f ${CONFIG_DIR}unbound.conf ];then
						echo -e $cRED_"\nusername: \"nobody\" changed to username: \"\"\n"$cRESET
						sed -i '/^username:.*\"nobody\"/s/nobody//' ${CONFIG_DIR}unbound.conf
						unbound-control reload
					fi
				;;
				e)
					exit_message
					break
				;;
				*)
					printf '%bInvalid Option%b %s%b Please enter a valid option\n' "$cBRED" "$cBGRE" "$menu1" "$cRESET"
				;;
			esac
		done
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
		READY="1"					# Assume Entware Utilities are NOT available
		ENTWARE_UTILITY=""			# Specific Entware utility to search for
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
	if [ $SECS -ge 86400 ] && [ -n "$2" ];then				# More than 24:00 i.e. 1 day?
		local DAYS=$((${SECS}/86400))
		SECS=$((SECS-DAYS*86400))
		local DAYS_TXT=$DAYS" days"
	fi
	local HH=$((${SECS}/3600))
	local MM=$((${SECS}%3600/60))
	local SS=$((${SECS}%60))
	if [ -z "$2" ];then
		echo $(printf "%02d:%02d:%02d" $HH $MM $SS)					   # Return 'hh:mm:ss" format
	else
		if [ -n "$2" ] && [ -z "$DAYS_TXT" ];then
			DAYS_TXT="0 Days, "
		fi
		echo $(printf "%s %02d:%02d:%02d" "$DAYS_TXT" $HH $MM $SS)		# Return in "x days hh:mm:ss" format
	fi
}
LastLine_LF() {

# Used by SmartInsertLine()

	case $2 in
		QueryLF)				# Does last line of file end with 'LF'?; if so return 'LF' otherwise return NULL
				[ $(wc -l < $1) -eq $(awk 'END{print NR}' $1 ) ] && echo "\n" || echo ""
				return 0
				;;
		Count)
				echo "$(awk 'END{print NR}' $1)"		# Return number of lines in file
				return 0
				;;
		*)
				echo "$(tail -n 1 $FN)"					# Return the last line of file
				return 0
				;;
	esac

}
Smart_LineInsert() {

# Requires LastLine_LF()

	local FN=$1
	local ARGS=$@
	local TEXT="$(printf "%s" "$ARGS" | cut -d' ' -f2-)"					# Drop the first word
	local TEXT=$(printf "%s" "$TEXT" | sed 's/^[ \t]*//;s/[ \t]*$//')		# Old-skool strip leading/trailing spaces

	sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $FN							# Delete all trailing blank lines from file
	
	# If last line doesn't end with '\n' then add one '\n'
	#[ -n "$(LastLine_LF "$FN" "QueryLF")" ] && echo -e "\n" >> "$FN"
	
	# If LAST line begins with 'exit' then insert TEXT line BEFORE it.
	if [ -z "$(grep -E "^##@Insert##" "$FN")" ];then
		FIRSTWORD=$(grep "." "$FN" | tail -n 1)
		[ "$FIRSTWORD == "exit")" ] && POS=$(awk 'END{print NR}' $FN) || POS=
	else
		POS="$(awk ' /^##@Insert##/ {print NR}' "$FN")";POS=$((POS + 1))
	fi
	[ -n "$POS" ] && { awk -v here="$POS" -v newline="$TEXT" 'NR==here{print newline}1' "$FN" > ${FN}a; rm $FN; mv ${FN}a $FN; } || printf "%s\n" "$TEXT" >> "$FN" 
	
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
check_dnsmasq_parms() {
		if [ -s "/etc/dnsmasq.conf" ]; then  # dnsmasq.conf file exists
			for DNSMASQ_PARM in "server=127.0.0.1#53535"; do		# v1.08
				if grep -q "$DNSMASQ_PARM" "/etc/dnsmasq.conf"; then  # see if line exists
					printf 'Required dnsmasq parm %b%s%b found in /etc/dnsmasq.conf\n' "${cBGRE}" "$DNSMASQ_PARM" "${cRESET}"
					continue #line found in dnsmasq.conf, no update required to /jffs/configs/dnsmasq.conf.add
				fi
				if [ -s "/jffs/configs/dnsmasq.conf.add" ]; then
					if grep -q "$DNSMASQ_PARM" "/jffs/configs/dnsmasq.conf.add"; then  # see if line exists
						#printf '%b%s%b found in /jffs/configs/dnsmasq.conf.add\n' "${cBGRE}" "$DNSMASQ_PARM" "${cRESET}"
						:
					else
						printf 'Adding %b%s%b to /jffs/configs/dnsmasq.conf.add\n' "${cBGRE}" "$DNSMASQ_PARM" "${cRESET}"
						printf '%s\n' "$DNSMASQ_PARM # unbound_installer" >> /jffs/configs/dnsmasq.conf.add
					fi
				else
					printf 'Adding %b%s%b to /jffs/configs/dnsmasq.conf.add\n' "${cBGRE}" "$DNSMASQ_PARM" "${cRESET}"
					printf '%s\n' "$DNSMASQ_PARM" > /jffs/configs/dnsmasq.conf.add
				fi
			done
		else
			echo -e $cBRED"\n\n\t***ERROR '/etc/dnsmasq.conf' file not found?. dnsmasq appears to not be configured on your router. Check router configuration"$cRESET
			exit_message
			exit 1
		fi
}
Check_dnsmasq_postconf() {

	local FN="/jffs/scripts/dnsmasq.postconf"

	if [ -f "$FN" ]; then  # dnsmasq.postconf file exists		# v1.05
		if [ "$1" != "del" ];then
			echo -e $cBCYA"Customising 'dnsmasq.postconf'"$cRESET			# v1.08
			[ -z "$(grep -E "^pc_delete.*servers\-file"    $FN)" ] && $(Smart_LineInsert "$FN" "$(echo -e "pc_delete \"servers-file\" \$CONFIG\t\t\t# unbound_installer")" )
			[ -z "$(grep -E "^pc_delete.*no\-negcache"     $FN)" ] && $(Smart_LineInsert "$FN" "$(echo -e "pc_delete \"no-negcache\" \$CONFIG\t\t\t# unbound_installer")" )
			[ -z "$(grep -E "^pc_delete.*domain\-needed"   $FN)" ] && $(Smart_LineInsert "$FN" "$(echo -e "pc_delete \"domain-needed\" \$CONFIG\t\t\t# unbound_installer")" )
			[ -z "$(grep -E "^pc_delete.*bogus-priv"       $FN)" ] && $(Smart_LineInsert "$FN" "$(echo -e "pc_delete \"bogus-priv\" \$CONFIG\t\t\t# unbound_installer")" )
			[ -z "$(grep -E "^pc_replace.*cache-size=1500" $FN)" ] && $(Smart_LineInsert "$FN" "$(echo -e "pc_replace \"cache-size=1500\" \"cache-size=0\" \$CONFIG\t\t\t# unbound_installer")" )	# v1.10
		else
			echo -e $cBCYA"Removing unbound installer directives from 'dnsmasq.postconf'"$cRESET			# v1.08
			sed -i '/#.*unbound_installer/d' $FN
		fi
	else
		{ echo "#!/bin/sh
CONFIG=\$1
source /usr/sbin/helper.sh
pc_delete \"servers-file\" \$CONFIG # unbound_installer
pc_delete \"no-negcache\" \$CONFIG # unbound_installer
pc_delete \"domain-needed\" \$CONFIG # unbound_installer
pc_delete \"bogus-priv\" \$CONFIG # unbound_installer
pc_replace \"cache-size=1500\" \"cache-size=0\" \$CONFIG # unbound_installer
pc_append \"server=127.0.0.1#53535\" \$CONFIG # unbound_installer"; }	> $FN
			chmod +x $FN			# v1.06
		fi
}
create_required_directories() {
		for DIR in  "/opt/etc/unbound" "/opt/var/lib/unbound" "/opt/var/log"; do
			if [ ! -d "$DIR" ]; then
				if mkdir -p "$DIR" >/dev/null 2>&1; then
					printf "Created project directory %b%s%b\\n" "${cBGRE}" "${DIR}" "${cRESET}"
					[ "$DIR" == "/opt/etc/unbound" ] && chown nobody /opt/etc/unbound
				else
					printf "%b***ERROR creating directory %b%s%b. Exiting $(basename "$0")\\n" "$cBRED" "${cBGRE}" "${DIR}" "${cRESET}"
					exit 1
				fi
			fi
		done
}
make_backup() {
		DIR="$1"
		FILE="$2"
		TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
		BACKUP_FILE_NAME="${FILE}.${TIMESTAMP}"
		if [ -f "$DIR/$FILE" ]; then
			if ! mv "$DIR/$FILE" "$DIR/$BACKUP_FILE_NAME" >/dev/null 2>&1; then
				printf 'Error backing up existing %b%s%b to %b%s%b\n' "$cBGRE" "$FILE" "$cRESET" "$cBGRE" "$BACKUP_FILE_NAME" "$cRESET"
				printf 'Exiting %s\n' "$(basename "$0")"
				exit 1
			else
				printf 'Existing %b%s%b found\n' "$cBGRE" "$FILE" "$cRESET"
				printf '%b%s%b backed up to %b%s%b\n' "$cBGRE" "$FILE" "$cRESET" "$cBGRE" "$BACKUP_FILE_NAME" "$cRESET"
			fi
		fi
}
download_file() {

		DIR="$1"
		FILE="$2"
		case "$3" in											# v1.08
			martineau)
				GITHUB_DIR=$GITHUB_MARTINEAU
			;;
			rgnldo)
				GITHUB_DIR=$GITHUB_RGNLDO
			;;
		esac

		STATUS="$(curl --retry 3 -L${SILENT} -w '%{http_code}' "$GITHUB_DIR/$FILE" -o "$DIR/$FILE")"	# v1.08
		if [ "$STATUS" -eq "200" ]; then
			printf '\t%b%s%b downloaded successfully\n' "$cBGRE" "$FILE" "$cRESET"
		else
			printf '\n%b%s%b download failed with curl error %s\n\n' "\n\t\a$cBRED" "$FILE" "$cBRED" "$STATUS"
			printf 'Rerun %binstall_unbound.sh%b and select the %bRemove Existing unbound Installation%b option\n' "$cBGRE" "$cRESET" "$cBGRE" "$cRESET"
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
	#download_file /opt/etc/init.d S61unbound rgnldo

	{
	echo "#!/bin/sh
if [ \"\$1\" = \"start\" ] || [ \"\$1\" = \"restart\" ]; then
	   # Wait for NTP before starting
	   logger -st \"S61unbound\" \"Waiting for NTP to sync before starting...\"
	   ntptimer=0
	   while [ \"\$(nvram get ntp_ready)\" = \"0\" ] && [ \"\$ntptimer\" -lt \"300\" ]; do
			   ntptimer=\$((ntptimer+1))
			   sleep 1
	   done

	   if [ \"\$ntptimer\" -ge \"300\" ]; then
			   logger -st \"S61unbound\" \"NTP failed to sync after 5 minutes - please check immediately!\"
			   echo \"\"
			   exit 1
	   fi
fi

export TZ=\$(cat /etc/TZ)
ENABLED=yes
PROCS=unbound
ARGS=\"-c ${CONFIG_DIR}unbound.conf\"
PREARGS=\"nohup\"
PRECMD=\"\"
POSTCMD=\"service restart_dnsmasq\"
DESC=\$PROCS
PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func"; } > /opt/etc/init.d/S61unbound

	chmod 755 /opt/etc/init.d/S61unbound >/dev/null 2>&1
}
S02haveged_update() {

	echo -e $cBCYA"Updating S02haveged"$cGRA

	if [ -d "/opt/etc/init.d" ]; then
		/opt/bin/find /opt/etc/init.d -type f -name S02haveged* | while IFS= read -r "line"; do
			rm "$line"
		done
	fi
	#download_file /opt/etc/init.d S02haveged rgnldo

	{
	echo "#!/bin/sh
if [ \"\$1\" = \"start\" ] || [ \"\$1\" = \"restart\" ]; then
        # Wait for NTP before starting
        logger -st \"S02haveged\" \"Waiting for NTP to sync before starting...\"
        ntptimer=0
        while [ \"\$(nvram get ntp_ready)\" = \"0\" ] && [ \"\$ntptimer\" -lt \"300\" ]; do
                ntptimer=\$((ntptimer+1))
                sleep 1
        done

        if [ \"\$ntptimer\" -ge \"300\" ]; then
                logger -st \"S02haveged" "NTP failed to sync after 5 minutes - please check immediately!\"
                echo \"\"
                exit 1
        fi
fi
export TZ=\$(cat /etc/TZ)
ENABLED=yes
PROCS=haveged
ARGS=\"-w 1024 -d 32 -i 32 -v 1\"
PREARGS=\"\"
DESC=\$PROCS
PATH=/opt/sbin:/opt/bin:/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func"; } > /opt/etc/init.d/S02haveged

	chmod 755 /opt/etc/init.d/S02haveged >/dev/null 2>&1

	# if ! grep -qF "export TZ=\$(cat /etc/TZ)" /opt/etc/init.d/S02haveged; then
		# sed -i "3i export TZ=\$(cat /etc/TZ)" /opt/etc/init.d/S02haveged
	# fi

	/opt/etc/init.d/S02haveged restart
}
Redirect_outbound_DNS_requests() {

	iptables -t nat -D PREROUTING -d "$(nvram get lan_ipaddr)" -p tcp --dport 53 -j REDIRECT --to-port 53535 2>/dev/null
	iptables -t nat -D PREROUTING -d "$(nvram get lan_ipaddr)" -p udp --dport 53 -j REDIRECT --to-port 53535 2>/dev/null

	if [ "$1" != "del" ] ;then
		logger -t unbound "[*] Updating nat firewall rules to redirect ALL DNS requests"
		echo -e $cBCYA"\nUpdating nat firewall rules to redirect ALL DNS requests"$cRESET
		iptables -t nat -A PREROUTING -d "$(nvram get lan_ipaddr)" -p tcp --dport 53 -j REDIRECT --to-port 53535
		iptables -t nat -A PREROUTING -d "$(nvram get lan_ipaddr)" -p udp --dport 53 -j REDIRECT --to-port 53535

		if [ -z "$(grep -E "# unbound.*" /jffs/scripts/firewall-start | grep -v "^#")" ]; then
			echo -e $cBCYA"Updating 'firewall-start' to redirect ALL DNS requests to unbound"$cRESET
			[ ! -f /jffs/scripts/firewall-start ] && { echo "#!/bin/sh" > /jffs/scripts/firewall-start; chmod +x /jffs/scripts/firewall-start; }
			EXEC="sh /jffs/scripts/unbound_installer.sh firewall # unbound Firewall Addition"
			echo -e "$EXEC" >> /jffs/scripts/firewall-start
		else
			echo -e $cBGRE"'firewall-start' already contains unbound rule request to redirect ALL DNS requests"$cRESET
		fi
	else
		logger -t unbound "[*] Deleted unbound firewall rules."
		#echo -e $cBGRE"Deleted unbound firewall rules from 'firewall-start'"$cRESET
		sed -i '/# unbound Firewall Addition/d' /jffs/scripts/firewall-start
	fi
}
Option_Ad_Tracker_Blocker() {
		echo -e "\nDo you want to install Ad and Tracker blocking?\n\n\tReply$cBRED 'y' or press$cBGRE ENTER $cRESET to skip"
		read -r "ANS"
		[ "$ANS" == "y"  ] && Ad_Tracker_blocking		# v1.06 (Apparently requests '/opt/etc/init.d/S61unbound start')

		# ....but just in case ;-)
		[ -z "$(pidof unbound)" ] && /opt/etc/init.d/S61unbound start || /opt/etc/init.d/S61unbound restart	# Will also restart dnsmasq
}
Ad_Tracker_blocking() {

	echo -e $cBCYA"Installing Ads and Tracker Blocking....."$cRESET		# v1.06
	download_file ${CONFIG_DIR} unbound_adblock.tar.bz2 rgnldo			# v1.08
	echo -e $cBCYA"Unzipping 'unbound_adblock.tar.bz2'....."$cBGRA
	tar -jxvf ${CONFIG_DIR}unbound_adblock.tar.bz2 -C ${CONFIG_DIR}  	# v1.07

	# FFS! Make sure the downloaded script doesn't use '/jffs'
	if [ -n "$(grep -F "/jffs/" ${CONFIG_DIR}adblock/gen_adblock.sh)" ];then
		echo -e ${aBLINK}$cRED"Sanitising '/jffs/' references in ${CONFIG_DIR}adblock/gen_adblock.sh)...."${cRESET}$cBGRA
		sed -i "s~/jffs/~${CONFIG_DIR}~" ${CONFIG_DIR}adblock/gen_adblock.sh
	fi

	echo -e $cBCYA"Executing '${CONFIG_DIR}adblock/gen_adblock.sh'....."$cBGRA
	chmod +x ${CONFIG_DIR}adblock/gen_adblock.sh
	sh ${CONFIG_DIR}adblock/gen_adblock.sh				# Apparently requests '/opt/etc/init.d/S61unbound start'

	if [ -n "$(grep -E "# include:.*adblock/adservers" ${CONFIG_DIR}unbound.conf)" ];then				# v1.07
		echo -e $cBCYA"Adding Ad and Tracker 'include: ${CONFIG_DIR}adblock/adservers'"$cRESET
		sed -i "s~# include:.*adblock/adservers~include: ${CONFIG_DIR}adblock/adservers~" ${CONFIG_DIR}unbound.conf
	fi

	# Create cron job to refresh the Ads/Tracker lists			# v1.07
	echo -e $cBCYA"Creating Daily cron job for Ad and Tracker update"$cBGRA
	cru d adblock 2>/dev/null
	cru a adblock "0 5 * * *" ${CONFIG_DIR}adblock/gen_adblock.sh
	[ ! -f /jffs/scripts/services-start ] && { echo "#!/bin/sh" > /jffs/scripts/services-start; chmod +x /jffs/scripts/services-start; }
	if [ -z "$(grep -E "gen_adblock" /jffs/scripts/services-start | grep -v "^#")" ];then
		$(Smart_LineInsert "/jffs/scripts/services-start" "$(echo -e "cru a adblock \"0 5 * * *\" ${CONFIG_DIR}adblock/gen_adblock.sh\t\t\t# unbound")" )	# v1.10
	fi

	echo -e $cRESET
}
Option_Stubby_Integration() {
		echo -e "\nDo you want to integrate Stubby with unbound?\n\n\tReply$cBRED 'y' or press$cBGRE ENTER $cRESET to skip"
		read -r "ANS"
		[ "$ANS" == "y"  ] && Stubby_Integration
}
Stubby_Integration() {

	echo -e $cBCYA"Integrating Stubby with unbound....."$cBGRA
	opkg install stubby ca-bundle

	download_file /opt/etc/stubby/ stubby.yml rgnldo		# v1.08
	download_file /opt/etc/init.d S62stubby rgnldo			# v1.10
	chmod +x /opt/etc/init.d/S62stubby						# v1.10

	echo -e $cBCYA"Adding Stubby 'forward-zone:'"$cRESET
	if [ -n "$(grep -F "#forward-zone:" ${CONFIG_DIR}unbound.conf)" ];then
		sed -i '/forward\-zone:/,/forward\-first: yes/s/^#//' ${CONFIG_DIR}unbound.conf		# v1.04
	fi
	
	if [ "$(nvram get ipv6_service)" != "disabled" ];then						# v1.10
		echo -e $cBCYA"Customising Unbound IPv6 Stubby configuration....."$cRESET	
		# Options for integration with TCP/TLS Stubby
		#udp-upstream-without-downstream: yes
		sed -i '/udp\-upstream\-without\-downstream: yes/s/^#//g' ${CONFIG_DIR}unbound.conf
	fi
	
}
Customise_config() {

	 echo -e $cBCYA"Generating unbound-anchor 'root.key'....."$cBGRA			# v1.07
	 /opt/sbin/unbound-anchor -a ${CONFIG_DIR}root.key

	 echo -e $cBCYA"Retrieving 'root-hints' from 'https://www.internic.net/domain/named.cache'....."$cBGRA
	 curl -o ${CONFIG_DIR}root.hints https://www.internic.net/domain/named.cache
	 echo -en $cRESET

	 echo -e $cBCYA"Retrieving Custom Unbound configuration"$cBGRA
	 download_file $CONFIG_DIR unbound.conf rgnldo

	 # Entware creates a traditional '/opt/etc/unbound' directory structure so spoof it 		# v1.07
	 mv /opt/etc/unbound/unbound.conf /opt/etc/unbound/unbound.conf.Example
	 ln -s /opt/var/lib/unbound/unbound.conf /opt/etc/unbound/unbound.conf
	 
	 chown nobody /opt/var/lib/unbound											# v1.10
	 
	 echo -e $cBCYA"Checking IPv6....."$cRESET									# v1.10
	 if [ "$(nvram get ipv6_service)" != "disabled" ];then
		 echo -e $cBCYA"Customising Unbound IPv6 configuration....."$cRESET
		 # integration IPV6
		 # do-ip6: yes
		 # interface: ::0
		 # iaccess-control: ::0/0 refuse
		 # access-control: ::1 allow
		 # private-address: fd00::/8
		 # private-address: fe80::/10
		 sed -i '/do\-ip6: yes/,/private\-address: fe80::\/10/s/^#//g' ${CONFIG_DIR}unbound.conf	# v1.10
	 fi

	 echo -e $cBCYA"Customising Unbound configuration Options:"$cRESET

	 echo -e "\nDo you want to ENABLE unbound logging?\n\n\tReply$cBRED 'y'$cBGRE or press ENTER $cRESET to skip"
		read -r "ANS"
		[ "$ANS" == "y"  ] && Enable_Logging											# v1.07

	 echo -e "\nDo you want to optimise Performance/Memory parameters? (Advanced Users)\n\n\tReply$cBRED 'y'$cBGRE or press ENTER $cRESET to skip"
	 read -r "ANS"
	 [ "$ANS" == "youmustbeverystupid"  ] && Optimise_Performance_Memory
}
Optimise_Performance_Memory() {

	local FN="/jffs/scripts/dnsmasq.postconf"

     # https://github.com/MatthewVance/stubby-docker/blob/master/unbound/unbound.sh
     # Lookup IP of Stubby container as work around because forward-host did not
     # resolve stubby correctly and does not support @port syntax.
     # This uses ping rather than 'dig +short stubby' to avoid needing dnsutils
     # package
	if [ "$1" != "del" ];then

		echo -e $cBCYA"Customising Unbound Performance/Memory 'proc/sys/net' parameters and 'dnsmasq.postconf'"$cRESET			# v1.07

		local reserved=12582912
		local availableMemory=$(($availableMemory - $reserved))
		local msg_cache_size=$(($availableMemory / 3))
		local rr_cache_size=$(($availableMemory / 3))

		local stubby_ip=$(ping -4 -c 1 stubby | head -n 1 | cut -d ' ' -f 3 | cut -d '(' -f 2 | cut -d ')' -f 1)
		local stubby_port=@8053
		local stubby=$stubby_ip$stubby_port

		local nproc=$(nproc)
		[ $nproc -gt 1 ] && local threads=$((nproc - 1)) || thread=1       # v1.07

		sed -i \
			-e "s/msg\-cache\-size:.*/msg\-cache\-size: ${msg_cache_size}/" \
			-e "s/rrset\-cache\-size:.*/rrset\-cache\-size: ${rr_cache_size}/" \
			-e "s/num\-threads:.*/num\-threads: ${threads}/" \
			-e "s/@STUBBY@/${stubby}/" ${CONFIG_DIR}unbound.conf



		echo "4096    87380   8388608" > /proc/sys/net/ipv4/tcp_wmem
		echo "4096    87380   8388608" > /proc/sys/net/ipv4/tcp_rmem
		echo "8388608 8388608 8388608" > /proc/sys/net/ipv4/tcp_mem
		echo "8388608"                 > /proc/sys/net/core/rmem_max
		echo "8388608"                 > /proc/sys/net/core/wmem_max

		# Move to 'check_dnsmasq_postconf()' ? - nah! as the file MUST physically already exist by now!
		[ -z "$(grep -E "^echo.*tcp_wmem" $FN)" ] && echo -e "4096    87380   8388608 > /proc/sys/net/ipv4/tcp_wmemt\t# unbound_installer" >> $FN
		[ -z "$(grep -E "^echo.*tcp_rmem" $FN)" ] && echo -e "4096    87380   8388608 > /proc/sys/net/ipv4/tcp_rmemt\t# unbound_installer" >> $FN
		[ -z "$(grep -E "^echo.*tcp_mem"  $FN)" ] && echo -e "4096    87380   8388608 > /proc/sys/net/ipv4/tcp_wmemt\t# unbound_installer" >> $FN
		[ -z "$(grep -E "^echo.*rmem_max" $FN)" ] && echo -e "8388608 8388608 8388608 > /proc/sys/net/ipv4/tcp_memt\t# unbound_installer"  >> $FN
		[ -z "$(grep -E "^echo.*wmem_max" $FN)" ] && echo -e "8388608                 > /proc/sys/net/core/wmem_maxt\t# unbound_installer" >> $FN
	#else
		 #sed -i '/#.*unbound_installer/d' $FN	# Removal will be handled by 'check_dnsmasq_postconf()'
	fi
}
Enable_Logging() {															# v1.07

	 if [ -n "$(grep -F "# verbosity:" ${CONFIG_DIR}unbound.conf)" ];then
		sed -i '/# verbosity:/,/# log-replies: yes/s/^# //' ${CONFIG_DIR}unbound.conf

		echo -e $cBCYA"Unbound Logging enabled - $(grep -F 'verbosity:' ${CONFIG_DIR}unbound.conf)"$cRESET
	 fi

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
	echo -e $cBMAG"Use 'unbound-control stats_noreset' to monitor unbound performance"$cRESET
}
Query_unbound_control() {

	unbound-control -q status
	if [ "$?" != 0 ]; then
	  { echo -e $cBRED"\a***ERROR unbound not running!" 2>&1; return 1; }
	fi

	#[ -z "$" ] && { echo -e $cBRED"\a***ERROR unbound not installed!" 2>&1; return 1; }

	local RESET="_noreset"					# v1.08

	case $1 in
		s)
			#unbound-control stats$RESET | grep -v thread | grep -v histogram | grep -v time. | column
			unbound-control stats$RESET | grep -F "total." | column			# v1.08
		;;
		sa)
			unbound-control stats$RESET  | column
		;;
		qo|qo*)
			local CONFIG_VARIABLE
			if [ $(echo "$1" | wc -w ) -eq 1 ];then
				echo -e "\nEnter option name or press$cBGRE ENTER $cRESET to skip"
				read -r "CONFIG_VARIABLE"
			else
				CONFIG_VARIABLE=$(echo "$1" | sed 's/[^ ]* //')
			fi
			if [ "$CONFIG_VARIABLE" != ""  ];then
				local RESULT="$(unbound-control get_option $CONFIG_VARIABLE)"
				[ -z "(echo $RESULT | grep -i "error")" ] && echo -e $cRESET"unbound '$CONFIG_VARIABLE:' is '$RESULT'"  2>&1 || echo -e $cBRED"'$CONFIG_VARIABLE:' $RESULT" 2>&1
			fi
			echo -en $cRESET 2>&1
		;;
		sx|fs)
			unbound-control flush_stats
		;;
		q?)
			unbound-control
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
			# Create alias 'unbound_installer' for '/jffs/scripts/unbound_installer.sh'
			if [ -d "/opt/bin" ] && [ ! -L "/opt/bin/unbound_installer" ]; then
				echo -e $cBGRE"Creating 'unbound_installer' alias" 2>&1
				ln -s /jffs/scripts/unbound_installer.sh /opt/bin/unbound_installer    # v1.04
			fi
		#else
			# Remove Script alias - why?
			#echo -e $cBCYA"Removing 'unbound_installer' alias" 2>&1
			#rm -rf "/opt/bin/unbound_installer" 2>/dev/null
		#fi
}
Check_SWAP() {
	local SWAPSIZE=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
	[ $SWAPSIZE -gt 0 ] && { echo $SWAPSIZE; return 0;} || { echo $SWAPSIZE; return 1; }
}
update_installer() {

	if [ "$1" == "uf" ] || [ "$localmd5" != "$remotemd5" ]; then
		if [ "$ALLOWUPGRADE" == "Y" ];then										# v1.09
			echo
			download_file /jffs/scripts unbound_installer.sh martineau
			printf '\n%bUpdate Complete! %s\n' "$cBGRE" "$remotemd5"
		else
			echo -e $cRED_"\nupdate_installer() DISABLED pending Push request to Github\n"$cRESET
		fi
	else
		printf '\n%bunbound_installer.sh is already the latest version. %s\n' "$cBMAG" "$localmd5"
	fi
	echo -e $cRESET
}
remove_existing_installation() {

		echo -e $cBCYA"\nUninstalling unbound"$cRESET

		# Remove firewall rules
		echo -e $cBCYA"Removing firewall rules"$cRESET
		sed -i '/unbound_installer.sh/d' "/jffs/scripts/firewall-start" >/dev/null
		#Redirect_outbound_DNS_requests "del"								# v1.09

		# Kill unbound process
		pidof unbound | while read -r "spid" && [ -n "$spid" ]; do
			echo -e $cBCYA"KILLing unbound PID=$spid"$cBRED				# v1.07
			kill "$spid"
		done

		# Remove Ad and Tracker cron job /jffs/scripts/services-start	# v1.07
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
			if opkg remove $ENTWARE_UNBOUND; then echo -e $cBGRE"unbound Entware packages '$ENTWARE_UNBOUND' successfully installed"; else echo -e $cBRED"\a\t***Error occurred when removing unbound"$cRESET; fi
			#if opkg remove haveged; then echo "haveged successfully removed"; else echo "Error occurred when removing haveged"; fi
			#if opkg remove coreutils-nproc; then echo "coreutils-nproc successfully removed"; else echo "Error occurred when removing coreutils-nproc"; fi
		else
			echo -e $cRED"Unable to remove unbound - 'unbound' not installed?"$cRESET
		fi

		# Remove entries from /jffs/configs/dnsmasq.conf.add
		if [ -s "/jffs/configs/dnsmasq.conf.add" ]; then  # file exists
			for DNSMASQ_PARM in "^server=127\.0\.0\.1*#53535"; do
				if [ -n "$(grep -oE "$DNSMASQ_PARM" /jffs/configs/dnsmasq.conf.add)" ]; then  # see if line exists
					sed -i "\\~$DNSMASQ_PARM~d" "/jffs/configs/dnsmasq.conf.add"
				fi
			done
		fi

		service restart_dnsmasq >/dev/null 2>&1			# Just in case reboot is skipped!

		# Purge unbound directories
		#(NOTE: Entware installs to '/opt/etc/unbound' but some kn*b-h*d wants '/opt/var/lib/unbound'
		for DIR in "/opt/var/lib/unbound/adblock" "/opt/var/lib/unbound" "/opt/etc/unbound"; do		# v1.07
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
			/opt/bin/find /opt/etc/init.d -type f -name S61unbound\* -delete
		fi

		Check_dnsmasq_postconf "del"

		#Script_alias "delete"

		# Reboot router to complete uninstall of unbound
		echo -e $cBGRE"\n\tUninstall of unbound completed.\n"$cRESET

		echo -e "The router will now$cBRED REBOOT$cRESET to finalize the removal of unbound"
		echo -e "After the$cBRED REBOOT$cRESET, review the DNS settings on the WAN GUI and adjust if necessary"
		echo
		echo -e "Press$cBRED Y$cRESET to$cBRED REBOOT $cRESET or press$cBGRE ENTER to ABORT"
		read -r "CONFIRM_REBOOT"
		[ "$CONFIRM_REBOOT" == "Y" ] && { echo -e $cBRED"\a\n\n\tREBOOTing....."; service start_reboot; } || echo -e $cBGRE"\tReboot ABORTED\n"$cRESET
}
install_unbound() {

		echo -en $cBCYA"\nConfiguring unbound"$cRESET

		GITHUB_DIR="https://raw.githubusercontent.com/rgnldo/$GIT_REPO/master"

		if [ -d "/jffs/dnscrypt" ] || [ -f "/opt/sbin/dnscrypt-proxy" ]; then
			echo "Warning! DNSCrypt installation detected"
			printf 'Please remove this script to continue installing unbound\n\n'
			exit 1
		fi

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
		# ln -s ${CONFIG_DIR}unbound.conf /opt/var/lib/unbound/unbound.conf 2>/dev/null	# Hack to retain '/opt/etc/unbound' for configs

		Enable_unbound_statistics					# Install Entware opkg 'unbound-control'

		Install_Entware_opkg "haveged"
		Install_Entware_opkg "coreutils-nproc"
		Install_Entware_opkg "column"

		S02haveged_update

		check_dnsmasq_parms
		Check_dnsmasq_postconf

		create_required_directories

		S61unbound_update
		Customise_config
		#Redirect_outbound_DNS_requests						# v1.09 Removed v1.07

		Option_Stubby_Integration

		Option_Ad_Tracker_Blocker

		# unbound apparently has a habit of taking its time to fully process its 'unbound.conf' and may terminate due to invalid directives
		# e.g. fatal error: could not open autotrust file for writing, /root.key.22350-0-2a0796d0: Permission denied
		echo -e $cRESET"\nPlease wait for up to ${cBCYA}30$cRESET seconds for ${cBCYA}status.....\n"$cRESET
		WAIT=31		# 16 i.e. 15 secs should be adequate?
		INTERVAL=1
		I=0
		 while [ $I -lt $((WAIT-1)) ]
			do
				sleep 1
				I=$((I + 1))
				[ -z "$(pidof unbound)" ] && { echo -e $cBRED"\a\n\t***ERROR unbound went AWOL after $aREVERSE$I seconds${cRESET}$cBRED.....\n"$cRESET ; break; }
			done																			# v1.06

		if pidof unbound >/dev/null 2>&1; then
			echo -e $cBGRE"\n\tInstallation of unbound completed\n"		# v1.04
		else
			echo -e $cBRED"\a\n\t***ERROR Unsuccessful installation of unbound detected\n"		# v1.04
			echo -en ${cRESET}$cRED_
			grep unbound /tmp/syslog.log | tail -n 5			# v1.07
			unbound -d			# v1.06
			echo -e $cRESET"\n"
			printf '\tRerun %bunbound_installer.sh%b and select the %bRemove%b option to backout changes\n\n' "$cBGRE" "$cRESET" "$cBGRE" "$cRESET"
		fi

		echo -e $cBCYA"Checking Router Configuration pre-reqs....."	# v1.04
		# Check Swap file
		[ $(Check_SWAP) -eq 0 ] && echo -e $cBRED"[✖]Warning SWAP file is not configured $cRESET - use amtm to create one!" || echo -e $cBGRE"[✔] Swapfile="$(grep "SwapTotal" /proc/meminfo | awk '{print $2" "$3}')$cRESET	# v1.04

		#	DNSFilter: ON - mode Router
		if [ $(nvram get dnsfilter_enable_x) -eq 0 ];then
			echo -e $cBRED"\a[✖] ***ERROR DNS Filter is OFF! - $cRESET see http://$(nvram get lan_ipaddr)/DNSFilter.asp LAN->DNSFilter Enable DNS-based Filtering"
		else
			echo -e $cBGRE"[✔] DNS Filter=ON"
			#	DNSFilter: ON - Mode Router ?
			[ $(nvram get dnsfilter_mode) != "11" ] && echo -e $cBRED"\a[✖] ***ERROR DNS Filter is NOT = 'Router' $cRESET see http://$(nvram get lan_ipaddr)/DNSFilter.asp ->LAN->DNSFilter"$cRESET || echo -e $cBGRE"[✔] DNS Filter=ROUTER"
		fi

		#	Tools/Other WAN DNS local cache: NO # for the FW Merlin development team, it is desirable and safer by this mode.
		[ $(nvram get nvram get dns_local_cache) != "0" ] && echo -e $cBRED"\a[✖] ***ERROR WAN: Use local caching DNS server as system resolver=YES $cRESET see http://$(nvram get lan_ipaddr)/Tools_OtherSettings.asp ->Advanced Tweaks and Hacks"$cRESET || echo -e $cBGRE"[✔] WAN: Use local caching DNS server as system resolver=NO"

		#	Configure NTP server Merlin
		[ $(nvram get ntpd_enable) == "0" ] && echo -e $cBRED"\a[✖] ***ERROR Enable local NTP server=NO $cRESET see http://$(nvram get lan_ipaddr)/Advanced_System_Content.asp ->Basic Config"$cRESET || echo -e $cBGRE"[✔] Enable local NTP server=YES"

		exit_message
}
exit_message() {
		rm -rf /tmp/unbound.lock
		echo -e $cRESET
		exit 0
}
#=============================================Main=============================================================
# shellcheck disable=SC2068
Main() { true; } # Syntax that is Atom Shellchecker compatible!

clear
Check_Lock "$1"

Script_alias "create"				# v1.08

# [ "$1" == "firewall" ] && { Redirect_outbound_DNS_requests; exit 0; }		# v1.09 Removed - Called from firewall-start?

ANSIColours

welcome_message "$@"

echo -e $cRESET

rm -rf /tmp/unbound.lock

exit 0
