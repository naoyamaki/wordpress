#!/bin/sh

docker compose build
docker tag wp_web:latest 247480313130.dkr.ecr.ap-northeast-1.amazonaws.com/wp_web:latest
docker push 247480313130.dkr.ecr.ap-northeast-1.amazonaws.com/wp_web:latest
docker tag wp_app:latest 247480313130.dkr.ecr.ap-northeast-1.amazonaws.com/wp_app:latest
docker push 247480313130.dkr.ecr.ap-northeast-1.amazonaws.com/wp_app:latest