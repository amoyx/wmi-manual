# Nginx部署说明
OpenResty 是基于 Nginx 的高性能 Web 平台，通过结合 Lua 脚本和 Nginx 模块，可以轻松实现动态 Web 应用和高性能的 API 服务器。本文档将指导你在 Linux 系统上安装[OpenResty](https://openresty.org/cn/installation.html).

Nginx 是一个高性能的 HTTP 服务器和反向代理服务器，自发布以来，因为其优越的性能和高扩展性，衍生出了多个分支和项目，以下是一些基于 Nginx 的重要衍生项目或分支：
* 1）OpenResty：是一个基于 Nginx 的高性能 Web 平台，集成了 LuaJIT、Lua 脚本处理能力和多种 Nginx 第三方模块，使得开发者可以使用 Lua 语言快速构建高并发 Web 应用、API 服务和动态内容
* 2）Tengine：是由阿里巴巴集团维护的一个 Nginx 衍生版本，针对高并发和大规模应用场景进行了多项优化。
* 3）Caddy：是一个现代化的 Web 服务器，受 Nginx 的启发而开发，虽然不是直接的 Nginx 分支，但具有类似的目标
* 4）Kong：Kong 是一个基于 Nginx 和 OpenResty 的开源 API 网关和微服务管理平台，提供了丰富的 API 管理功能，如身份验证、速率限制、监控、日志记录等。
* 5）nginx-quic：是由 Nginx 官方团队维护的一个实验性分支，增加了对 QUIC 和 HTTP/3 协议的支持。

由于OpenResty具有高性能和高并发处理能力，灵活的动态脚本能力，丰富的模块支持，优秀的社区支持和文档，开源和免费，强大的集成能力，适用于多种使用场景，并且在国内互联网公司中大量使用，因此本文以OpenResty构建Nginx.

## 1.Nginx高可用部署

###### 本文以Centos7系统上搭建Nginx高可用为例，如果是其他操作系统，请参考[官方文档](https://openresty.org/cn/linux-packages.html)部署

### 1.1 前提条件
* 一台具有 sudo 或 root 权限的 Linux 服务器
* 需要配置提前配置 epel.repo源，以免安装依赖失败
* 环境说明：<br> 
  1）192.168.10.11 为Nginx主节点，192.168.10.12 为Nginx备份节点<br>
  2）192.168.10.100为VIP(心跳IP地址)<br>

### 1.2 OpenResty安装
在192.168.10.11和192.168.10.12服务器上执行以下命令
```
配置openresty软件源
# curl -o /etc/yum.repos.d/openresty.repo https://openresty.org/package/centos/openresty.repo

查看 openresty 可安装版本
# yum --showduplicates list openresty

安装 openresty
# yum install -y openresty

启动 openresty 服务
#systemctl start openresty

设置开机启动 openresty
#systemctl enable openresty

openresty配置文件路径
# ls /usr/local/openresty/nginx/conf/nginx.conf
```

### 1.3 Keepalived安装
在192.168.10.11和192.168.10.12服务器上执行以下命令
```
安装keepalived
# yum install -y keepalived

编辑keepalived配置文件
# vi /etc/keepalived/keepalived.conf

! Configuration File for keepalived
global_defs {
  router_id LVS_DEVEL
}

vrrp_instance VI_1 {
    state MASTER     # 192.168.10.11设为 MASTER，192.168.10.12 设为 BACKUP
    interface eth0   # 绑定到的网络接口名称
    virtual_router_id 101  # VRRP 路由器 ID，主备需相同
    priority 90            # 优先级，MASTER 设置较高值，BACKUP 设置较低值
    advert_int 1           # 广播间隔
    authentication {
        auth_type PASS     # 验证类型，可以是 PASS 或 AH
        auth_pass 1111     # 验证密码，主备需相同
    }
    virtual_ipaddress {
       192.168.10.100       # 虚拟IP地址
    }
}

启动keepalived服务
# systemctl start keepalived
```

### 1.4 常用Nginx配置说明
nginx基本配置
```
server {
    listen 80;  # 监听的端口号
    server_name example.com www.example.com;  # 定义域名
    
    # 网站的根目录
    root /var/www/html;
    
    # 默认首页文件
    index index.html index.htm;

    # 日志配置
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;
    
    # URL 路径匹配和处理
    location / {
        try_files $uri $uri/ =404;  # 尝试按文件路径匹配，找不到时返回404
    }
}
```

静态文件缓存
```
server {
    .....
    
    # 配置jpg|jpeg|png|gif|ico|css|js 类型文件缓存30天
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;  # 缓存时间为 30 天
        access_log off;  # 关闭访问日志记录
    }
}
```

配置https访问
```
# vi /usr/local/openresty/nginx/conf.d/example_1.conf
server {
    listen 443 ssl;               # 启用 SSL 监听 443 端口
    server_name www.example.com;  # 替换为你的域名

    # SSL 证书文件和私钥文件,这个需要自行购买
    ssl_certificate /etc/nginx/ssl/your_signed.crt;
    ssl_certificate_key /etc/nginx/ssl/your_signed.key;

    # 推荐的 SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;  # 只启用安全的协议版本
    ssl_ciphers HIGH:!aNULL:!MD5;   # 设置 SSL 密码套件

    # 其他配置（如根目录、日志、错误页面等）
    location / {
        root /var/www/html;  # 替换为你的网站目录
        index index.html index.htm;
    }
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name www.example.com;
    return 301 https://$host$request_uri;  # 强制 HTTP 重定向到 HTTPS
}
```
配置负载均衡和反向代理
```
http {
    upstream backend {
        server 192.168.10.20:8080 weight=1;  # 域名或者IP都可以
        server backend.example.com max_fails=2 fail_timeout=30s;
        server backend2.example.com backup;  # 备用服务器
    }

    server {
        listen 80;
        server_name example.com;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;            
        }
    }
}

# 指令说明：
# weight：指定该服务器的权重，默认为 1。权重越高，服务器被选中的概率越高。
# max_fails： 在 fail_timeout 时间段内，允许的最大失败次数。达到此次数时，该服务器将被标记为失败
# fail_timeout：在检测到 max_fails 次失败后，将该服务器标记为不可用的时间，默认是 10s
# backup：将该服务器标记为备用服务器，仅在主服务器全部失效后才会使用。
# down：将该服务器标记为不可用，即使服务器实际可用也不会被选择。
```
反向代理缓存
```
proxy_cache_path /data/nginx/cache levels=1:2 keys_zone=cache_zone:10m max_size=1g inactive=60m use_temp_path=off;

server {
    location / {
        proxy_cache cache_zone; # 指定缓存区域
        proxy_cache_valid 200 302 10m;  # 缓存 200 和 302 状态码的响应 10 分钟
        proxy_cache_valid 404 1m;  # 缓存 404 状态码的响应 1 分钟
        proxy_pass http://backend;
    }
}

# /data/nginx/cache 缓存存储路径
# levels=1:2 设置缓存路径的层级，表示第一层目录使用 1 位十六进制表示（0 到 F，共 16 个子目录），第二层目录使用 2 位十六进制表示（00 到 FF，共 256 个子目录）
# keys_zone=cache_zone:10m  指定共享内存区域的名称和大小
# max_size=1g  设置缓存的最大总大小,一旦缓存达到此大小，Nginx 将自动删除最老的缓存文件
# inactive=60m 指定在没有访问的情况下，缓存项在多少时间后失效，默认10分钟，这里表示60分钟
# min_free=100m  指定文件系统必须保持的最小可用空间大小,如果低于这个大小，Nginx 将停止向缓存中写入新的内容
# use_temp_path=off  禁止使用临时文件，直接写入缓存文件
更多指令说明自行摸索 
```
配置日志格式
```
log_format main '$remote_addr - $remote_user [$time_local] "$request" "$request_uri" $request_method '
                  '$status $body_bytes_sent $request_time "$http_referer" '
                  '"$http_user_agent" "$http_x_forwarded_for"';
                  
access_log /var/log/nginx/access.log main;    
```
限制文件上传大小
```
client_max_body_size 10m;  # 限制最大上传10m
```
启用跨域资源共享（CORS），允许跨域请求
```
location / {
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
    add_header Access-Control-Allow-Headers 'DNT, X-CustomHeader, Keep-Alive, User-Agent, X-Requested-With, If-Modified-Since, Cache-Control, Content-Type';
}
```
IP白名单和黑名单控制
```
server {
    listen 80;
    server_name example.com;

    # IP 白名单配置
    allow 192.168.1.1;     # 允许单个 IP 地址， 
    allow 192.168.2.0/24;  # 允许整个 IP 网段
    deny all;              # 拒绝所有其他 IP 地址

    # 如果是禁止192.168.1.1和192.168.0.0/24，允许所有访问，则改成如下
    # deny 192.168.1.1;  # 禁止单个IP地址
    # deny 192.168.2.0/24; # 禁止整个 IP 网段
    # allow all;   # 允许所有访问
     
    location / {
        # 正常的服务配置...
        proxy_pass http://backend_server;
    }
}
```

## 二、脚本安装
本文提供了shell脚本一键安装，先下载脚本install.sh，然后执行脚本，脚本会自动安装OpenResty.

### 2.1 脚本执行前准备
* 需要用root管理员用户执行该脚本，执行过程中会用到特殊权限，避免因为权限导致脚本执行失败
* 确保80端口没有被占用，避免因为端口冲突导致OpenResty安装失败
* 请提前配置好SSH免密登录，免密登录的用户为root

### 2.2 脚本中变量说明
```
IPLIST="192.168.10.11;192.168.10.12"  # 必填，需要安装OpenResty的节点IP列表，多个IP用分号分隔，第一个节点为主节点，其他为备节点
VIP="192.168.10.100" # 必填，keepalived生成的VIP
WORKDIR="/opt/wmi"    # 安装主目录
LOGPATH="$WORKDIR/openresty_install.log"  # 安装执行时的日志
```

### 2.3 脚本执行
+ 1）下载install.sh脚本，最好是下载到一个单独的目录中，执行过程中会生成一些临时文件，以便执行完毕后清理.
+ 2）修改install.sh脚本中变量的值，根据你自己的实际场景修改配置
+ 3）给脚本执行权限 chmod +x install.sh，执行脚本 bash install.sh
