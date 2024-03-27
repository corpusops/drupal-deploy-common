#!/bin/bash
# If you need more debug play with these variables:
# export NO_STARTUP_LOGS=
# export SHELL_DEBUG=1
# export DEBUG=1
# start by the first one, then try the others

SDEBUG=${SDEBUG-}
DEBUG=${DEBUG:-${SDEBUG-}}
# activate shell debug if SDEBUG is set
VCOMMAND=""
DASHVCOMMAND=""
if [[ -n $SDEBUG ]];then set -x; VCOMMAND="v"; DASHVCOMMAND="-v";fi
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
ODIR=$(pwd)
cd "${TOPDIR:-$SCRIPTSDIR/..}"
TOPDIR="$(pwd)"
BASE_DIR="${BASE_DIR:-${TOPDIR}}"

# now be in stop-on-error mode
set -e

# export back the gateway ip as a host if ip is available in container
if ( ip -4 route list match 0/0 &>/dev/null );then
    ip -4 route list match 0/0 | awk '{print $3" host.docker.internal"}' >> /etc/hosts
fi

# load locales & default env while preserving original $PATH
export OPATH=$PATH
for i in /etc/environment /etc/default/locale;do if [ -e $i ];then . $i;fi;done
export PATH=$OPATH

# load virtualenv if present
for VENV in "$BASE_DIR/venv" "$BASE_DIR";do if [ -e "$VENV/bin/activate" ];then export VENV;. "$VENV/bin/activate";break;fi;done

SRC_DIR="${SRC_DIR-}"
SRC_DIR_NAME=app
if [[ -z "${SRC_DIR}" ]];then
    if [ -e "${TOPDIR}/${SRC_DIR_NAME}" ];then SRC_DIR="$TOPDIR/${SRC_DIR_NAME}";fi
fi
export ROOTPATH=$SRC_DIR

# sourcing bash utilities
. "$BASE_DIR/init/sbin/base.sh"

DEFAULT_IMAGE_MODE="phpfpm"

export IMAGE_MODE=${IMAGE_MODE:-${DEFAULT_IMAGE_MODE}}
SKIP_STARTUP_DB=${SKIP_STARTUP_DB-}
SKIP_SYNC_DOCS=${SKIP_SYNC_DOCS-}
IMAGE_MODES="(cron|nginx|fg|phpfpm|supervisor)"
IMAGE_MODES_MIGRATE="(fg|phpfpm)"
NO_START=${NO_START-}
DRUPAL_CONF_PREFIX="${DRUPAL_CONF_PREFIX:-"DRUPAL__"}"
DEFAULT_NO_MIGRATE=1
DEFAULT_NO_COMPOSER=
DEFAULT_NO_INSTALL=
DEFAULT_NO_STARTUP_LOGS=
DEFAULT_NO_COLLECT_STATIC=
if ( echo $IMAGE_MODE|grep -E -iq "$IMAGE_MODES_MIGRATE" );then
    DEFAULT_NO_MIGRATE=
fi
if [[ -n $@ ]];then
    IMAGE_MODE=shell
    DEFAULT_NO_MIGRATE=1
    DEFAULT_NO_COLLECT_STATIC=1
    DEFAULT_NO_STARTUP_LOGS=1
fi
NO_MIGRATE=${NO_MIGRATE-$DEFAULT_NO_MIGRATE}
NO_STARTUP_LOGS=${NO_STARTUP_LOGS-$DEFAULT_NO_STARTUP_LOGS}
NO_COMPOSER=${NO_COMPOSER-$DEFAULT_NO_COMPOSER}
NO_INSTALL=${NO_INSTALL-$DEFAULT_NO_INSTALL}
NO_COLLECT_STATIC=${NO_COLLECT_STATIC-$DEFAULT_NO_COLLECT_STATIC}
NO_IMAGE_SETUP="${NO_IMAGE_SETUP:-"1"}"
SKIP_IMAGE_SETUP="${KIP_IMAGE_SETUP:-""}"
FORCE_IMAGE_SETUP="${FORCE_IMAGE_SETUP:-"1"}"
SKIP_SERVICES_SETUP="${SKIP_SERVICES_SETUP-}"
IMAGE_SETUP_MODES="${IMAGE_SETUP_MODES:-"fg|phpfpm"}"
export CRON_LOGS_DIR="${CRON_LOGS_DIR:-$SRC_DIR/var/private/logs}"
export FPM_LOGS_DIR="${FPM_LOGS_DIR:-$SRC_DIR/var/private/logs}"
export FPM_LOG_FILE="${FPM_LOG_FILE:-/proc/self/fd/2}"
export LOCAL_DIR="${LOCAL_DIR:-/local}"

