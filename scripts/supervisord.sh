#!/bin/sh
# Simple wrapper for supervisord so we prep the container as needed

DEFAULTS_DIR=/HDHomeRunDVR/defaults
REC_DIR=/dvrrec
CONF_DIR=/dvrdata
CONF_DIR_DVR=${CONF_DIR}/dvr
CONF_DIR_NGINX=${CONF_DIR}/http
CONF_DIR_PHP=${CONF_DIR}/php
NGINX_CONF=${CONF_DIR_NGINX}/nginx.conf
NGINX_SRV_CONF=${CONF_DIR_NGINX}/nginx-dvrui.conf
PHP_WWW_CONF=${CONF_DIR_PHP}/www.conf
DVR_USR=dvr
DVR_GRP=dvr
PHP_ETC=/etc/php7
NGINX_ETC=/etc/nginx

##################
#
# worker functions for various tasks
#

validate_links() {
    if [ ! -d "/HDHomeRunDVR/data" ] ; then
        echo "INFO: DVR data folder doesn't exist, mapping to ${CONF_DIR}"
        ln -s ${CONF_DIR} /HDHomeRunDVR/data
    else
        # Location exists - but is it correct...
        echo "INFO: DVR data folder exists already"
        if [ -d "/HDHomeRunDVR/data" ] && [ ! -L "/HDHomeRunDVR/data" ] ; then
            echo "WARN: DVR data folder exists but is not linked as expected"
        fi
        if [ -L "/HDHomeRunDVR/data" ] ; then
            echo "INFO: DVR Data folder is linked"
            LINK_DATA=$(readlink -f /HDHomeRunDVR/data)
            if [[ "${LINK_DATA}" == "${CONF_DIR}" ]] ; then
                echo "INFO: DVR Folder linked to correct folder ${CONF_DIR}"
            else
                echo "WARN: DVR Folder linked to incorrect folder ${LINK_DATA}"
            fi
        fi
    fi

    if [ ! -d "/HDHomeRunDVR/recordings" ] ; then
        echo "INFO: Record recordings folder doesn't exist, mapping to ${REC_DIR}"
        ln -s ${REC_DIR} /HDHomeRunDVR/recordings
    else
        # Location exists - but is it correct...
        echo "INFO: DVR recordings folder exists already"
        if [ -d "/HDHomeRunDVR/recordings" ] && [ ! -L "/HDHomeRunDVR/recordings" ] ; then
            echo "WARN: DVR recordings folder exists but is not linked as expected"
        fi
        if [ -L "/HDHomeRunDVR/data" ] ; then
            echo "INFO: DVR recordings folder is linked"
            LINK_REC=$(readlink -f /HDHomeRunDVR/recordings)
            if [[ "${LINK_REC}" == "${REC_DIR}" ]] ; then
                echo "INFO: DVR recordings Folder linked to correct folder ${REC_DIR}"
            else
                echo "WARN: DVR recordings Folder linked to incorrect folder ${LINK_REC}"
            fi
        fi
    fi
}

validate_dvr() {
    if [ ! -d "${CONF_DIR_DVR}" ] ; then
        echo "INFO: DVR config folder doesn't exist, creating..."
        mkdir -p ${CONF_DIR_DVR}
    fi
}

validate_nginx() {
    if [ ! -d "${CONF_DIR_NGINX}" ] ; then
        echo "INFO: NGINX config folder doesn't exist, creating..."
        mkdir -p ${CONF_DIR_NGINX}
    fi
    if [ ! -f "${CONF_DIR_NGINX}/nginx.conf" ] ; then
        echo "INFO: NGINX config file is missing, pulling from defaults..."
        cp ${DEFAULTS_DIR}/nginx.conf ${CONF_DIR_NGINX}/nginx.conf
    fi
    if [ ! -f "${CONF_DIR_NGINX}/nginx-dvrui.conf" ] ; then
        echo "INFO: NGINX DVR Server config file is missing, pulling from defaults..."
        cp ${DEFAULTS_DIR}/nginx-dvrui.conf ${CONF_DIR_NGINX}/nginx-dvrui.conf
    fi
    ln -fs ${CONF_DIR_NGINX}/nginx.conf ${NGINX_ETC}/nginx.conf
    ln -fs ${CONF_DIR_NGINX}/nginx-dvrui.conf ${NGINX_ETC}/modules/nginx-dvrui.conf
}

validate_php() {
    if [ ! -d "${CONF_DIR_PHP}" ] ; then
        echo "INFO: PHP config folder doesn't exist, creating..."
        mkdir -p ${CONF_DIR_PHP}
    fi
    if [ ! -f "${CONF_DIR_PHP}/php-fpm.conf" ] ; then
        echo "INFO: PHP FPM config file is missing, pulling from defaults..."
        cp ${DEFAULTS_DIR}/php-fpm.conf ${CONF_DIR_PHP}/php-fpm.conf
    fi
    if [ ! -f "${CONF_DIR_PHP}/php-fpm-www.conf" ] ; then
        echo "INFO: PHP WWW Server config file is missing, pulling from defaults..."
        cp ${DEFAULTS_DIR}/php-fpm-www.conf ${CONF_DIR_PHP}/www.conf
    fi
    if [ ! -f "${CONF_DIR_PHP}/php.ini" ] ; then
        echo "INFO: PHP ini file is missing, pulling from defaults..."
        cp ${DEFAULTS_DIR}/php.ini-rel ${CONF_DIR_PHP}/php.ini
    fi
    /bin/ln -fs ${CONF_DIR_PHP}/php-fpm.conf ${PHP_ETC}/php-fpm.conf
    /bin/ln -fs ${CONF_DIR_PHP}/www.conf ${PHP_ETC}/php-fpm.d/www.conf
    /bin/ln -fs ${CONF_DIR_PHP}/php.ini ${PHP_ETC}/php.ini
}

