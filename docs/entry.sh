#!/bin/bash
if [[ -n ${DEBUG} ]];then set -x;fi
set -e
export SOURCEDIR=${SOURCEDIR:-"/code/docs"}
SYNC_DIR=${SYNC_DIR:-"/code/app/config/sync"}
if [ -e ${SYNC_DIR} ] && ( ls $SYNC_DIR/*.yml >/dev/null ) && ( grep -q -- "root_dir:.*var/docs" ${SYNC_DIR}/*.yml );then
    BUILDDIR=${BUILDDIR:-"/code/app/var/docs"}
else
    BUILDDIR=${BUILDDIR:-"/code/app/var/private/docs"}
fi
export NO_INSTALL=${NO_INSTALL-1}
export NO_INIT=${NO_INIT-}
export NO_CLEAN=${NO_CLEAN-}
export NO_HTML=${NO_HTML-}
export OWNER=${HOST_USER_UID:-1000}
init() {
	if [ ! -e "$BUILDDIR" ];then
        mkdir -pv "$BUILDDIR";
        chown ${OWNER} "$BUILDDIR";
    fi
}
build_doc() {
    [[ -z ${NO_CLEAN} ]] && if !(make clean);then ret=1;fi
    [[ -z ${NO_HTML} ]] && if !(make html);then ret=1;fi
    chown -R ${OWNER} "$BUILDDIR"
}
install_tools() {
    if [[ -n ${NO_INSTALL} ]];then return 0;fi
    python3 -m pip install -r requirements.txt
}
cd $SOURCEDIR
[[ -z "${NO_INIT}" ]] && init
[[ -z "${NO_INSTALL}" ]] && install_tools
if [[ -n "${@}" ]];then
    case ${1-} in
        build_doc|install_tools) $1;;
        *) "$@";;
    esac
else
    build_doc
fi
ret=$?
exit $ret
