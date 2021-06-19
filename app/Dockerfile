FROM php:8.0.7-fpm-alpine3.13

COPY etc/ /usr/local/etc/
RUN apk update
RUN apk add --no-cache php8-mbstring php8-mysqlnd php8-mysqli php8-pdo php8-gd