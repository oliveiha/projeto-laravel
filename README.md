
Projeto Laravel Aws.


1. certificados

Precisamos de dois certificados: um para o nosso aplicativo da web em si e outro para o nosso domínio personalizado
no CloudFront. Aquele para o seu aplicativo da Web precisa ser criado na região da AWS que você deseja
implantar seu aplicativo em que o CloudFront só aceitará certificados gerados na região
us-east-1.

2. Keypar para ser utilizado na instancia Ec2

3 . Execução das Stacks Cloudformation


├── master.yaml                # Template root (altere os apontamento s3 de acordo com sua configuração)
├── infrastructure
  ├── vpc.yaml                 # Nossas VPCs e security groups
  ├── storage.yaml             # Cluster de banco de dados e um buckets3 
  ├── web.yaml                 # Nosso Cluster Ecs
  └── services.yaml            # Nosso ECS Tasks Definitions & Services


4 - Criando uma nova stack

aws cloudformation create-stack --stack-name=laravel --template-body=file://master.yaml --parameters file://params.json --capabilities CAPABILITY_NAMED_IAM --on-failure DO_NOTHING

5 - Depois que a stack for criado, receberemos um erro 503 do ELB pois ele nao esta encontrado nenhuma instancia saudavel.
    Isso vai mudar assim que implatarmos a aplicação no nosso cluster ECS.

6 - Build e Push de uma imagem docker laravel.

Na etapa anterior criamos um registro ECR para armazenar nossa imagem, precisamos rodar o seguinte comando para gerar um novo registro.

eval $(aws ecr get-login --no-include-email)

Na pasta raiz ha 2 Dockerfile que usaremos para construir nossas imagens
Dockerfile-web

FROM php:7.1-fpm

# Update packages and install composer and PHP dependencies.
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    postgresql-client \
    libpq-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng12-dev \
    libbz2-dev \
    php-pear \
    cron \
    && pecl channel-update pecl.php.net \
    && pecl install apcu

# PHP Extensions
RUN docker-php-ext-install mcrypt zip bz2 mbstring pdo pdo_pgsql pdo_mysql pcntl \
&& docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
&& docker-php-ext-install gd

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

RUN mkdir storage/logs
RUN touch storage/logs/laravel.log
RUN chmod 777 storage/logs/laravel.log

RUN composer install
RUN php artisan optimize --force
# RUN php artisan route:cache

RUN chmod -R 777 /var/www/html/storage

RUN touch /var/log/cron.log

ADD deploy/cron/artisan-schedule-run /etc/cron.d/artisan-schedule-run
RUN chmod 0644 /etc/cron.d/artisan-schedule-run
RUN chmod +x /etc/cron.d/artisan-schedule-run

# CMD ["php-fpm"]

CMD ["/bin/sh", "-c", "php-fpm -D | tail -f storage/logs/laravel.log"],

Dcokerfile-ngnix

FROM nginx

ADD deploy/nginx/nginx.conf /etc/nginx/
ADD deploy/nginx/default.conf /etc/nginx/conf.d/

ADD public /usr/share/nginx/html

WORKDIR /usr/share/nginx/html

Criar uma instancia "Bastion" e efetuar a migração do banco de dados 





