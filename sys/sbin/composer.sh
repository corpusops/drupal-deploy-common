#!/bin/bash
SDEBUG=${SDEBUG-}
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
SHELL_USER=${SHELL_USER-$(whoami)}
COMPOSER_JSON_CANDIDATES=${COMPOSER_JSON_CANDIDATES:-app/composer.json composer.json}
TOPDIR_CANDIDATES=${TOPDIR_CANDIDATES:-$SCRIPTSDIR/../.. $SCRIPTSDIR/../../../../ ../}

# detect root folder, either 4 levels under if called from common-glue
# or 2 from project root
TOPDIR=
for i in $TOPDIR_CANDIDATES;do
    for j in $COMPOSER_JSON_CANDIDATES;do
        if [ -e "$i/$j" ];then
            cd "$i"
            TOPDIR=$(pwd)
            break
        fi
    done
done
if [[ -z "$TOPDIR" ]];then
    echo "Can't detect project root level" >&2
    exit 1
fi

cd "$TOPDIR"
# now be in stop-on-error mode
set -e
# load locales & default env
# load this first as it resets $PATH
for i in /etc/environment /etc/default/locale;do
    if [ -e $i ];then . $i;fi
done

# activate shell debug if SDEBUG is set
if [[ -n $SDEBUG ]];then set -x;fi


PROJECT_DIR=$TOPDIR
if [ -e app ];then
    PROJECT_DIR=$TOPDIR/app
fi
export PROJECT_DIR

export APP_TYPE="${APP_TYPE:-drupal}"
export APP_USER="${APP_USER:-$APP_TYPE}"
export APP_GROUP="$APP_USER"

if [ "x${SHELL_USER}" = "x${APP_USER}" ]; then
    GOSU_CMD=""
else
    GOSU_CMD="gosu $APP_USER"
fi

for i in "$TOPDIR" "$TOPDIR/scripts" "$SCRIPTSDIR";do
    if [ -e $i/pre-composer.sh ]; then
        $i/pre-composer.sh
        break
    fi
done
(
    cd $PROJECT_DIR \
    && $GOSU_CMD /usr/local/bin/composer clear-cache \
    && $GOSU_CMD /usr/local/bin/composer --verbose $@
)
