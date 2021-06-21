FROM nginx:1.20-alpine
COPY nginx/ /etc/nginx/

# UTC時間をJST時間に変更
RUN apk --update add tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*