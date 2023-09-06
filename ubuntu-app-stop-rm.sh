#!/bin/bash -e

echo "停止现有容器"
docker stop "stf-reaper" "triproxy-dev" "stf-processer" "triproxy-app" "storage-temp" "storage-image" "storage-apk" "stf-api" "websocket" "stf-auth" "stf-app" "some-rethink" "nginx" 
sleep 1

echo "删除现有容器"
docker rm -v "stf-reaper" "triproxy-dev" "stf-processer" "triproxy-app" "storage-temp" "storage-image" "storage-apk" "stf-api" "websocket" "stf-auth" "stf-app" "some-rethink" "nginx" 
sleep 1
