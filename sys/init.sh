#!/bin/bash
# If you need more debug play with these variables:
# export NO_STARTUP_LOGS=
# export SHELL_DEBUG=1
# export DEBUG=1
# start by the first one, then try the others

SDEBUG=${SDEBUG-}
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
cd "$SCRIPTSDIR/.."
TOPDIR=$(pwd)

# now be in stop-on-error mode
set -e

# export back the gateway ip as a host if ip is available in container
if ( ip -4 route list match 0/0 &>/dev/null );then
    ip -4 route list match 0/0 \
        | awk '{print $3" host.docker.internal"}' >> /etc/hosts
fi

# load locales & default env
# load this first as it resets $PATH
for i in /etc/environment /etc/default/locale;do
    if [ -e $i ];then . $i;fi
done

# load virtualenv if any
for VENV in ./venv ../venv;do
    if [ -e $VENV ];then . $VENV/bin/activate;break;fi
done

# sourcing bash utilities
. "/code/init/sbin/base.sh"

PROJECT_DIR=$TOPDIR
if [ -e app ];then
    PROJECT_DIR=$TOPDIR/app
fi
if [ -e /code/app ]; then
    PROJECT_DIR=/code/app
fi
export PROJECT_DIR
# activate shell debug if SDEBUG is set
VDEBUG="${VDEBUG-}"
if [[ -n $SDEBUG ]];then set -x;VDEBUG="v";fi

DEFAULT_IMAGE_MODE=phpfpm

export IMAGE_MODE=${IMAGE_MODE:-${DEFAULT_IMAGE_MODE}}
IMAGE_MODES="(cron|nginx|fg|phpfpm|supervisor)"
NO_START=${NO_START-}
DEFAULT_NO_MIGRATE=
DEFAULT_NO_COMPOSER=
DEFAULT_NO_INSTALL=
DEFAULT_NO_STARTUP_LOGS=${NO_STARTUP_LOGS-}
DEFAULT_NO_COLLECT_STATIC=
if [[ -n $@ ]];then
    DEFAULT_NO_STARTUP_LOGS=1
    DEFAULT_NO_MIGRATE=1
    DEFAULT_NO_COLLECT_STATIC=1
fi
NO_STARTUP_LOGS=${NO_STARTUP_LOGS-${NO_MIGRATE-$DEFAULT_NO_STARTUP_LOGS}}
NO_MIGRATE=${NO_MIGRATE-$DEFAULT_NO_MIGRATE}
NO_COMPOSER=${NO_COMPOSER-$DEFAULT_NO_COMPOSER}
NO_INSTALL=${NO_INSTALL-$DEFAULT_NO_INSTALL}
NO_COLLECT_STATIC=${NO_COLLECT_STATIC-$DEFAULT_NO_COLLECT_STATIC}
NO_IMAGE_SETUP="${NO_IMAGE_SETUP:-"1"}"
FORCE_IMAGE_SETUP="${FORCE_IMAGE_SETUP:-"1"}"
SKIP_SERVICES_SETUP="${SKIP_SERVICES_SETUP-}"
IMAGE_SETUP_MODES="${IMAGE_SETUP_MODES:-"fg|phpfpm"}"
export FPM_LOGS_DIR="${FPM_LOGS_DIR:-/logs/phpfpm}"


FINDPERMS_PERMS_DIRS_CANDIDATES="${FINDPERMS_PERMS_DIRS_CANDIDATES:-"var/public var/private"}"
FINDPERMS_OWNERSHIP_DIRS_CANDIDATES="${FINDPERMS_OWNERSHIP_DIRS_CANDIDATES:-"var/public var/private"}"
export APP_TYPE="${APP_TYPE:-drupal}"
export APP_USER="${APP_USER:-$APP_TYPE}"
export APP_GROUP="${APP_GROUP:-$APP_USER}"
export PHP_GROUP="${PHP_GROUP:-apache}"
# directories created and set on user ownership at startup
export USER_DIRS=". public private $FPM_LOGS_DIR"
SHELL_USER=${SHELL_USER:-${APP_USER}}

