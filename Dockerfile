# To slim down the final size, this image absoutly need to be squashed at the end of the build
# stages:
# - stage base: install & setup layout
# - stage composer(base): install dev deps & run composer
# - stage final(base): copy results files from composer stage
ARG BASE=corpusops/ubuntu-bare:20.04
FROM $BASE AS base
ARG APP_GROUP=
ARG APP_TYPE=drupal
ARG APP_USER=
ARG BUILD_DEV=y
ARG CHARSET=UTF-8
ARG FPM_LOGS_DIR=/logs/phpfpm
ARG COMPOSER_DOWNLOAD_URL=https://getcomposer.org
ARG COMPOSER_VERSION=1.10.16
ARG DEV_DEPENDENCIES_PATTERN='^#\s*dev dependencies'
ARG GPG_KEYS=B42F6819007F00F88E364FD4036A9C25BF357DD4
ARG GPG_KEYS_SERVERS="hkp://p80.pool.sks-keyservers.net:80 hkp://ipv4.pool.sks-keyservers.net hkp://pgp.mit.edu:80"
ARG HOST_USER_UID=1000
ARG LANG=fr_FR.utf8
ARG LANGUAGE=fr_FR
ARG PHP_GROUP=apache
ARG PHP_VER=7.2
ARG PHP_VER_NO_DOT=72
ARG TZ=Europe/Paris
ENV \
    APP_TYPE="${APP_TYPE}" \
    BUILD_DEV="$BUILD_DEV" \
    PHP_GROUP="${PHP_GROUP}" \
    APP_USER="${APP_USER:-$APP_TYPE}" \
    APP_GROUP="${APP_GROUP:-$APP_TYPE}" \
    FPM_LOGS_DIR="${FPM_LOGS_DIR}" \
    COMPOSER_VERSION="$COMPOSER_VERSION" \
    DEBIAN_FRONTEND="noninteractive" \
    LANG="$LANG" \
    LC_ALL="$LANG" \
    PHP_VER="$PHP_VER" \
    PHP_VER_NO_DOT="$PHP_VER_NO_DOT"

WORKDIR /code

USER root

ADD apt.txt ./
RUN bash -exc '\
    : "install packages" \
    && apt-get update  -qq \
    && apt-get install -qq -y software-properties-common apt-utils \
    && add-apt-repository -yu ppa:ondrej/php \
    && sed -i -re "s/(php-?)[0-9]\.[0-9]+/\1$PHP_VER/g" apt.txt \
    && apt-get install -qq -y $(grep -vE "^\s*#" apt.txt|tr "\n" " ") \
    && php --version \
    && apt-get clean all && apt-get autoclean'

RUN bash -exc '\
    : "remove default php-fpm pool"\
    && find $(ls -1d /etc/php*fpm* /etc/php*/*fpm* /etc/php*/*/*fpm*  2>/dev/null || true) /bin -type f -name www.conf -print -delete\
    \
    && : "on debian based systems, link pool definitions" \
    && (ls -1d /etc/php*/*/*fpm*/pool.d 2>/dev/null||true)|while read p;do rm -rf "$p";ln -sfv /etc/php-fpm.d $p;done\
    \
    && : "install composer"\
    && if (echo $COMPOSER_VERSION|egrep -vq "\." );then u="$COMPOSER_DOWNLOAD_URL/composer-${COMPOSER_VERSION}.phar";\
       else u="$COMPOSER_DOWNLOAD_URL/download/${COMPOSER_VERSION}/composer.phar";fi\
    && curl -sS "$u" -o /usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer \
    && /usr/local/bin/composer --version  \
    \
    && : "make shortcut links for php"\
    && ln -s $(which php-fpm${PHP_VER}) /usr/local/bin/php-fpm \
    && ln -s $(which php${PHP_VER}) /usr/local/bin/php \
    \
    && : "setup project user & workdir, and ssh">&2\
    && for g in $APP_GROUP $PHP_GROUP;do if !( getent group ${g} &>/dev/null );then groupadd ${g};fi;done \
    && if !( getent passwd ${APP_USER} &>/dev/null );then useradd -g ${APP_GROUP} -ms /bin/bash ${APP_USER} --uid ${HOST_USER_UID} --home-dir /home/${APP_USER};fi \
    && ( usermod -a -G $PHP_GROUP $APP_USER || true ) \
    && if [ ! -e /home/${APP_USER}/.ssh ];then mkdir /home/${APP_USER}/.ssh;fi \
    && chown -R ${APP_USER}:${APP_GROUP} /home/${APP_USER} . \
    && chown -R ${APP_USER}:${PHP_GROUP} . \
    && chmod 2755 /home/${APP_USER} . \
    \
    && : "set locale"\
    && export INSTALL_LOCALES="${LANG}" INSTALL_DEFAULT_LOCALE="${LANG}" \
    && if [ -e /usr/bin/setup_locales.sh ];then /usr/bin/setup_locales.sh; \
       else localedef -i ${LANGUAGE} -c -f ${CHARSET} -A /usr/share/locale/locale.alias ${LANGUAGE}.${CHARSET};\
       fi\
    \
    && : "setup project timezone"\
    && date && : "set correct timezone" \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    '
