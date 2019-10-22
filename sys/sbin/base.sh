#!/usr/bin/env bash
# This is the main bash ressource file.
#  - default variables values
#  - fonctions used by others

shopt -s extglob

RED=$'\e[31;01m'
BLUE=$'\e[36;01m'
YELLOW=$'\e[33;01m'
GREEN=$'\e[32;01m';
NORMAL=$'\e[0m'
CYAN="\\e[0;36m"

SDEBUG=${SDEBUG-}

# exit codes
END_SUCCESS=0
END_FAIL=1
END_RECVSIG=3
END_BADUSAGE=65

# activate shell debug if SDEBUG is set
if [[ -n $SDEBUG ]];then set -x;fi

NONINTERACTIVE="${NONINTERACTIVE:-}"

ROOTPATH="${ROOTPATH:-/code/app}"
BINPATH="${BINPATH:-"${ROOTPATH}/bin"}"
WWW_DIR="${WWW_DIR:-"${ROOTPATH}/www"}"
SITES_DIR="${SITES_DIR:-"${WWW_DIR}/sites"}"
SITES_SUBDIR="${SITES_SUBDIR:-"default"}"
PUBLIC_DIR="${PUBLIC_DIR:-"${ROOTPATH}/var/public"}"
PRIVATE_DIR="${PUBLIC_DIR:-"${ROOTPATH}/var/private"}"
STOP_CRON_FLAG="${PRIVATE_DIR}/suspend_drupal_cron_flag"
MAINTENANCE_FLAG="${PRIVATE_DIR}/MAINTENANCE"

# System User
APP_USER="${APP_USER:-$(whoami)}"
USER="${APP_USER}"
GROUP="${GROUP:-$(groups|awk '{print $0}')}"

# Locale to set
LOCALE="fr"

THE_DRUSH_WRAPPER="${BINPATH}/drush"
DRUSH="${BINPATH}/drush"
COMPOSER="${BINPATH}/composer"
# drush bare script abs path
DRUSH_CMD="${DRUSH_CMD:-}"
# drush var script search path if not found
DRUSH_PRETENDANTS="${DRUSH_PRETENDANTS:-"${ROOTPATH}/vendor/drush/drush/drush ${ROOTPATH}/lib/vendor/drush/drush/drush ${ROOTPATH}/sbin/vendor/drush/drush/drush /usr/local/bin/drush /usr/bin/drush drush"}"
DRUSH_EXTRA_ARGS=""
DRUSH_CALL=""

reset_colors() {
    if [[ -n ${NO_COLOR} ]]; then
        BLUE=""
        YELLOW=""
        RED=""
        CYAN=""
    fi
}

log_() {
    reset_colors
    logger_color=${1:-${RED}}
    msg_color=${2:-${YELLOW}}
    shift;shift;
    logger_slug="${logger_color}[${LOGGER_NAME}]${NORMAL} "
    if [[ -n ${NO_LOGGER_SLUG} ]];then
        logger_slug=""
    fi
    printf "${logger_slug}${msg_color}$(echo "${@}")${NORMAL}\n" >&2;
    printf "" >&2;  # flush
}

log() {
    log_ "${RED}" "${CYAN}" "${@}"
}

warn() {
    log_ "${RED}" "${CYAN}" "${YELLOW}[WARN] ${@}${NORMAL}"
}

may_die() {
    reset_colors
    thetest=${1:-1}
    rc=${2:-1}
    shift
    shift
    if [ "x${thetest}" != "x0" ]; then
        if [[ -z "${NO_HEADER-}" ]]; then
            NO_LOGGER_SLUG=y log_ "" "${CYAN}" "Problem detected:"
        fi
        NO_LOGGER_SLUG=y log_ "${RED}" "${RED}" "$@"
        exit $rc
    fi
}

die() {
    may_die 1 1 "${@}"
}

die_in_error_() {
    ret=${1}
    shift
    msg="${@:-"$ERROR_MSG"}"
    may_die "${ret}" "${ret}" "${msg}"
}

die_in_error() {
    die_in_error_ "${?}" "${@}"
}

