#!/bin/sh
VER="1.01"
# Original script http://www.snbforums.com/threads/safesearchenforcement-with-unbound.68314/ by SNBForum member @SomeWhereOverTheRainBow

URL="https://www.google.com/supported_domains"
#file="/etc/unbound/unbound.conf.d/safesearch.conf" #this can be where-ever your unbound config storage is. You will have to use include: option inside the main unbound.conf though.
FN="/opt/share/unbound/configs/unbound.conf.safesearch" #this can be where-ever your unbound config storage is. You will have to use include: option inside the main unbound.conf though. # Martineau Hack
echo "server:" > "${FN}"
echo -e "\n# $(date)\n# Google Safe Search: "$URL >> "${FN}"    # Martineau Hack
DOMAINS=$(curl $URL 2>/dev/null)
for DOMAIN in $DOMAINS;do
    DOMAIN=$(echo $DOMAIN | cut -c 2-)
    printf 'local-zone: "%s" redirect \n' $DOMAIN >> "${FN}"
    printf 'local-data: "%s CNAME forcesafesearch.google.com" \n' $DOMAIN >> "${FN}"
    printf 'local-zone: "www.%s" redirect \n' $DOMAIN >> "${FN}"
    printf 'local-data: "www.%s CNAME forcesafesearch.google.com" \n' $DOMAIN >> "${FN}"
done
echo -e "\n# Youtube Safe Search:" >> "${FN}"                   # Martineau Hack
#for DOMAIN in youtube; do
    for PREFIX in youtube www.youtube m.youtube youtubei.googleapis youtube.googleapis youtube-nocookie www.youtube-nocookie;do  # Martineau Hac
        printf 'local-zone: "%s.com" redirect \n' $PREFIX >> "${FN}"
        printf 'local-data: "%s.com CNAME restrictmoderate.youtube.com" \n' $PREFIX >> "${FN}"
    done
#done
echo -e "\n# Yandex Safe Search: " >> "${FN}"                   # Martineau Hack
#for DOMAIN in yandex;do                                        # Martineau Hack
    for SUFFIX in com ru ua by kz;do
        printf 'local-zone: "yandex.%s" redirect \n' $SUFFIX >> "${FN}"
        printf 'local-data: "yandex.%s CNAME familysearch.yandex.%s" \n' $SUFFIX $SUFFIX >> "${FN}"
    done
#done
echo -e "\n# duckduckgo Safe Search:" >> "${FN}"                # Martineau Hack
#for DOMAIN in duckduckgo;do                                    # Martineau Hack
    for PREFIX in duckduckgo www.duckduckgo start.duckduckgo duck www.duck;do   # Martineau Hack
        printf 'local-zone: "%s.com" redirect \n' $PREFIX >> "${FN}"
        printf 'local-data: "%s.com CNAME safe.duckduckgo.com" \n' $PREFIX >> "${FN}"
    done
#done
echo -e "\n# Bing Safe Search:" >> "${FN}"                      # Martineau Hack
#for DOMAIN in bing;do                                          # Martineau Hack
    for PREFIX in bing www.bing;do  # Martineau Hac
        printf 'local-zone: "%s.com" redirect \n' $PREFIX >> "${FN}"
        printf 'local-data: "%s.com CNAME strict.bing.com" \n' $PREFIX >> "${FN}"
    done
#done
echo -e "\n# QWant Safe Api:" >> "${FN}"                      # Martineau Hack
#for DOMAIN in qwant;do
    for PREFIX in api.qwant.com;do
        printf 'local-zone: "%s" redirect \n' $PREFIX >> "${FN}"
        printf 'local-data: "%s CNAME safe%s" \n' $PREFIX $PREFIX >> "${FN}"
    done
#done
echo -e "\n# pixabay Safe Search:" >> "${FN}"                   # Martineau Hack
printf 'local-zone: "pixabay.com" redirect \n' >> "${FN}"
printf 'local-data: "pixabay.com CNAME safesearch.pixabay.com" \n' >> "${FN}"
