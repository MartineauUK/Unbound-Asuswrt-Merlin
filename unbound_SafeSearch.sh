#!/bin/sh

# http://www.snbforums.com/threads/safesearchenforcement-with-unbound.68314/

URL="https://www.google.com/supported_domains"
#file="/etc/unbound/unbound.conf.d/safesearch.conf" #this can be where-ever your unbound config storage is. You will have to use include: option inside the main unbound.conf though.
FN="/opt/share/unbound/configs/unbound.conf.safesearch" #this can be where-ever your unbound config storage is. You will have to use include: option inside the main unbound.conf though.
echo "server:" > "${FN}"
echo -e "\n# $(date)\n# Google Safe Search: "$URL >> "${FN}"						# EIC Hack
DOMAINS=$(curl $URL 2>/dev/null)
for DOMAIN in $DOMAINS; do
    DOMAIN=$(echo $DOMAIN | cut -c 2-)
    printf 'local-zone: "%s" redirect \n' $DOMAIN >> "${FN}"
    printf 'local-data: "%s CNAME forcesafesearch.google.com" \n' $DOMAIN >> "${FN}"
    printf 'local-zone: "www.%s" redirect \n' $DOMAIN >> "${FN}"
    printf 'local-data: "www.%s CNAME forcesafesearch.google.com" \n' $DOMAIN >> "${FN}"
done
echo -e "\n# Custom Safe Search:" >> "${FN}"						# EIC Hack
printf 'local-zone: "duckduckgo.com" redirect \n' >> "${FN}"
printf 'local-data: "duckduckgo.com CNAME safe.duckduckgo.com" \n' >> "${FN}"
printf 'local-zone: "www.duckduckgo.com" redirect \n' >> "${FN}"
printf 'local-data: "www.duckduckgo.com CNAME safe.duckduckgo.com" \n' >> "${FN}"
printf 'local-zone: "start.duckduckgo.com" redirect \n' >> "${FN}"
printf 'local-data: "start.duckduckgo.com CNAME safe.duckduckgo.com" \n' >> "${FN}"
printf 'local-zone: "duck.com" redirect \n' >> "${FN}"
printf 'local-data: "duck.com CNAME safe.duckduckgo.com" \n' >> "${FN}"
printf 'local-zone: "www.duck.com" redirect \n' >> "${FN}"
printf 'local-data: "www.duck.com CNAME safe.duckduckgo.com" \n' >> "${FN}"
printf 'local-zone: "bing.com" redirect \n' >> "${FN}"
printf 'local-data: "bing.com CNAME strict.bing.com" \n' >> "${FN}"
printf 'local-zone: "www.bing.com" redirect \n' >> "${FN}"
printf 'local-data: "www.bing.com CNAME strict.bing.com" \n' >> "${FN}"
printf 'local-zone: "pixabay.com" redirect \n' >> "${FN}"
printf 'local-data: "pixabay.com CNAME safesearch.pixabay.com" \n' >> "${FN}"
printf 'local-zone: "www.youtube.com" redirect \n' >> "${FN}"
printf 'local-data: "www.youtube.com CNAME restrictmoderate.youtube.com" \n' >> "${FN}"
printf 'local-zone: "m.youtube.com" redirect \n' >> "${FN}"
printf 'local-data: "m.youtube.com CNAME restrictmoderate.youtube.com" \n' >> "${FN}"
printf 'local-zone: "youtubei.googleapis.com" redirect \n' >> "${FN}"
printf 'local-data: "youtubei.googleapis.com CNAME restrictmoderate.youtube.com" \n' >> "${FN}"
printf 'local-zone: "youtube.googleapis.com" redirect \n' >> "${FN}"
printf 'local-data: "youtube.googleapis.com CNAME restrictmoderate.youtube.com" \n' >> "${FN}"
printf 'local-zone: "www.youtube-nocookie.com" redirect \n' >> "${FN}"
printf 'local-data: "www.youtube-nocookie.com CNAME restrictmoderate.youtube.com" \n' >> "${FN}"
printf 'local-zone: "yandex.com" redirect \n' >> "${FN}"
printf 'local-data: "yandex.com CNAME familysearch.yandex.ru" \n' >> "${FN}"
printf 'local-zone: "yandex.ru" redirect \n' >> "${FN}"
printf 'local-data: "yandex.ru CNAME familysearch.yandex.ru" \n' >> "${FN}"
printf 'local-zone: "yandex.ua" redirect \n' >> "${FN}"
printf 'local-data: "yandex.ua CNAME familysearch.yandex.ru" \n' >> "${FN}"
printf 'local-zone: "yandex.by" redirect \n' >> "${FN}"
printf 'local-data: "yandex.by CNAME familysearch.yandex.ru" \n' >> "${FN}"
printf 'local-zone: "yandex.kz" redirect \n' >> "${FN}"
printf 'local-data: "yandex.kz CNAME familysearch.yandex.ru" \n' >> "${FN}"
printf 'local-zone: "www.yandex.com" redirect \n' >> "${FN}"
printf 'local-data: "www.yandex.com CNAME familysearch.yandex.ru" \n' >> "${FN}"
printf 'local-zone: "www.yandex.ru" redirect \n' >> "${FN}"
printf 'local-data: "www.yandex.ru CNAME familysearch.yandex.ru" \n' >> "${FN}"
printf 'local-zone: "www.yandex.ua" redirect \n' >> "${FN}"
printf 'local-data: "www.yandex.ua CNAME familysearch.yandex.ru" \n' >> "${FN}"
printf 'local-zone: "www.yandex.by" redirect \n' >> "${FN}"
printf 'local-data: "www.yandex.by CNAME familysearch.yandex.ru" \n' >> "${FN}"
printf 'local-zone: "www.yandex.kz" redirect \n' >> "${FN}"
printf 'local-data: "www.yandex.kz CNAME familysearch.yandex.ru" \n' >> "${FN}"
