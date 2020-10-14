#!/bin/bash
if [[ -n ${DEBUG} ]];then set -x;fi
set -e
SOURCEDIR=${SOURCEDIR:-"/code/docs.host"}
BUILDDIR=${BUILDDIR:-"/code/app.host/var/private/docs"}
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
if [[ -n "$@" ]];then
    exec $@
else
    [[ -z ${NO_CLEAN} ]] && make clean
    [[ -z ${NO_HTML} ]] && make html
fi

chown -R ${OWNER} "$BUILDDIR";