# Potential ssh keys for application user
ADD --chown=${APP_USER}:${APP_GROUP} keys/*                           /home/${APP_USER}/.ssh/
ADD --chown=${APP_USER}:${PHP_GROUP} app                              ./app
ADD --chown=${APP_USER}:${PHP_GROUP} sys/sbin                         ./sbin
ADD --chown=${APP_USER}:${PHP_GROUP} sys                              ./sys
ADD --chown=${APP_USER}:${PHP_GROUP} local/${APP_TYPE}-deploy-common/ ./local/${APP_TYPE}-deploy-common/


# We make an intermediary init folder to allow to have the
#
# entrypoint mounted as a volume in dev
# cp -frnv => keeps existing stuff, add new stuff, this allows for existing files in project
# overriding the common stuff
# common -> sys
# sys -> init
# ==> init contains files from both local sys and common, common cannot override content from local sys

RUN bash -exc ': \
    && : "alter rights and ownerships of ssh keys" \
    && chmod 0700 /home/${APP_USER}/.ssh \
    && (chmod 0600 /home/${APP_USER}/.ssh/* || true) \
    && (chmod 0644 /home/${APP_USER}/.ssh/*.pub || true) \
    && (chown -R ${APP_USER}:${APP_GROUP} /home/${APP_USER}/.ssh/* || true) \
    \
    && : "create layout" \
    && mkdir -vp sys init sbin\
    app/bin app/drush app/lib app/scripts app/src app/www app/var \
    app/www/sites app/www/sites/default \
    app/var/public app/var/private app/var/tmp app/var/cache app/var/nginxwebroot \
    local/${APP_TYPE}-deploy-common >&2\
    \
    && : "if we found a static dist inside the sys directory, it has been injected during " \
    && :  "the CI process, we just unpack it" \
    && if [ -e sys/statics ];then\
     while read f;do tar xJvf ${f};done \
      < <(find sys/statics -name "*.txz" -or -name "*.xz"); \
     while read f;do tar xjvf ${f};done \
      < <(find sys/statics -name "*.tbz2" -or -name "*.bz2"); \
     while read f;do tar xzvf ${f};done \
      < <(find sys/statics -name "*.tgz" -or -name "*.gz"); \
    fi\
    && rm -rfv sys/statics \
    \
    && : "assemble init" \
    && cp -frnv local/${APP_TYPE}-deploy-common/sys/* sys \
    && cp -frnv sys/* init \
    \
    && : "connect init.sh" \
    && ln -sf $(pwd)/init/init.sh /init.sh \
    \
    && : "generate a default app.env from the app/.env.dist.frep" \
    && frep "app/.env.dist.frep:app/.env" --overwrite \
    \
    && : "latest fixperm" \
    && find $(pwd) -not -user ${APP_USER} \
       | while read f;do chown ${APP_USER}:${PHP_GROUP} "$f";done \
    \
    && : "run composer install with --no-scripts switch is to avoid the drupal cache clear." \
    && : "Indeed this one requires a working database" \
    && cd app && gosu ${APP_USER} ../init/sbin/composerinstall.sh --no-scripts && cd -\
    \
    && : "Final cleanup, only work if using the docker build --squash option" \
    && if $(egrep -q "${DEV_DEPENDENCIES_PATTERN}" apt.txt);then \
      apt-get remove --auto-remove --purge \
        $(sed "1,/${DEV_DEPENDENCIES_PATTERN}/ d" apt.txt|grep -v '"'"^#"'"'|tr "\n" " ");\
    fi \
    && rm -rf /var/lib/apt/lists/* \
    '

# image will drop privileges itself using gosu
WORKDIR /code/app
ENTRYPOINT []
CMD "/init.sh"
