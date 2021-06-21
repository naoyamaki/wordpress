FROM php:8.0.7-fpm-alpine
COPY etc/ /usr/local/etc/

# UTC時間をJST時間に変更
RUN apk --update add tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*

# phpモジュールを追加
RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pdo_mysql