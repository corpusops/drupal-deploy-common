#!/bin/sh
. "$(dirname $(readlink -f $0))/base"
#!/bin/sh
. "$(dirname $(readlink -f $0))/base"
if [ "x${SDEBUG-}" != "x" ];then set -x;fi
LIVEFOLDER=${LIVEFOLDER:-/etc/letsencrypt/live}
# for now nothing has to be done
exit 0
# vim:set et sts=4 ts=4 tw=0:
