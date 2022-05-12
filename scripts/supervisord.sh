#!/bin/sh
# Simple wrapper for supervisord to first update uid/gid if provided

# Check the UID/GID env settings
# If so modify the DVR user
# usermod -u $PUID dvr
# groupmod -g $PGID dvr

# now start the supervisord
/usr/bin/supervisord -c /etc/supervisor.d/supervisord.conf

