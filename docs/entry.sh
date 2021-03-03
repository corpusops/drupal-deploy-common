#!/bin/bash
if [[ -n ${DEBUG} ]];then set -x;fi
set -e
SOURCEDIR=${SOURCEDIR:-"/code/docs.host"}
SYNC_DIR=${SYNC_DIR:-"../app.host/config/sync"}
if [ -e ${SYNC_DIR} ] && ( ls $SYNC_DIR/*.yml >/dev/null ) && ( grep -q -- "root_dir:.*var/docs" ${SYNC_DIR}/*.yml );then
    BUILDDIR=${BUILDDIR:-"/code/app.host/var/docs"}
else
    BUILDDIR=${BUILDDIR:-"/code/app.host/var/private/docs"}
fi
NO_INIT=${NO_INIT-}
NO_CLEAN=${NO_CLEAN-}
NO_HTML=${NO_HTML-}
OWNER=${HOST_USER_UID:-1000}
init() {
	if [ ! -e "$BUILDDIR" ];then
        mkdir -pv "$BUILDDIR";
        chown ${OWNER} "$BUILDDIR";
    fi
}
[[ -z ${NO_INIT} ]] && init
cd $SOURCEDIR
if [[ -n "$@" ]];then
    exec $@
else
    [[ -z ${NO_CLEAN} ]] && make clean
    [[ -z ${NO_HTML} ]] && make html
fi

chown -R ${OWNER} "$BUILDDIR";