# Drupal variables
export DRUPAL_LISTEN=${DRUPAL_LISTEN:-"0.0.0.0:8000"}
export PHP_MAX_WORKERS=${PHP_MAX_WORKERS:-50}
export PHP_MAX_SPARE_WORKERS=${PHP_MAX_SPARE_WORKERS:-35}
export PHP_MIN_SPARE_WORKERS=${PHP_MIN_SPARE_WORKERS:-5}
export PHP_DISPLAY_ERROR=${PHP_DISPLAY_ERROR:-0}
export PHP_XDEBUG_REMOTE=${PHP_XDEBUG_REMOTE:-0}
export PHP_XDEBUG_PROFILER_ENABLE_TRIGGER=${PHP_XDEBUG_PROFILER_ENABLE_TRIGGER:-1}
export PHP_XDEBUG_REMOTE_AUTOSTART=${PHP_XDEBUG_REMOTE_AUTOSTART:-0}
export PHP_XDEBUG_PORT=${PHP_XDEBUG_PORT:-9000}
export PHP_XDEBUG_IP=${PHP_XDEBUG_IP:-172.17.0.1}
export COOKIE_DOMAIN=${COOKIE_DOMAIN:-".local"}
export APP_ENV=${APP_ENV:-"prod"}
export DATABASE_URL=${DATABASE_URL:-"no value"}
export APP_SECRET=${APP_SECRET:-42424242424242424242424242}
export INIT_HOOKS_DIR="${INIT_HOOKS_DIR:-/code/sys/scripts/hooks}"
export DO_DRUPAL_SETTINGS_ENFORCEMENT=${DO_DRUPAL_SETTINGS_ENFORCEMENT-1}
export COMPOSER_NO_NO_DEV_ENVS="${COMPOSER_NO_NO_DEV_ENVS-"^dev|test$"}"
export SKIP_COMPOSER_INSTALL=${SKIP_COMPOSER_INSTALL-}
export DO_COMPOSER_INSTALL=${DO_COMPOSER_INSTALL-}
export SKIP_COMPOSER_HOOKS=${SKIP_COMPOSER_HOOKS-}
export COMPOSER_INSTALLED_FILE=${COMPOSER_INSTALLED_FILE:-${PROJECT_DIR}/.composerinstalled}
export COMPOSER_INSTALL_ARGS="${COMPOSER_INSTALL_ARGS-}"
export COMPOSER_NO_INTERACTION=${COMPOSER_NO_INTERACTION-1}


log() {
    echo "$@" >&2;
}

debuglog() {
    if [[ -n "$DEBUG" ]];then log "$@";fi
}

vv() {
    log "$@";"$@";
}

dvv() {
    debuglog "$@";"$@";
}


die() {
    log "$@";exit 1;
}