debug() {
    if [[ -n "${DEBUG// }" ]];then
        log_ "${YELLOW}" "${YELLOW}" "${@}"
    fi
}

vvv() {
    debug "${@}"
    "${@}"
}

vv() {
    log "${@}"
    "${@}"
}

settings_folder_write_fix() {
    cd "${ROOTPATH}"
    echo "${YELLOW}+ Check Write rights in ${SITES_DIR}/${SITES_SUBDIR}${NORMAL}"
    chmod u+w "${SITES_DIR}/${SITES_SUBDIR}"
    chown ${USER}:${GROUP} "${SITES_DIR}/${SITES_SUBDIR}"
}

test_drush_status()  {
    call_drush status --format=yaml|grep -q "bootstrap: Successful"
    return $?
}


filter_drush() {
    # Prevent fork bombs
    if [ "x${1}" != "x${THE_DRUSH_WRAPPER}" ];then
        echo "${1}"
    fi
}

set_drush() {
    if [ "x${DRUSH_CALL}" = "x" ];then
        search=""
        if [ ! -x "${DRUSH_CMD}" ];then
            search="y"
        fi
        if [ "x${search}" != "x" ];then
            for i in ${DRUSH_PRETENDANTS};do
                if [ -x "$(filter_drush ${i})" ];then
                    if ${i} version 1>/dev/null 2>&1;then
                        DRUSH_CMD="${i}"
                        break
                    fi
                fi
            done
        fi
        if [ ! -x "${DRUSH_CMD}" ];then
            die "no drush found"
        fi
        DRUSH_CALL="${DRUSH_CMD} --root="${WWW_DIR}" ${DRUSH_EXTRA_ARGS}"
    fi
}

bad_exit() {
        echo ;
        echo "${RED} ERROR: ${1}" >&2;
        echo "${NORMAL}" >&2;
        exit ${END_FAIL};
}

check_conf_arg() {
    CONFARG=${1}
    if [ "x${!CONFARG}" == "x" ]; then
        bad_exit "${CONFARG} is not defined"
    fi
}

ask() {
    local ask=${ASK:-}
    if [[ -n $NONINTERACTIVE ]];then
        ask=${ask:-yauto}
    fi
    UNDONE=1
    NO_AVOID=${2}
    echo "${NORMAL}"
    while :
    do
        if [ "x${ask}" = "xyauto" ]; then
          echo " * ${1} [o/n]: ${GREEN}y (auto)${NORMAL}"
          USER_CHOICE=ok
          break
        fi
        read -r -p " * ${1} [o/n]: " USER_CHOICE
        if [ "x${USER_CHOICE}" == "xn" ]; then
            if [ "x${NO_AVOID}" == "xNO_AVOID_MESSAGE" ]; then
                echo "${GREEN}  --> no${NORMAL}"
                USER_CHOICE=abort
            else
                echo "${BLUE}  --> ok, step avoided.${NORMAL}"
                USER_CHOICE=abort
            fi
            break
        else
            if [ "x${USER_CHOICE}" == "xo" ]; then
                USER_CHOICE=ok
                break
            else
                if [ "x${USER_CHOICE}" == "xy" ]; then
                    USER_CHOICE=ok
                    break
                fi
            fi
        fi
        echo "${RED}Please answer \"o\",\"y\" (yes|oui) or \"n\" (no|non).${NORMAL}"
    done
}

call_composer() {
    "${COMPOSER}" "${@}"
}

call_drush() {
    local pre=""
    if [ "x${DATABASE_DRIVER}" = "xpgsql" ] && [ "x${DATABASE_PASSWD}" != "x" ];then
        export PGPASSWORD="$DATABASE_PASSWD"
    fi
    set_drush
    # Always cd in drupal www dir before running drush !
    cwd="$(pwd)"
    cd "${WWW_DIR}"
    ${pre} ${DRUSH_CALL} "${@}"
    ret=$?
    cd "${cwd}"
    return $ret
}

verbose_call_drush() {
    echo "${YELLOW}+ drush ${@}${NORMAL}"
    call_drush "${@}"
}

