FROM php:7.1-fpm

# Update packages and install composer and PHP dependencies.
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wget \
    #postgresql-client-9.6 \
    libpq-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng-dev \
    libbz2-dev \
    #php-pear \
    cron \
    && pecl channel-update pecl.php.net \
    && pecl install apcu

# PHP Extensions
RUN docker-php-ext-install mcrypt zip bz2 mbstring pdo pdo_pgsql pdo_mysql pcntl \
&& docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
&& docker-php-ext-install gd

#Problem Postgresql install resolv
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main"
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc
#RUN apt-get update -y
#RUN apt-get install postgresql-client-9.6 -y

# Memory Limit
RUN echo "memory_limit=2048M" > $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "max_execution_time=900" >> $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "extension=apcu.so" > $PHP_INI_DIR/conf.d/apcu.ini
RUN echo "post_max_size=20M" >> $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "upload_max_filesize=20M" >> $PHP_INI_DIR/conf.d/memory-limit.ini

# Time Zone
RUN echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini

# Display errors in stderr
RUN echo "display_errors=stderr" > $PHP_INI_DIR/conf.d/display-errors.ini

# Disable PathInfo
RUN echo "cgi.fix_pathinfo=0" > $PHP_INI_DIR/conf.d/path-info.ini

# Disable expose PHP
RUN echo "expose_php=0" > $PHP_INI_DIR/conf.d/path-info.ini

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

ADD . /var/www/html
WORKDIR /var/www/html

RUN mkdir /storage/
RUN touch /storage/laravel.log
RUN chmod 777 /storage/laravel.log
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer dump-autoload
RUN composer install --no-autoloader
RUN php artisan optimize --force
# RUN php artisan route:cache

RUN chmod -R 777 /var/www/html/storage

RUN touch /var/log/cron.log

ADD deploy/cron/artisan-schedule-run /etc/cron.d/artisan-schedule-run
RUN chmod 0644 /etc/cron.d/artisan-schedule-run
RUN chmod +x /etc/cron.d/artisan-schedule-run

CMD ["php-fpm"]

CMD ["/bin/sh", "-c", "php-fpm -D | tail -f storage/logs/laravel.log"],
