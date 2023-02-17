### openresty-mysql-k8s
在openresty通过lua连接MySQL，实现简单的增删改查，并用k8s部署到两个pod中
#### openresty
安装openresty，搭建调试环境

```
sudo apt-get -y install --no-install-recommends wget gnupg ca-certificates
wget -O - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" > openresty.list
sudo cp openresty.list /etc/apt/sources.list.d/
echo "deb http://openresty.org/package/arm64/ubuntu $(lsb_release -sc) main"
sudo apt-get update
sudo apt-get -y install --no-install-recommends openresty
```

在项目文件夹下

```
mkdir conf
mkdir logs
mkdir lua
```
conf为存放nginx启动的配置文件

logs用于存放nginx的日志信息

lua为不同路由所执行的lua脚本文件
##### nginx.conf
配置日志路径，增删改查接口的路由和调用的lua文件

```
worker_processes  1;
error_log logs/error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen 8080;
        location /insert {
            default_type text/html;
            lua_code_cache on;
            content_by_lua_file /home/zyt/project/openresty_test/lua/insert.lua;
        }
        location /update {
            default_type text/html;
            lua_code_cache on;
            content_by_lua_file /home/zyt/project/openresty_test/lua/update.lua;
        }
        location /delete {
            default_type text/html;
            lua_code_cache on;
            content_by_lua_file /home/zyt/project/openresty_test/lua/delete.lua;
        }
        location /select {
            default_type text/html;
            lua_code_cache on;
            content_by_lua_file /home/zyt/project/openresty_test/lua/select.lua;
        }
    }
}
```
##### lua文件
编写lua脚本连接mysql数据库，执行sql语句

```
local function close_db(db)
    if not db then
        return
    end
    db:close()
end

local mysql = require("resty.mysql")

local db, err = mysql:new()
if not db then
    ngx.say("new mysql error : ", err)
    return
end

db:set_timeout(1000)

local props = {
    host = "127.0.0.1",
    port = 3306,
    database = "mysql",
    user = "root",
    password = "123"
}

local res, err, errno, sqlstate = db:connect(props)

if not res then
   ngx.say("connect to mysql error : ", err, " , errno : ", errno, " , sqlstate : ", sqlstate)
   return close_db(db)
end

local insert_sql = "insert into test (ch) values('"..ngx.var.arg_ch.."')"
res, err, errno, sqlstate = db:query(insert_sql)
if not res then
   ngx.say("insert error : ", err, " , errno : ", errno, " , sqlstate : ", sqlstate)
   return close_db(db)
end

ngx.say("ok")
close_db(db)
```
##### 启动openresty并验证

```
nginx -p `pwd`/ -c conf/nginx.conf
curl 127.0.0.1:8080/insert?ch=hello
```
#### k8s
使用minikube利用虚拟机搭建单机的k8s节点，并启动mysql和openresty容器
##### 安装
1. 安装docker，添加用户组，修改权限
2. 安装kubectl,kubelet,kubeadm

```
// 安装所需要的包
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

// 下载 Google Cloud 公开签名秘钥（阿里云镜像）：
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg  https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg

// 添加 Kubernetes apt 仓库（阿里云镜像）：
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] http://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list


 安装 kubelet、kubeadm 和 kubectl：
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
```

3. 安装minikube
安装虚拟机，下载minikube安装包并给予执行权限

```
sudo apt install virtualbox virtualbox-ext-pack
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube

sudo mkdir -p /usr/local/bin/
sudo install minikube /usr/local/bin/
```
使用国内源，docker驱动启动

```
minikube start --driver=docker --container-runtime=containerd --image-mirror-country='cn'
```

##### 建立私有仓库
Minikube中部署Registry

重启minikube并配置远程仓库
```
minikube delete
minikube start --driver=docker --container-runtime=containerd --image-mirror-country='cn' --insecure-registries='192.168.49.2:31000' --registry-mirror=https://registry.docker-cn.com
```
在minikube主节点中重启docker服务

```
minikube ssh
systemctl unmask docker.service
systemctl unmask docker.socket
systemctl restart docker.service

```


在yaml文件夹下
```
kubectl create -f reigstry-deployment.yml
```
将Registry公开为Service

```
kubectl create -f registry-service.yml
```
暴露Registry的端口给宿主机

```
minikube service registry-service
```
推送mysql，openresty

```
docker tag mysql:latest <host>:<port>/mysql:latest
docker push <host>:<port>/mysql:latest
```

##### 创建pod

```
kubectl apply -f mysql.yaml
kubectl apply -f openresty.yaml
```

在mysql中创建数据库，赋予外部访问权限

在openresty中启动并监听8080端口
