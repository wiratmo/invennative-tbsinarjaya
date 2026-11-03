# Inventaris Toko Bangunan (invennative)
# PHP 8.3-FPM + Nginx (Alpine), SQLite + FTS5, tanpa MySQL

FROM node:22-alpine AS assets
WORKDIR /build

COPY package.json package-lock.json ./
COPY src ./src
COPY pages ./pages
COPY templates ./templates
COPY index.php ./

RUN npm ci \
    && npm install --no-save tailwindcss @tailwindcss/cli \
    && mkdir -p public/css vendor/sweetalert2 \
    && npx @tailwindcss/cli -i src/input.css -o public/css/tailwind.css --minify \
    && cp node_modules/sweetalert2/dist/sweetalert2.all.js vendor/sweetalert2/sweetalert2.all.js

FROM php:8.3-fpm-alpine

RUN apk add --no-cache \
        nginx \
        curl \
        bash \
        icu-libs \
        libpng \
        libjpeg-turbo \
        freetype \
        libzip \
        sqlite \
        unzip \
    && apk add --no-cache --virtual .build-deps \
        icu-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libzip-dev \
        oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        mbstring \
        gd \
        zip \
        opcache \
    && apk del .build-deps

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN echo "upload_max_filesize = 50M" > /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size = 55M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "memory_limit = 256M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "opcache.enable=1" > /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini

WORKDIR /var/www/html

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --optimize-autoloader --no-scripts

COPY . .
COPY --from=assets /build/public/css/tailwind.css /var/www/html/public/css/tailwind.css
COPY --from=assets /build/vendor/sweetalert2 /var/www/html/vendor/sweetalert2

COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /opt/db-init /run/nginx /var/www/html/storage/cache /var/www/html/public/css \
    && cp -a /var/www/html/database/. /opt/db-init/ \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/database /var/www/html/storage

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["sh", "-c", "php-fpm -D && exec nginx -g 'daemon off;'"]
