FROM alpine:latest
WORKDIR /var/www/html

# Create default user and group
RUN addgroup -g 1000 dvr
RUN adduser -HDG dvr -u 1000 dvr

# Basics
RUN echo "UTC" > /etc/timezone
RUN apk add --no-cache nginx supervisor wget grep curl sqlite shadow

#Install PHP 
RUN apk add --no-cache php7 \
	php7-common \
	php7-fpm \
	php7-opcache \
	php7-zip \
	php7-curl \
	php7-xml \
	php7-json \
	php7-fileinfo \
	php7-dom \
	php7-pdo_sqlite 

#configure Supervisord
RUN mkdir -p /etc/supervisor.d/
COPY config/supervisord.conf /etc/supervisor.d/supervisord.conf

#Configure PHP
RUN mkdir -p /run/php
RUN touch /run/php/php7-fpm.pid
COPY config/php-fpm.conf /etc/php7/php-fpm.conf
COPY config/php.ini-rel /etc/php7/php.ini
COPY config/php-fpm-www.conf /etc/php7/php-fpm.d/www.conf

#Configure Nginx
RUN mkdir -p /run/nginx
RUN touch /run/nginx/nginx.pid
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx-dvrui.conf /etc/nginx/modules/nginx-dvrui.conf
# Remove the Default
RUN rm -f /etc/nginx/http.d/default.conf

#Copy the UI
RUN mkdir -p /var/www/html/dvrui
COPY ui/ /var/www/html/dvrui/
RUN chown -R dvr:dvr /var/www/html/dvrui

# Create working directory
RUN mkdir -p /HDHomeRunDVR

# Create volume mount points
RUN mkdir /dvrdata
RUN mkdir /dvrrec
RUN ln -s /dvrdata /HDHomeRunDVR/data
RUN ln -s /dvrrec /HDHomeRunDVR/recordings
RUN chown dvr:dvr /HDHomeRunDVR/data
RUN chown dvr:dvr /HDHomeRunDVR/recordings


COPY scripts/hdhomerun.sh /HDHomeRunDVR
COPY scripts/supervisord.sh /HDHomeRunDVR
RUN chmod u+x /HDHomeRunDVR/hdhomerun.sh
RUN chmod 755 /HDHomeRunDVR/supervisord.sh

# Set Volumes to be added
VOLUME ["/dvrrec", "/dvrdata"]

# Will use this port for mapping engine to the outside world
EXPOSE 59090
EXPOSE 80

ENTRYPOINT ["/bin/sh","/HDHomeRunDVR/supervisord.sh"]