# log to stdout which in turn should log to docker logger, do not store local logs
export RSYSLOG_LOGFORMAT="${RSYSLOG_LOGFORMAT:-'%timegenerated% %syslogtag% %msg%\\n'}"
export RSYSLOG_OUT_LOGFILE="${RSYSLOG_OUT_LOGFILE:-n}"
export RSYSLOG_REPEATED_MSG_REDUCTION="${RSYSLOG_REPEATED_MSG_REDUCTION:-off}"

FINDPERMS_PERMS_DIRS_CANDIDATES="${FINDPERMS_PERMS_DIRS_CANDIDATES:-"var/public var/private var/docs"}"
FINDPERMS_OWNERSHIP_DIRS_CANDIDATES="${FINDPERMS_OWNERSHIP_DIRS_CANDIDATES:-"var/public var/private var/docs"}"
SKIP_RENDERED_CONFIGS="${SKIP_RENDERED_CONFIGS:-varnish}"
export HISTFILE="${LOCAL_DIR}/.bash_history"
export PSQL_HISTORY="${LOCAL_DIR}/.psql_history"
export MYSQL_HISTFILE="${LOCAL_DIR}/.mysql_history"
export IPYTHONDIR="${LOCAL_DIR}/.ipython"

export APP_TYPE="${APP_TYPE:-drupal}"
export TMPDIR="${TMPDIR:-/tmp}"
export STARTUP_LOG="${STARTUP_LOG:-$TMPDIR/${APP_TYPE}_startup.log}"
export APP_USER="${APP_USER:-$APP_TYPE}"
export HOST_USER_UID="${HOST_USER_UID:-$(id -u $APP_USER)}"
export INIT_HOOKS_DIR="${INIT_HOOKS_DIR:-${BASE_DIR}/sys/scripts/hooks}"
export APP_GROUP="${APP_GROUP:-$APP_USER}"
export PHP_GROUP="${PHP_GROUP:-apache}"
export APP_ENV=${APP_ENV:-"prod"}
export APP_SECRET=${APP_SECRET:-42424242424242424242424242}
# directories created and set on user ownership at startup
export EXTRA_USER_DIRS="${EXTRA_USER_DIRS-}"
export USER_DIRS="${USER_DIRS:-". app/public app/private $FPM_LOGS_DIR $CRON_LOGS_DIR ${EXTRA_USER_DIRS}"}"
export SHELL_USER="${SHELL_USER:-${APP_USER}}" SHELL_EXECUTABLE="${SHELL_EXECUTABLE:-/bin/bash}"

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
export DATABASE_URL=${DATABASE_URL:-"no value"}
export DO_DRUPAL_SETTINGS_ENFORCEMENT=${DO_DRUPAL_SETTINGS_ENFORCEMENT-1}
export COMPOSER_NO_NO_DEV_ENVS="${COMPOSER_NO_NO_DEV_ENVS-"^dev|test$"}"
export SKIP_COMPOSER_INSTALL=${SKIP_COMPOSER_INSTALL-}
export DO_COMPOSER_INSTALL=${DO_COMPOSER_INSTALL-}
export SKIP_COMPOSER_HOOKS=${SKIP_COMPOSER_HOOKS-}
export COMPOSER_INSTALLED_FILE=${COMPOSER_INSTALLED_FILE:-${SRC_DIR}/.composerinstalled}
export COMPOSER_INSTALL_ARGS="${COMPOSER_INSTALL_ARGS-}"
export COMPOSER_NO_INTERACTION=${COMPOSER_NO_INTERACTION-1}


# forward console integration
export TERM="${TERM-}" COLUMNS="${COLUMNS-}" LINES="${LINES-}"

