#!/bin/sh
. "$(dirname $(readlink -f $0))/base"
hasdone=""
while :;do
    for i in $(printenv|grep -E "^${CERTBOT_ENV_VAR_PREFIX}"|sed 's;=.*;;'|sort);do
        hasdone=1
        domains="$( eval "echo \$$i" )"
        domain=$(echo "${domains}"|sed "s/,.*//g" )
        log "Handling: $i > $domains"
        if  [ "x$CERTBOT_RENEWAL" != "x" ];then
            for dconf in $CERTBOT_CONSTANTS_FILES;do if [ -e "$dconf" ];then
                log "--------------------"
                log "Patching $dconf with renewal: $CERTBOT_RENEWAL"
                sed -i -r \
                    -e "s/renew_before_expiry=[\"][^\"]+[\"]/renew_before_expiry=\"$CERTBOT_RENEWAL\"/g" \
                    $dconf
                # grep -E -C2 renew_before_expiry= $dconf >&2
                log "--------------------"
            fi;done
            dconf=/etc/letsencrypt/renewal/${domain}.conf
            if  [ -e $dconf ];then
                log "--------------------"
                log "Patching $dconf with renewal: $CERTBOT_RENEWAL"
                sed -i -r \
                    -e "/^renew_before_expiry/ d" \
                    -e "1 i\renew_before_expiry = $CERTBOT_RENEWAL" \
                    $dconf
                # grep -E -C2 ^renew_before_expiry $dconf >&2
                log "--------------------"
            fi
        fi
        if !( vv certbot $CERTBOT_ARGS --domains $domains ; );then
            log "Failed renewal: $i > $domains"
        fi
    done
    if [ "x$hasdone" = "x" ];then log "NO CNs were selected";fi
    sleep "$SLEEPTIME"
done
# vim:set et sts=4 ts=4 tw=0:
