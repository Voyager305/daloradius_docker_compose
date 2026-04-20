FROM php:8.2-fpm-alpine

RUN apk add --no-cache \
        curl \
        libzip-dev \
        oniguruma-dev \
        icu-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
    && curl -fsSL "https://pear.php.net/get/DB-1.12.2.tgz" -o /tmp/DB.tgz \
    && tar -xzf /tmp/DB.tgz -C /tmp \
    && cp -r /tmp/DB-1.12.2/DB.php /tmp/DB-1.12.2/DB /usr/local/lib/php/ \
    && chmod 644 /usr/local/lib/php/DB.php \
    && find /usr/local/lib/php/DB -type d -exec chmod 755 {} \; \
    && find /usr/local/lib/php/DB -type f -exec chmod 644 {} \; \
    && rm -rf /tmp/DB.tgz /tmp/DB-1.12.2 \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        mysqli \
        pdo_mysql \
        mbstring \
        intl \
        zip \
        gd

RUN { \
      echo "display_errors=Off"; \
      echo "log_errors=On"; \
      echo "error_reporting=E_ALL & ~E_DEPRECATED & ~E_WARNING & ~E_NOTICE"; \
    } > /usr/local/etc/php/conf.d/zz-daloradius.ini

WORKDIR /var/www/daloradius