suspend_cron() {
    echo "${YELLOW}+ touch ${STOP_CRON_FLAG}${NORMAL}"
    touch "${STOP_CRON_FLAG}"
}

unsuspend_cron() {
    echo "${YELLOW}+ rm -f  ${STOP_CRON_FLAG}${NORMAL}"
    rm -f "${STOP_CRON_FLAG}"
}

maintenance_mode() {
    echo "${YELLOW}+ drush vset maintenance_mode 1${NORMAL}"
    ${BINPATH}/drush sset system.maintenance_mode TRUE
    echo "${YELLOW}+ touch ${MAINTENANCE_FLAG}${NORMAL}"
    touch "${MAINTENANCE_FLAG}"


}

undo_maintenance_mode() {
    echo "${YELLOW}+ drush vset maintenance_mode 0${NORMAL}"
    ${BINPATH}/drush sset system.maintenance_mode FALSE
    echo "${YELLOW}+ rm -f  ${MAINTENANCE_FLAG}${NORMAL}"
    rm -f "${MAINTENANCE_FLAG}"
}

activate_maintenance() {
    maintenance_mode
    suspend_cron
}

deactivate_maintenance() {
    undo_maintenance_mode
    unsuspend_cron
}

drush_updb() {
    verbose_call_drush -y updb
}


drush_cc_all() {
    verbose_call_drush -y cache-rebuild all
}

drush_cim() {
    verbose_call_drush -y cim
}

drush_cr() {
    verbose_call_drush -y cr
}

die() {
    echo "$@"
    exit 1
}

has_ignited_db() {
    case $DATABASE_DRIVER in
        postgres*|pgsql)
            NB_TABLES=$( call_drush sqlq --extra="-t" "SELECT COUNT(*) FROM information_schema.tables WHERE table_catalog ='${DATABASE_DB}' AND table_schema NOT IN ('pg_catalog', 'information_schema');" 2>/dev/null; );;
        *)
            NB_TABLES=$(call_drush sqlq --extra="-N" "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${DATABASE_DB}';" 2>/dev/null);;
    esac
    test "${NB_TABLES}" -gt "5"
}

check_public_files_symlink() {
    cd "${ROOTPATH}"
    if [ ! -d "${SITES_DIR}/default" ]; then
        echo "${YELLOW}+ Creating ${SITES_DIR}/default${NORMAL}";
        mkdir -p "${SITES_DIR}/default"
        chown ${USER}:${GROUP} "${SITES_DIR}/default"
    fi
    # Drupal specifics, checks /www/sites/default
    # is really symbolic link to /sites/default directory
    if [ -e "${SITES_DIR}" ]; then
        if [ -d "${SITES_DIR}/default/files" ]; then
            if [ ! -h "${SITES_DIR}/default/files" ]; then
                echo "${YELLOW}+ ${SITES_DIR}/default/files is a real directory!${NORMAL}"
                echo "${RED}++ moving it to ${SITES_DIR}/default/files.bak!${NORMAL}"
                mv "${SITES_DIR}/default/files" "${SITES_DIR}/default/files.bak"
                chown ${USER}:${GROUP} "${SITES_DIR}/default".bak
            fi
        fi
    else
        echo "${YELLOW}+ Creating ${SITES_DIR}/default${NORMAL}"
        mkdir -p "${SITES_DIR}/default"
        chown ${USER}:${GROUP} "${SITES_DIR}"
        chown ${USER}:${GROUP} "${SITES_DIR}/default"
    fi

    echo "${YELLOW}+ Testing relative link ${SITES_DIR}/default/files exists ${NORMAL}"
    if [ ! -h ${SITES_DIR}/default/files ]; then
        echo "${YELLOW}++ No, so Creating relative symbolic link to ../../../var/public for ${SITES_DIR}/default/files${NORMAL}";
        settings_folder_write_fix
        cd "${SITES_DIR}/default"
        echo "${YELLOW}++ Relative path used is: ../../../var/public ${NORMAL}"
        ln -s ../../../var/public files
        chown -h ${USER}:${GROUP} files
        cd -
    fi
}

# vim:set et sts=4 ts=4 tw=0:
