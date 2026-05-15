FROM php:8.3-cli-alpine

RUN apk add --no-cache bash curl git icu-dev libzip-dev mysql-client \
    && docker-php-ext-install pdo_mysql intl zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.alpine.sh' | bash \
    && apk add --no-cache symfony-cli

WORKDIR /app