create_dvr_user() {
    echo "INFO: Attempting requested User mapping"
    curruser=`/usr/bin/id -un`
    currgrp=`/usr/bin/id -gn`
    realgrp=${currgrp}
    echo "INFO: From ${curruser}:${currgrp} to ${PUID}:${PGID}"

    /usr/bin/getent group ${PGID}
    if [ $? -eq 0 ]; then
        echo "ERROR: GID specified in PUID [${PGID}] already exists - please specify a valid GID - skipping"
    else
        echo "INFO: Creating Group dvr with GID [${PGID}]"
        /usr/sbin/addgroup -g ${PGID} ${DVR_GRP}
        if [ $? -ne 0 ]; then
            echo "ERROR: Creating group with GID [${PGID}] FAILED - sticking with ${currgrp}"
        else
            echo "INFO: Success"
            realgrp=${DVR_GRP}
        fi
    fi

    /usr/bin/getent passwd ${PUID}
    if [ $? -eq 0 ]; then
        echo "ERROR: UID specified in PUID [${PUID}] already exists - please specify a valid UID - skipping"
    else
        /usr/sbin/adduser -HDG $realgrp -u ${PUID} ${DVR_USR}
        if [ $? -ne 0 ]; then
            echo "ERROR: Creating user with UID [${PUID}] FAILED"
        else
            echo "INFO: Success"
        fi
    fi
}

update_nginx_user() {
    echo "INFO: Updating Nginx User"
    /usr/bin/getent passwd ${PUID}
    if [ $? -eq 0] ; then
        echo "INFO: user with UID [${PUID}] exists, checking GID..."
        /usr/bin/getent group ${PGID}
        if [ $? -ne 0] ; then
            echo "WARN: group with GID [${PGID}] doesn't exists, using root and updating Nginx config"
            /sbin/sed -i "s!\(\"user nginx\").*!\1\"user ${DVR_USER} root\";!" ${NGINX_CONF}
        else
            echo "INFO: group with GID [${PGID}] exists, updating NGinx config"
            /sbin/sed -i "s!\(\"user nginx\"\).*!\1\"user ${DVR_USER} ${DVR_GRP}\";!" ${NGINX_CONF}
        fi
    else
        echo "WARN: user with PID [${PUID}] not found, using default"
    fi
}

update_php_user() {
    echo "INFO: Updating PHP User"
    /usr/bin/getent passwd ${PUID}
    if [ $? -eq 0] ; then
        echo "INFO: user with UID [${PUID}] exists, updating php config"
        /sbin/sed -i "s!\(\"user = nobody\").*!\1\"user = ${DVR_USER}\";!" ${PHP_WWW_CONF}
        /usr/bin/getent group ${PGID}
        if [ $? -ne 0] ; then
            echo "WARN: group with GID [${PGID}] doesn't exists, using default"
        else
            echo "INFO: group with GID [${PGID}] exists, updating php config"
            /sbin/sed -i "s!\(\"group = nobody\").*!\1\"group = ${DVR_USER}\";!" ${PHP_WWW_CONF}
        fi
    else
        echo "WARN: user with PID [${PUID}] not found, using default"
    fi
}

fix_permissions() {
    # Need to make sure we have the right permissions to the files needed.
    # and flag if the specified user doesn't have full access to the recordings
    echo "INFO: Attempting to Fixing Permissions"
}

# Check we have valid configuration - and create/patch up files if missing
validate_config() {
    validate_links
    validate_dvr
    validate_nginx
    validate_php
}

# Check the UID/GID env settings
update_user() {
    if [ ! -z "${PUID}" ] || [ ! -z "${PGID}"] ; then
        create_dvr_user
        update_nginx_user
        update_php_user
        fix_permissions
    fi
}

# Check the UI Port env setting
# If set - then update NGinx to run on that port
update_nginx_port() {
    if [[ ! -z "${DVRUI_PORT}" ]] ; then
        echo "INFO: Updating the NGINX Port for UI to ${DVRUI_PORT}"
        sed -i "s|listen 80 default_server|listen ${DVRUI_PORT} default_server|g" ${NGINX_SRV_CONF}
    else
        echo "WARN: NGINX Port for the UI will default to 80"
        echo "  please set DVRUI_PORT to free port number if you need to run something else on 80"
    fi

}

# start the supervisord
start_supervisord() {
    /usr/bin/supervisord -c /etc/supervisor.d/supervisord.conf
}

# Main Loop
echo ""
echo "************************************************"
echo ""
echo "           Starting DVR Container"
echo ""
echo "************************************************"
echo ""

validate_config
update_user
update_nginx_port
start_supervisord