#  shell: Run interactive shell inside container
_shell() {
    local pre=""
    local user="$APP_USER"
    if [[ -n $1 ]];then user=$1;shift;fi
    local bargs="$@"
    local NO_VIRTUALENV=${NO_VIRTUALENV-}
    local NO_NVM=${NO_VIRTUALENV-}
    local NVMRC=${NVMRC:-.nvmrc}
    local NVM_PATH=${NVM_PATH:-..}
    local NVM_PATHS=${NVMS_PATH:-${NVM_PATH}}
    local VENV_NAME=${VENV_NAME:-venv}
    local VENV_PATHS=${VENV_PATHS:-./$VENV_NAME ../$VENV_NAME}
    local DOCKER_SHELL=${DOCKER_SHELL-}
    local pre="DOCKER_SHELL=\"$DOCKER_SHELL\";touch \$HOME/.control_bash_rc;
    if [ \"x\$DOCKER_SHELL\" = \"x\" ];then
        if ( bash --version >/dev/null 2>&1 );then \
            DOCKER_SHELL=\"bash\"; else DOCKER_SHELL=\"sh\";fi;
    fi"
    if [[ -z "$NO_NVM" ]];then
        if [[ -n "$pre" ]];then pre=" && $pre";fi
        pre="for i in $NVM_PATHS;do \
        if [ -e \$i/$NVMRC ] && ( nvm --help > /dev/null );then \
            printf \"\ncd \$i && nvm install \
            && nvm use && cd - >/dev/null 2>&1 && break\n\">>\$HOME/.control_bash_rc; \
        fi;done $pre"
    fi
    if [[ -z "$NO_VIRTUALENV" ]];then
        if [[ -n "$pre" ]];then pre=" && $pre";fi
        pre="for i in $VENV_PATHS;do \
        if [ -e \$i/bin/activate ];then \
            printf \"\n. \$i/bin/activate\n\">>\$HOME/.control_bash_rc && break;\
        fi;done $pre"
    fi
    if [[ -z "$bargs" ]];then
        bargs="$pre && if ( echo \"\$DOCKER_SHELL\" | grep -q bash );then \
            exec bash --init-file \$HOME/.control_bash_rc -i;\
            else . \$HOME/.control_bash_rc && exec sh -i;fi"
    else
        bargs="$pre && . \$HOME/.control_bash_rc && \$DOCKER_SHELL -c \"$bargs\""
    fi
    export TERM="$TERM"; export COLUMNS="$COLUMNS"; export LINES="$LINES"
    exec gosu $user sh $( if [[ -z "$bargs" ]];then echo "-i";fi ) -c "$bargs"
}

execute_hooks() {
    local step="$1"
    local hdir="$INIT_HOOKS_DIR/${step}"
    if [ ! -d "$hdir" ];then return 0;fi
    shift
    while read f;do
        if ( echo "$f" | egrep -q "\.sh$" );then
            debuglog "running shell hook($step): $f"
            . "${f}"
        else
            debuglog "running executable hook($step): $f"
            "$f" "$@"
        fi
    done < <(find "$hdir" -type f -executable 2>/dev/null | egrep -iv readme | sort -V; )
}


fix_settings_perms() {
    if [ -e /code/app/www/sites/default/settings.php ];then
        chown ${APP_USER}:${PHP_GROUP} "/code/app/www/sites/default/settings.php"
        chmod u+w "/code/app/www/sites/default/settings.php"
    fi
}

call_drush() {
    ( cd $PROJECT_DIR \
        && gosu $APP_USER bin/drush -y "$@" )
}


#  configure: generate configs from template at runtime
configure() {
    if [[ -n $NO_CONFIGURE ]];then return 0;fi
    for i in $USER_DIRS;do
        if [ ! -e "$i" ];then mkdir -p "$i" >&2;fi
        chown $APP_USER:$PHP_GROUP "$i"
    done
    if (find /etc/sudoers* -type f >/dev/null 2>&1);then chown -Rf root:root /etc/sudoers*;fi
    # copy only if not existing template configs from common deploy project
    # and only if we have that common deploy project inside the image
    # we first  create missing structure, but do not override yet (no clobber)
    # then override files if they have no pretendants in project customizations
    if [ ! -e init/etc ];then mkdir init/etc;fi
    for i in local/*deploy-common/etc local/*deploy-common/sys/etc;do
        if [ -d $i ];then
            cp -rfn${VDEBUG} $i/* init/etc
            while read conffile;do
                if [ ! -e sys/etc/$conffile ];then
                    cp -f${VDEBUG} $i/$conffile init/etc/$conffile
                fi
            done < <(cd $i && find -type f|sed -re "s/\.\///g")
        fi
    done
    cp -rf$VDEBUG sys/etc/. init/etc
    # install with frep any template file to / (eg: logrotate & cron file)
    cd init
    for i in $(find etc -name "*.frep" -type f |grep -v 'varnish' 2>/dev/null);do
        d="$(dirname "$i")/$(basename "$i" .frep)"
        di="/$(dirname $d)"
        if [ ! -e "$di" ];then mkdir -p${VDEBUG} "$di" >&2;fi
        debuglog "Generating with frep $i:/$d"
        frep "$i:/$d" --overwrite
    done
    cd - >/dev/null 2>&1
    # FPMPOOLS:
    #   - patch logsdirs
    #   - create pidfile folders
    while read fpmconf;do
        sed -i -r\
        -e "/^(slowlog|error_log|access\.log)/ d" \
        -e "/\[global\]/ aerror_log = $FPM_LOGS_DIR/fpm.error.log" \
        $fpmconf
    done < <(ls -1d /etc/php-fpm.conf /etc/php/*/fpm/php-fpm.conf 2>/dev/null|| true)
    while read fpmconf;do
        if (egrep -q "^pid\s*=" $fpmconf);then
            rpid=$(dirname $(egrep  "^pid\s*=" $fpmconf|head -n1|sed "s/.*=\s*//g"))
            if [ ! -e $rpid ];then mkdir -p $rpid;fi
        fi
    done < <(ls -1d /etc/php-fpm.conf           /etc/php-fpm.d/*.conf \
                    /etc/php/*/fpm/php-fpm.conf /etc/php/*/fpm/pool.d/*.conf \
                    2>/dev/null|| true)
    # support also debian based systems
    while read poold;do
        fpmd=$(dirname $poold)
        phpd=$(dirname $fpmd)
        rm -rf "$poold" && ln -sf /etc/php-fpm.d "$poold"
        bexts=""
        while read ext;do
            extn=$(basename $ext)
            extf=$(echo $extn | sed -re "s/[0-9]+-//g")
            bextn=$(basename $extf .ini)
            fextf=$phpd/mods-available/$extf
            if [ ! -e $fextf ];then die "missing php ext: $fextf";fi
            # remove any debian based conf as we override it with our custom priority numbers
            ( rm -f $phpd/mods-*/*${bextn}* $phpd/*/conf.d/*${bextn}* $phpd/*/mods-*/*${bextn}* >/dev/null 2>&1 || true )
            ln -sf $ext $fextf
            bexts="$bexts $bextn"
        done < <(find /etc/php.d -type f)
        [[ -n $bexts ]] && phpenmod -vALL -sALL $bexts
    done < <(ls -1d /etc/php*/*/*fpm*/pool.d 2>/dev/null||true)

    # regenerate app/.env file
    debuglog "regenerate /code/app/.env"
    frep "/code/app/.env.dist.frep:/code/app/.env" --overwrite
    chown ${APP_USER}:${PHP_GROUP} "/code/app/.env"
    # regenerate drupal app/www/sites/default/settings.php file
    chmod u+w "/code/app/www/sites/default"
    fix_settings_perms
    frep "/code/app/www/sites/default/settings.php.frep:/code/app/www/sites/default/settings.php" --overwrite
    fix_settings_perms


    # add shortcuts to some binaries on the project if they do not exists
    # and refresh them from project folders if found
    for shortcut in composerinstall.sh composer.sh base.sh;do
        for origdir in "${TOPDIR}"/sys/sbin "${TOPDIR}"/local/*deploy-common/sys/sbin;do
            if [ -e "${origdir}/${shortcut}" ];then
                cp -f${VDEBUG} "${origdir}/${shortcut}" "${TOPDIR}/init/sbin/${shortcut}"
            fi
        done
        if [[ "$shortcut" = "base.sh" ]];then
            shortcutlink=$shortcut
        else
            shortcutlink=$(basename $shortcut .sh)
        fi
        if [[ ! -L "$PROJECT_DIR/bin/${shortcutlink}" ]];then
            if [[ -f "$PROJECT_DIR/bin/${shortcutlink}" ]]; then
                rm -f "$PROJECT_DIR/bin/${shortcutlink}"
            fi
            ( cd $PROJECT_DIR/bin \
                && gosu $APP_USER ln -s "../../init/sbin/${shortcut}" "${shortcutlink}" )
        fi
    done

    # add shortcut from /code/app/www/sites/default/files to /code/app/var/public
    # do it before the sync for nginx
    check_public_files_symlink

    if [ -e /code/app/var/nginxwebroot ] && [[ -z ${NO_COLLECT_STATIC} ]]; then
        debuglog "Sync webroot for Nginx"
        # Sync the webroot to a shared volume with Nginx
        # but do not sync files which is already a shared Nginx volume
        # containing public long term contributions -- except we need the files directory link, just not the content --
        rsync -a --delete --exclude files/ /code/app/www/ /code/app/var/nginxwebroot/ \
            || die "sync webroot failed"
    fi
}

#  services_setup: when image run in daemon mode: pre start setup
#               like database migrations, etc
services_setup() {
    if [[ -z $NO_IMAGE_SETUP ]];then
        if [[ -n $FORCE_IMAGE_SETUP ]] || ( echo $IMAGE_MODE | egrep -q "$IMAGE_SETUP_MODES" ) ;then
            : "continue services_setup"
        else
            debuglog "No image setup"
            return 0
        fi
    else
        if [[ -n $SKIP_SERVICES_SETUP ]];then
            debuglog "Skip image setup"
            return 0
        fi
    fi
    # alpine linux has /etc/crontabs/ and ubuntu based vixie has /etc/cron.d/
    if [ -e /etc/cron.d ] && [ -e /etc/crontabs ];then cp -f$VDEBUG /etc/crontabs/* /etc/cron.d >&2;fi

    # composer install
    if [[ -z ${NO_COMPOSER} ]];then
        if [ -e /code/init/sbin/composerinstall.sh ]; then
            if [ ! -e ${COMPOSER_INSTALLED_FILE} ];then
                DO_COMPOSER_INSTALL=1
            else
                debuglog "composer install already ran (${COMPOSER_INSTALLED_FILE})"
            fi
            if ! ( echo "${DRUPAL_ENV_NAME}" | grep -Eq "${COMPOSER_NO_NO_DEV_ENVS}" );then
                if ( echo ${COMPOSER_INSTALL_ARGS} | grep -vq -- --no-dev );then
                    COMPOSER_INSTALL_ARGS="${COMPOSER_INSTALL_ARGS-} --no-dev"
                fi
            fi
            if [[ -n "${DO_COMPOSER_INSTALL}" ]] ;then
                dvv /code/init/sbin/composerinstall.sh ${COMPOSER_INSTALL_ARGS} && touch "${COMPOSER_INSTALLED_FILE}"
            else
                debuglog "Skipping composer install"
            fi
            if [[ -z "${SKIP_COMPOSER_HOOKS-}" ]];then
                dvv /code/init/sbin/composer.sh run-script pre-install-cmd
                dvv /code/init/sbin/composer.sh run-script post-install-cmd
            fi
        fi
    fi

    # Run install ?
    if [[ -z ${NO_INSTALL} ]];then
        ( cd $PROJECT_DIR && gosu $APP_USER bin/install.sh )
    fi

    # Run any migration
    if [[ -z ${NO_MIGRATE} ]];then
        call_drush updb
    fi
}

fixperms() {
    if [[ -n $NO_FIXPERMS ]];then return 0;fi
    for i in /etc/{crontabs,cron.d} /etc/logrotate.d /etc/supervisor.d;do
        if [ -e $i ];then
            while read f;do
                chown -R root:root "$f"
                chmod 0640 "$f"
            done < <(find "$i" -type f)
        fi
    done
    while read f;do chmod 0755 "$f";done < \
        <(find $FINDPERMS_PERMS_DIRS_CANDIDATES -type d \
          -not \( -perm 0755 2>/dev/null\) |sort)
    while read f;do chmod 0644 "$f";done < \
        <(find $FINDPERMS_PERMS_DIRS_CANDIDATES -type f \
          -not \( -perm 0644 2>/dev/null\) |sort)
    while read f;do chown $APP_USER:$APP_USER "$f";done < \
        <(find $FINDPERMS_OWNERSHIP_DIRS_CANDIDATES \
          \( -type d -or -type f \) \
             -and -not \( -user $APP_USER -and -group $PHP_GROUP \)  2>/dev/null|sort)
}

#  usage: print this help
usage() {
    drun="docker run --rm -it <img>"
    echo "EX:
$drun [-e NO_COLLECT_STATIC=1] [-e NO_MIGRATE=1] [-e NO_COMPOSER=1]  [-e NO_INSTALL=1] [ -e FORCE_IMAGE_SETUP] [-e IMAGE_MODE=\$mode]
    docker run <img>
        run either fg, nginx, cron, supervisor or phpfpm daemon
        (IMAGE_MODE: $IMAGE_MODES)

$drun \$args: run commands with the context ignited inside the container
$drun [ -e FORCE_IMAGE_SETUP=1] [ -e NO_IMAGE_SETUP=1] [-e SHELL_USER=\$ANOTHERUSER] [-e IMAGE_MODE=\$mode] [\$command[ \args]]
    docker run <img> \$COMMAND \$ARGS -> run command
    docker run <img> shell -> interactive shell
(default user: $SHELL_USER)
(default mode: $IMAGE_MODE)

If FORCE_IMAGE_SETUP is set: run migration
If NO_IMAGE_SETUP is set: migration is skipped, no matter what
If NO_START is set: start an infinite loop doing nothing (for dummy containers in dev)
If NO_INSTALL is set: no attempt at installing Drupal via drush install will be made
"
  exit 0
}

do_fg() {
    # FIXME: not sure at all, needs tests. But currently not used
    ( cd $PROJECT_DIR \
        && exec gosu $APP_USER php app/www/core/scripts/drupal quick-start $DRUPAL_LISTEN )
}

do_phpfpm() { ( php-fpm -F -R ) }

if ( echo $1 | egrep -q -- "--help|-h|help" );then
    usage
fi

if [[ -n ${NO_START-} ]];then
    while true;do echo "start skipped" >&2;sleep 65535;done
    exit $?
fi

# Run app
pre() {
    configure
    execute_hooks afterconfigure "$@"
    services_setup
    execute_hooks afterservicessetup "$@"
    fixperms
    execute_hooks afterfixperms "$@"
}

execute_hooks pre "$@"
# only display startup logs when we start in daemon mode
# and try to hide most when starting an (eventually interactive) shell.
if ! ( echo "$NO_STARTUP_LOGS" | egrep -iq "^(no?)?$" );then pre 2>/dev/null;else pre;fi
execute_hooks post "$@"

if [[ -z "$@" ]]; then
    if ! ( echo $IMAGE_MODE | egrep -q "$IMAGE_MODES" );then
        debuglog "Unknown image mode ($IMAGE_MODES): $IMAGE_MODE"
        exit 1
    fi
    debuglog "Running in $IMAGE_MODE mode"
    if [[ "$IMAGE_MODE" = "fg" ]]; then
        do_fg
    else
        cfg="/etc/supervisor.d/$IMAGE_MODE"
        if [ ! -e $cfg ];then
            log "Missing: $cfg"
            exit 1
        fi
        SUPERVISORD_CONFIGS="rsyslog $cfg" exec /bin/supervisord.sh
    fi
else
    if [[ "${1-}" = "shell" ]];then shift;fi
    execute_hooks beforeshell "$@"
    ( cd $PROJECT_DIR && _shell $SHELL_USER "$@" )
fi
