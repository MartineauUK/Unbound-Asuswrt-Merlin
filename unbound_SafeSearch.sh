#!/bin/sh
VER="1.03"
# Original script http://www.snbforums.com/threads/safesearchenforcement-with-unbound.68314/ by SNBForum member @SomeWhereOverTheRainBow

f_nslookup() {
    local DOMAIN="$1"
    nslookup ${DOMAIN} 1.1.1.1 2>/dev/null | awk '/^Address[[:space:]][0-9]*\:[[:space:]]/{if($3 ~ /((((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])\.){3}(25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])(\/(1?[0-9]|2?[0-9]|3?[0-2]))?)|(([0-9A-f]{0,4}:){1,7}[0-9A-f]{0,4}:{2}(\/(1?[0-2][0-8]|[0-9][0-9]))?))/ && !/1\.1\.1\.1/)print $3}' | while read -r line; do { if [ "${line%%.*}" = "0" ] || [ -z "${line%%::*}" ]; then continue; elif [ "${line##*:}" = "${line}" ]; then printf "%s " "$line"; else printf "%s " "$line"; fi; }; done
}                   # @Martineau Hack

URL="https://www.google.com/supported_domains"
#file="/etc/unbound/unbound.conf.d/safesearch.conf" #this can be where-ever your unbound config storage is. You will have to use include: option inside the main unbound.conf though.
FN="/opt/share/unbound/configs/unbound.conf.safesearch" #this can be where-ever your unbound config storage is. You will have to use include: option inside the main unbound.conf though. # Martineau Hack
echo "server:" > "${FN}"
{
echo -e "\n# $(date)\n# Google Safe Search: "$URL     # @Martineau Hack
DOMAINS=$(curl $URL 2>/dev/null)
for DOMAIN in $DOMAINS;do
    DOMAIN=$(echo $DOMAIN | cut -c 2-)
    #printf 'local-zone: "%s." transparent\n' $DOMAIN # v1.02 Disable so Android properly recieves push notifications @SomeWhereOverTheRainBow
    #printf 'local-data: "%s. CNAME forcesafesearch.google.com."\n' $DOMAIN # v1.02 Disable so Android properly recieves push notifications @SomeWhereOverTheRainBow
    printf 'local-zone: "www.%s." transparent\n' $DOMAIN
    printf 'local-data: "www.%s. CNAME forcesafesearch.google.com."\n' $DOMAIN
done
echo -e "\n# Youtube Safe Search:"
#for DOMAIN in youtube; do
    for PREFIX in www.youtube m.youtube youtubei.googleapis youtube.googleapis www.youtube-nocookie;do  # v1.02 @SomeWhereOverTheRainBow @Martineau Hack
        printf 'local-zone: "%s.com." transparent\n' $PREFIX
        printf 'local-data: "%s.com. CNAME restrictmoderate.youtube.com."\n' $PREFIX
    done
#done
echo -e "\n# Yandex Safe Search: "
#for DOMAIN in yandex;do                                        # @Martineau Hack
    for SUFFIX in com ru ua by kz;do
        printf 'local-zone: "yandex.%s." transparent\n' $SUFFIX
        printf 'local-data: "yandex.%s. CNAME familysearch.yandex.%s."\n' $SUFFIX $SUFFIX
    done
#done
echo -e "\n# duckduckgo Safe Search:"
#for DOMAIN in duckduckgo;do                                    # @Martineau Hack
    for PREFIX in duckduckgo www.duckduckgo start.duckduckgo duck www.duck;do   # Martineau Hack
        printf 'local-zone: "%s.com." transparent\n' $PREFIX
        printf 'local-data: "%s.com. CNAME safe.duckduckgo.com."\n' $PREFIX
    done
#done
echo -e "\n# Bing Safe Search:"
#for DOMAIN in bing;do                                          # @Martineau Hack
    for PREFIX in bing www.bing;do  # Martineau Hac
        printf 'local-zone: "%s.com." transparent\n' $PREFIX
        printf 'local-data: "%s.com. CNAME strict.bing.com."\n' $PREFIX
    done
#done
echo -e "\n# QWant Safe Api:"
#for DOMAIN in qwant;do
    for PREFIX in api.qwant.com;do
        printf 'local-zone: "%s." transparent\n' $PREFIX
        printf 'local-data: "%s. CNAME safe%s."\n' $PREFIX $PREFIX
    done
#done
echo -e "\n# pixabay Safe Search:"
printf 'local-zone: "pixabay.com." transparent\n'
printf 'local-data: "pixabay.com. CNAME safesearch.pixabay.com."\n'
for DOMAIN in forcesafesearch.google.com safe.duckduckgo.com restrictmoderate.youtube.com strict.bing.com safesearch.pixabay.com safeapi.qwant.com familysearch.yandex.ru; do
    for IPS in $(f_nslookup $DOMAIN); do
        if [ "$DOMAIN" = "forcesafesearch.google.com" ]; then
            if [ "${IPS##*:}" = "${IPS}" ]; then
                printf "%s\n" 'local-data: "'${DOMAIN}'. A '${IPS}'"'
                printf "%s\n" 'local-data: "'${DOMAIN}'. AAAA ::ffff:'${IPS}'"'
                printf "%s\n" 'local-data: "restrict.youtube.com. A '${IPS}'"'
                printf "%s\n" 'local-data: "restrict.youtube.com. AAAA ::ffff:'${IPS}'"'
            else
                printf "%s\n" 'local-data: "'${DOMAIN}'. AAAA '${IPS}'"'
                printf "%s\n" 'local-data: "restrict.youtube.com. AAAA '${IPS}'"'
            fi
        else
            if [ "${IPS##*:}" = "${IPS}" ]; then
                printf "%s\n" 'local-data: "'${DOMAIN}'. A '${IPS}'"'
                printf "%s\n" 'local-data: "'${DOMAIN}'. AAAA ::ffff:'${IPS}'"'
            else
                printf "%s\n" 'local-data: "'${DOMAIN}'. AAAA '${IPS}'"'
            fi
        fi
    done
done
} >> "${FN}"                   # @Martineau Hack
