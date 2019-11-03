#!/bin/bash
if [[ -n ${DEBUG} ]];then set -x;fi
set -e
DOC_OUTPUT_DIR=${DOC_OUTPUT_DIR:-"/output"}
if [[ -n "$@" ]];then
    exec $@
else
	if [ ! -e "$DOC_DESTDIR" ];then mkdir -p "$DOC_DESTDIR";fi
    make html
fi
