#!/bin/sh
. "$(dirname $(readlink -f $0))/base"
if [ "x${SDEBUG-}" != "x" ];then set -x;fi
LIVEFOLDER=${LIVEFOLDER:-/etc/letsencrypt/live}
# transform certs in haproxy format
for f in $(find -L $LIVEFOLDER -name fullchain.pem 2>/dev/null );do
    d=$(dirname $f)
    c=$(basename $d)
    n=$c.crt
    if [ -f $d/fullchain.pem -a -f $d/privkey.pem ]; then
        cat $d/fullchain.pem $d/privkey.pem > $d/full.pem
        if !( diff -q $d/full.pem /certificates/$n 2>&1 >/dev/null );then
            cp $d/full.pem /certificates/$n
        fi
    fi
done
# reload haproxy conf
for f in $(find -L /certificates -name "*.crt" -type f -not -name self.crt 2>/dev/null );do
    log "handling $f"
    echo "new ssl cert $f" \
        | nc $HAPROXY_INT_IP $HAPROXY_CPORT
    echo -e -n "set ssl cert $f <<\n$(cat $f)\n\n" \
        | nc $HAPROXY_INT_IP $HAPROXY_CPORT
    echo "commit ssl cert $f" \
        | nc $HAPROXY_INT_IP $HAPROXY_CPORT
    echo "show ssl cert $f" \
        | nc $HAPROXY_INT_IP $HAPROXY_CPORT |egrep -i "^(subject|not|filename)"
done
# vim:set et sts=4 ts=4 tw=0:
