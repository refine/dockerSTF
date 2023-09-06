#!/bin/bash -e

if [ ! -n "$1" ] ;then
	hostname="127.0.0.1"
else
	hostname="$1"
fi
echo "服务IP:${hostname}"

echo "apt update......"
apt update

#安装 docker
echo "检查Docker......"
docker -v
if [ $? -eq  0 ]; then
    echo "检查到Docker已安装!"
else
    echo "安装docker环境..."
    curl -sSL https://get.docker.com/ | sh
    echo "安装docker环境...安装完成!"
fi


echo "启动 docker"
service docker start

stf_image="nobuoka/stf-arm64:latest"

echo "拉取image"
docker pull ${stf_image}
docker pull rethinkdb:2.4
docker pull nginx:latest

echo "创建文件夹"
mkdir rethinkdb_data
mkdir storage
chmod 777 storage

#获取当前目录
workdir=$(cd $(dirname $0); pwd)

echo "停止现有容器"
docker stop "stf-reaper" "triproxy-dev" "stf-processer" "triproxy-app" "storage-temp" "storage-image" "storage-apk" "stf-api" "websocket" "stf-auth" "stf-app" "some-rethink" "nginx" 
sleep 1

echo "删除现有容器"
docker rm -v "stf-reaper" "triproxy-dev" "stf-processer" "triproxy-app" "storage-temp" "storage-image" "storage-apk" "stf-api" "websocket" "stf-auth" "stf-app" "some-rethink" "nginx" 
sleep 1

echo "下载nginx配置文件..."
curl -sSL https://raw.githubusercontent.com/sunshine4me/dockerSTF/master/nginx.conf > nginx.conf

echo "启动nginx"
docker run -d  --name nginx -v "${workdir}/nginx.conf:/etc/nginx/nginx.conf:ro" --net host nginx:1.7.10 nginx


echo "启动 rethinkdb"
docker run -d --name some-rethink -v "${workdir}/rethinkdb_data:/data" --net host rethinkdb:2.3 rethinkdb --cache-size 2048 --no-update-check
sleep 3


# 初始化数据表,只需要执行一次
echo "rethinkdb init"
docker run --rm --name stf-migrate --net host ${stf_image} stf migrate
sleep 3

echo "启动 stf app"
docker run -d --name stf-app --net host -e "SECRET=YOUR_SESSION_SECRET_HERE" ${stf_image} stf app --port 7100 --auth-url http://${hostname}/auth/mock/ --websocket-url ws://${hostname}/
sleep 3

echo "启动 stf auth-mock"
docker run -d --name stf-auth --net host -e "SECRET=YOUR_SESSION_SECRET_HERE" ${stf_image} stf auth-mock --port 7101 --app-url http://${hostname}/
sleep 1

echo "启动 stf websocket"
docker run -d --name websocket --net host -e "SECRET=YOUR_SESSION_SECRET_HERE" ${stf_image} stf websocket --port 7102 --storage-url http://${hostname}/ --connect-sub tcp://127.0.0.1:7150 --connect-push tcp://127.0.0.1:7170
sleep 1

echo "启动 stf api"
docker run -d --name stf-api --net host -e "SECRET=YOUR_SESSION_SECRET_HERE" ${stf_image} stf api --port 7103 --connect-sub tcp://127.0.0.1:7150 --connect-push tcp://127.0.0.1:7170
sleep 1

echo "启动 stf storage-plugin-apk"
docker run -d --name storage-apk --net host ${stf_image} stf storage-plugin-apk --port 7104 --storage-url http://${hostname}/
sleep 1

echo "启动 stf storage-plugin-image"
docker run -d --name storage-image --net host ${stf_image} stf storage-plugin-image --port 7105 --storage-url http://${hostname}/
sleep 1

echo "启动 stf storage-temp"
docker run -d --name storage-temp --net host -v "${workdir}/storage:/data" ${stf_image} stf storage-temp --port 7106 --save-dir /data
sleep 1

echo "启动 stf triproxy app"
docker run -d --name triproxy-app --net host ${stf_image} stf triproxy app --bind-pub "tcp://*:7150" --bind-dealer "tcp://*:7160" --bind-pull "tcp://*:7170"
sleep 1

echo "启动 stf processor"
docker run -d --name stf-processer --net host ${stf_image} stf processor stf-processer --connect-app-dealer tcp://127.0.0.1:7160 --connect-dev-dealer tcp://127.0.0.1:7260
sleep 1

echo "启动 stf triproxy dev"
docker run -d --name triproxy-dev --net host ${stf_image} stf triproxy dev --bind-pub "tcp://*:7250" --bind-dealer "tcp://*:7260" --bind-pull "tcp://*:7270"
sleep 1

echo "启动 stf reaper dev"
docker run -d --name stf-reaper --net host ${stf_image} stf reaper dev --connect-push tcp://127.0.0.1:7270 --connect-sub tcp://127.0.0.1:7150 --heartbeat-timeout 30000
