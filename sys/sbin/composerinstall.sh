#!/bin/bash
SDEBUG=${SDEBUG-}
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
SHELL_USER=${SHELL_USER-$(whoami)}
COMPOSER_JSON_CANDIDATES=${COMPOSER_JSON_CANDIDATES:-app/composer.json composer.json}
TOPDIR_CANDIDATES=${TOPDIR_CANDIDATES:-$SCRIPTSDIR/../.. $SCRIPTSDIR/../../../../ ../}
DISABLE_COMPOSER_TLS=${DISABLE_COMPOSER_TLS-1}

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

for i in \
    "$TOPDIR" "$TOPDIR/sbin" "$TOPDIR/sys" "$TOPDIR/sys/sbin" \
    "$SCRIPTSDIR" \
    ;do
    if [ -e $i/pre-composer.sh ]; then
        $i/pre-composer.sh
        break
    fi
done
(
    cd $PROJECT_DIR \
    && $GOSU_CMD /usr/local/bin/composer clear-cache \
    && if [[ -n "$DISABLE_COMPOSER_TLS" ]];then \
        echo "afwully disabling tls, seems CentOS+TLS is bad for https://codeload.github.com" \
        && $GOSU_CMD /usr/local/bin/composer config -g disable-tls true; \
    fi \
    && $GOSU_CMD sh -c 'COMPOSER_MEMORY_LIMIT=-1 php -d memory_limit=-1 \
        /usr/local/bin/composer install  --prefer-dist --optimize-autoloader --no-interaction --verbose $@'
)
