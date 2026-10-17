#!/bin/sh
# Entry point of the API containers (php:<version>-apache): serve $APACHE_DOCUMENT_ROOT and send every
# path that is not a file to index.php, so APIs can route /items, /items/1... without any .htaccess.
set -e

sed -ri "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" \
    /etc/apache2/sites-available/*.conf /etc/apache2/conf-available/*.conf

cat > /etc/apache2/conf-enabled/api.conf <<CONF
<Directory ${APACHE_DOCUMENT_ROOT}>
    AllowOverride All
    Require all granted
    FallbackResource /index.php
</Directory>
CONF
a2enmod rewrite > /dev/null

exec apache2-foreground
