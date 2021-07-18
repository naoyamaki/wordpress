#!/bin/sh

AWS_ACOUNT_ID=`aws sts get-caller-identity --query Account --output text`
docker-compose down --rmi all --volumes --remove-orphans
docker compose build
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin https://${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com
docker tag wp_web:latest ${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_web:latest
docker push ${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_web:latest
docker tag wp_app:latest ${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_app:latest
docker push ${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_app:latest