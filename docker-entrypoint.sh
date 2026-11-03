#!/bin/sh
set -e

mkdir -p /var/www/html/database /var/www/html/storage/cache /run/nginx

# Volume named overlay folder database/: pastikan schema/seed/migrations tetap ada.
for f in schema.sql seed.sql; do
    if [ ! -f "/var/www/html/database/$f" ] && [ -f "/opt/db-init/$f" ]; then
        cp "/opt/db-init/$f" "/var/www/html/database/$f"
    fi
done

if [ ! -d /var/www/html/database/migrations ] && [ -d /opt/db-init/migrations ]; then
    cp -a /opt/db-init/migrations /var/www/html/database/migrations
fi

chown -R www-data:www-data /var/www/html/database /var/www/html/storage
chmod -R ug+rwX /var/www/html/database /var/www/html/storage

exec "$@"
