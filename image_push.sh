#!/bin/sh

# AWSのアカウントIDをawscliから取得（複数アカウントを接している場合は注意）
AWS_ACOUNT_ID=`aws sts get-caller-identity --query Account --output text`

# 一度composeで作成した資材を削除してからイメージを再作成
docker compose down --rmi all --volumes --remove-orphans
docker compose build

# AWS ECRへログイン
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin https://${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

# webサーバのイメージを作成してECRへプッシュ
docker tag wp_web:latest ${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_web:latest
docker push ${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_web:latest

# appサーバのイメージを作成してECRへプッシュ
docker tag wp_app:latest ${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_app:latest
docker push ${AWS_ACOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_app:latest