debuglog() { if [[ -n "$DEBUG" ]];then echo "$@" >&2;fi }
log() { echo "$@" >&2; }
die() { log "$@";exit 1; }
vv() { log "$@";"$@"; }
dvv() { debuglog "$@";"$@"; }


#  shell: Run interactive shell inside container
_shell() {
    exec gosu ${user:-$APP_USER} $SHELL_EXECUTABLE -$([[ -n ${SSDEBUG:-$SDEBUG} ]] && echo "x" )elc "${@:-${SHELL_EXECUTABLE}}"
}


fix_settings_perms() {
    if [ -e $SRC_DIR/www/sites/default/settings.php ];then
        chown ${APP_USER}:${PHP_GROUP} "$SRC_DIR/www/sites/default/settings.php"
        chmod u+w "$SRC_DIR/www/sites/default/settings.php"
    fi
}

call_drush() { ( cd $SRC_DIR && gosu $APP_USER bin/drush -y "$@" ); }

#  configure: generate configs from template at runtime
configure() {
    if [[ -n $NO_CONFIGURE ]];then return 0;fi
    for i in $USER_DIRS;do
        if [ ! -e "$i" ];then mkdir -p "$i" >&2;fi
        chown $APP_USER:$PHP_GROUP "$i"
    done
    for i in $HISTFILE $MYSQL_HISTFILE $PSQL_HISTORY;do if [ ! -e "$i" ];then touch "$i";fi;done
    for i in $IPYTHONDIR;do if [ ! -e "$i" ];then mkdir -pv "$i";fi;done
    for i in $HISTFILE $MYSQL_HISTFILE $PSQL_HISTORY $IPYTHONDIR;do chown -Rf $APP_USER "$i";done
    if (find /etc/sudoers* -type f >/dev/null 2>&1);then chown -Rf root:root /etc/sudoers*;fi
    # copy only if not existing template configs from common deploy project
    # and only if we have that common deploy project inside the image
    # we first  create missing structure, but do not override yet (no clobber)
    # then override files if they have no pretendants in project customizations
    if [ ! -e init/etc ];then mkdir -pv init/etc;fi
    for i in local/*deploy-common/etc local/*deploy-common/sys/etc;do
        if [ -d $i ];then
            cp -rf${VCOMMAND} $i/. init/etc
            while read conffile;do
                if [ ! -e sys/etc/$conffile ];then
                    cp -f${VCOMMAND} $i/$conffile init/etc/$conffile
                fi
            done < <(cd $i && find -type f|sed -re "s/\.\///g")
        fi
    done
    cp -rf$VCOMMAND sys/etc/. init/etc
    # install with frep any template file to / (eg: logrotate & cron file)
    cd init
    for i in $(find etc -name "*.frep" -type f |grep -E -v "${SKIP_RENDERED_CONFIGS}" 2>/dev/null);do
        d="$(dirname "$i")/$(basename "$i" .frep)"
        di="/$(dirname $d)"
        if [ ! -e "$di" ];then mkdir -p${VCOMMAND} "$di" >&2;fi
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
        -e "/\[global\]/ aerror_log = $FPM_LOG_FILE" \
        $fpmconf
    done < <(ls -1d /etc/php-fpm.conf /etc/php/*/fpm/php-fpm.conf 2>/dev/null|| true)
    while read fpmconf;do
        if (grep -E -q "^pid\s*=" $fpmconf);then
            rpid=$(dirname $(grep -E  "^pid\s*=" $fpmconf|head -n1|sed "s/.*=\s*//g"))
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
    debuglog "regenerate $SRC_DIR/.env"
    frep "$SRC_DIR/.env.dist.frep:$SRC_DIR/.env" --overwrite
    chown ${APP_USER}:${PHP_GROUP} "$SRC_DIR/.env"

    # regenerate drupal app/www/sites/default/settings.php file
    chmod u+w "$SRC_DIR/www/sites/default"
    fix_settings_perms
    frep "$SRC_DIR/www/sites/default/settings.php.frep:$SRC_DIR/www/sites/default/settings.php" --overwrite
    fix_settings_perms

    # add shortcuts to some binaries on the project if they do not exists
    # and refresh them from project folders if found
    for shortcut in composerinstall.sh composer.sh base.sh;do
        for origdir in "${TOPDIR}"/sys/sbin "${TOPDIR}"/local/*deploy-common/sys/sbin;do
            if [ -e "${origdir}/${shortcut}" ];then
                cp -f${VCOMMAND} "${origdir}/${shortcut}" "${TOPDIR}/init/sbin/${shortcut}"
            fi
        done
        if [[ "$shortcut" = "base.sh" ]];then
            shortcutlink=$shortcut
        else
            shortcutlink=$(basename $shortcut .sh)
        fi
        if [[ ! -L "$SRC_DIR/bin/${shortcutlink}" ]];then
            if [[ -f "$SRC_DIR/bin/${shortcutlink}" ]]; then
                rm -f "$SRC_DIR/bin/${shortcutlink}"
            fi
            ( cd $SRC_DIR/bin \
                && gosu $APP_USER ln -s "../../init/sbin/${shortcut}" "${shortcutlink}" )
        fi
    done

    # add shortcut from /$SRC_DIRwww/sites/default/files to /code/app/var/public
    # do it before the sync for nginx
    check_public_files_symlink

    if [ -e $SRC_DIR/var/nginxwebroot ] && [[ -z ${NO_COLLECT_STATIC} ]]; then
        debuglog "Sync webroot for Nginx"
        # Sync the webroot to a shared volume with Nginx
        # but do not sync files which is already a shared Nginx volume
        # containing public long term contributions -- except we need the files directory link, just not the content --
        rsync -a --delete --exclude files/ $SRC_DIR/www/ $SRC_DIR/var/nginxwebroot/ \
            || die "sync webroot failed"
    fi
}

#  services_setup: when image run in daemon mode: pre start setup like database migrations, etc
services_setup() {
    if [[ -z $NO_IMAGE_SETUP ]];then
        if [[ -n $FORCE_IMAGE_SETUP ]] || ( echo $IMAGE_MODE | grep -E -q "$IMAGE_SETUP_MODES" ) ;then
            debuglog "Force services_setup"
        else
            debuglog "No image setup" && return 0
        fi
    else
        if [[ -n $SKIP_SERVICES_SETUP ]];then
            debuglog "Skip image setup"
            return 0
        fi
    fi
    if [[ "$SKIP_IMAGE_SETUP" = "1" ]];then
        debuglog "Skip image setup" && return 0
    fi
    debuglog "doing services_setup"
    # alpine linux has /etc/crontabs/ and ubuntu based vixie has /etc/cron.d/
    if [ -e /etc/cron.d ] && [ -e /etc/crontabs ];then cp -f$VCOMMAND /etc/crontabs/* /etc/cron.d >&2;fi

    # composer install
    if [[ -z ${NO_COMPOSER} ]];then
        if [ -e $BASE_DIR/init/sbin/composerinstall.sh ]; then
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
                dvv $BASE_DIR/init/sbin/composerinstall.sh ${COMPOSER_INSTALL_ARGS} && touch "${COMPOSER_INSTALLED_FILE}"
            else
                debuglog "Skipping composer install"
            fi
            if [[ -z "${SKIP_COMPOSER_HOOKS-}" ]];then
                dvv $BASE_DIR/init/sbin/composer.sh run-script pre-install-cmd
                dvv $BASE_DIR/init/sbin/composer.sh run-script post-install-cmd
            fi
        fi
    fi

    # Run install ?
    if [[ -z ${NO_INSTALL} ]];then ( cd $SRC_DIR && gosu $APP_USER bin/install.sh );fi

    # Run any migration
    if [[ -z ${NO_MIGRATE} ]];then
        call_drush updb
    fi
}

# fixperms: basic file & ownership enforcement
fixperms() {
    if [[ -n $NO_FIXPERMS ]];then return 0;fi
	if [ "$(id -u $APP_USER)" != "$HOST_USER_UID" ];then
	    groupmod -g $HOST_USER_UID $APP_USER
	    usermod -u $HOST_USER_UID -g $HOST_USER_UID $APP_USER
	fi
    for i in /etc/{crontabs,cron.d} /etc/logrotate.d /etc/supervisor.d;do
        if [ -e $i ];then
            while read f;do
                chown -R root:root "$f"
                chmod 0640 "$f"
            done < <(find "$i" -type f)
        fi
    done
    for i in $USER_DIRS;do if [ -e "$i" ];then chown $APP_USER:$PHP_GROUP "$i";fi;done
    while read f;do chmod 0755 "$f";done < \
        <(find $FINDPERMS_PERMS_DIRS_CANDIDATES -type d -not \( -perm 0755 2>/dev/null \) |sort)
    while read f;do chmod 0644 "$f";done < \
        <(find $FINDPERMS_PERMS_DIRS_CANDIDATES -type f -not \( -perm 0644 2>/dev/null \) |sort)
    while read f;do chown $APP_USER:$PHP_GROUP "$f";done < \
        <(find $FINDPERMS_OWNERSHIP_DIRS_CANDIDATES \
          \( -type d -or -type f \) -not \( -user $APP_USER -or -group $PHP_GROUP \)  2>/dev/null|sort)
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
    cd $SRC_DIR && exec gosu $APP_USER php app/www/core/scripts/drupal quick-start $DRUPAL_LISTEN
}

do_phpfpm() { ( php-fpm -F -R ) }

execute_hooks() {
    local step="$1"
    local hdir="$INIT_HOOKS_DIR/${step}"
    shift
    if [ ! -d "$hdir" ];then return 0;fi
    while read f;do
        if ( echo "$f" | grep -E -q "\.sh$" );then
            debuglog "running shell hook($step): $f" && . "${f}"
        else
            debuglog "running executable hook($step): $f" && "$f" "$@"
        fi
    done < <(find "$hdir" -type f -executable 2>/dev/null | grep -E -iv readme | sort -V; )
}

# Run app preflight routines (layout, files sync to campanion volumes, migrations, permissions fix, etc.)
pre() {
    if [ -e "${BASE_DIR}/docs" ] && [[ -z "${SKIP_SYNC_DOCS}" ]];then
        rsync -az${VCOMMAND} "${BASE_DIR}/docs/" "${BASE_DIR}/outdocs/" --delete
    fi
    # wait for db to be avalaible (skippable with SKIP_STARTUP_DB)
    # come from https://github.com/corpusops/docker-images/blob/master/rootfs/bin/project_dbsetup.sh
    if [ "x$SKIP_STARTUP_DB" = "x" ];then project_dbsetup.sh;fi
    execute_hooks pre "$@"
    configure
    execute_hooks afterconfigure "$@"
    # fixperms may have to be done on first run
    if ! ( services_setup );then
        fixperms
        execute_hooks beforeservicessetup "$@"
        services_setup
    fi
    execute_hooks afterservicessetup "$@"
    fixperms
    execute_hooks afterfixperms "$@"
    execute_hooks post "$@"
}

if ( echo $1 | grep -E -q -- "--help|-h|help" );then usage;fi

if [[ -n ${NO_START-} ]];then
    while true;do echo "start skipped" >&2;sleep 65535;done
    exit $?
fi

# only display startup logs when we start in daemon mode and try to hide most when starting an (eventually interactive) shell.
if ! ( echo "$NO_STARTUP_LOGS" | grep -E -iq "^(no?)?$" );then if ! ( pre >"$STARTUP_LOG" 2>&1 );then cat "$STARTUP_LOG">&2;die "preflight startup failed";fi;else pre;fi;

if [[ "${IMAGE_MODE}" != "shell" ]]; then
    if ! ( echo $IMAGE_MODE | grep -E -q "$IMAGE_MODES" );then die "Unknown image mode ($IMAGE_MODES): $IMAGE_MODE";fi
    log "Running in $IMAGE_MODE mode"
    if [ -e "$STARTUP_LOG" ];then cat "$STARTUP_LOG";fi
    if [[ "$IMAGE_MODE" = "fg" ]]; then
        do_fg
    else
        cfg="/etc/supervisor.d/$IMAGE_MODE"
        if [ ! -e $cfg ];then die "Missing: $cfg";fi
        SUPERVISORD_CONFIGS="rsyslog $cfg" exec supervisord.sh
    fi
else
    if [[ "${1-}" = "shell" ]];then shift;fi
    cmd="$@"
    execute_hooks beforeshell "$@"
    ( cd $SRC_DIR && user=$SHELL_USER _shell "$cmd" )
fi
