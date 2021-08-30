#!/bin/sh
. "$(dirname $(readlink -f $0))/base"
if [ "x${SDEBUG-}" != "x" ];then set -x;fi
LIVEFOLDER=${LIVEFOLDER:-/etc/letsencrypt/live}
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
# vim:set et sts=4 ts=4 tw=0:
