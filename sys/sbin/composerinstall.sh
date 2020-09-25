#!/bin/bash
SDEBUG=${SDEBUG-}
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
SHELL_USER=${SHELL_USER-}
cd "$SCRIPTSDIR/../.."
TOPDIR=$(pwd)

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

if [ -e $SCRIPTSDIR/pre-composer.sh ]; then
    $SCRIPTSDIR/pre-composer.sh
fi
(
    cd $PROJECT_DIR \
    && $GOSU_CMD /usr/local/bin/composer clear-cache \
    && $GOSU_CMD /usr/local/bin/composer install  --prefer-dist --optimize-autoloader --no-interaction --verbose $@
)
# in case you need it one day:
# && $GOSU_CMD sh -c 'COMPOSER_MEMORY_LIMIT=-1 php -d memory_limit=-1 /usr/local/bin/composer install --prefer-dist --optimize-autoloader --no-interaction --verbose $@'

