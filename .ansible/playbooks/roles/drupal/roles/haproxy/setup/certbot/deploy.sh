#!/bin/sh
. "$(dirname $(readlink -f $0))/base"
#!/bin/sh
. "$(dirname $(readlink -f $0))/base"
if [ "x${SDEBUG-}" != "x" ];then set -x;fi
LIVEFOLDER=${LIVEFOLDER:-/etc/letsencrypt/live}
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
