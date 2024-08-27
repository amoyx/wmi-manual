#!/bin/bash

deploy_mode="cluster" # 部署模式,cluster集群模式,standalone单机模式, 为单机模式时，部署在本机，无需填写iplist, sshuser, shhpasswd
iplist="172.16.14.21 172.16.14.22 172.16.14.23"  # 仅支持3台服务器和6台服务器，3台服务器时每台起2个Redis实例，6台服务器时每台起1个Redis实例
sshuser="root" # 单机模式，无需填写
sshpasswd="abc123" # 单机模式，无需填写
redis_version="6.2.8"   # 必须>=4.0版本
redis_passwd="abc123" # redis密码，默认为abc123

WORKDIR="/opt/wmi"    # 工作目录
LOGPATH="${WORKDIR}/redis/redis_install.log"  #日志路径
OSRELEASE=""   # 操作系统发行服务商，无需填写
redis_path=""  # redis文件路径，无需填写

# 消息
print_message() {
  echo $1
  echo $1 >> $LOGPATH
}

# check_os 检查操作系统类型
check_os() {
  mkdir -p $WORKDIR/redis/{data,conf}

  OSRELEASE=$(awk -F'"' '/^ID=/ {print $2}' /etc/os-release)
  OSVERSION=$(awk -F'"' '/^VERSION_ID=/ {print $2}' /etc/os-release)
  
  if [ -z "$OSRELEASE" ]; then
    OSRELEASE=$(awk -F'=' '/^ID/ {print $2}' /etc/os-release)
  fi
  
  if [ -z "$OSVERSION" ]; then
    OSVERSION=$(awk -F'=' '/^VERSION_ID/ {print $2}' /etc/os-release)
  fi
  
  case $OSRELEASE in
    "centos")
	   msg="【INFO】当前OS为CentOS, 版本：$OSVERSION"
       ;;
    "rhel")
	   msg="【INFO】当前OS为Red Hat, 版本：$OSVERSION"
       ;;
	"fedora")
	   msg="【INFO】当前OS为Fedora, 版本：$OSVERSION"
	   ;;
    "debian")
	   msg="【INFO】当前OS为Debian, 版本：$OSVERSION"
       ;;
	"ubuntu")
	   msg="【INFO】当前OS为Ubuntu, 版本：$OSVERSION"
	   ;;
    *)
       msg="【INFO】未识别到你的操作系统类型 $OSRELEASE!, 版本为$OSVERSION"
       ;;
  esac

  print_message $msg
}

# copy_ssh_key 配置ssh免密通信
function copy_ssh_key() {
  case $OSRELEASE in
    "centos" | "rhel" | "fedora")
	  yum install sshpass expect -y
	  ;;
	"debian" | "ubuntu")
    apt-get install sshpass expect -y
	  ;;
	*)
	  print_message "【WARN】未知的操作系统类型,请自行安装sshpass工具!"
    ;;
  esac
 
  if [ $? -ne 0 ]; then
	   print_message "【ERROR】sshpass失败，程序退出！"
	   exit 1
  fi
  
  if [[ ! -f ~/.ssh/id_rsa ]]; then
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
  fi
  
  for ipaddr in ${iplist}; do
    sshpass -p ${sshpasswd} ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no $sshuser@$ipaddr
	  if [ $? -ne 0 ]; then
	    print_message "【ERROR】配置SSH免密登录错误，程序退出！"
	    exit 1
    fi
  done
  
}

# 安装依赖
install_depend() {
  case $OSRELEASE in
    "centos" | "rhel" | "fedora")
	  yum clean all
	  yum makecache
	  yum install tar gcc jemalloc-devel -y
	  ;;
	"debian" | "ubuntu")
	  apt-get update
    apt-get install tar gcc jemalloc-devel -y
	  ;;
	*)
	  print_message "【WARN】未知的操作系统类型,请自行安装tar gcc jemalloc-devel工具!"
    ;;
  esac
  
  if [ $? -ne 0 ]; then
    print_message "【ERROR】基础依赖工具安装失败，程序退出！"
    exit 1
  fi
}

# 下载redis包文件
download() {
  redis_url="https://download.redis.io/releases/redis-${redis_version}.tar.gz"
  filename=$(echo $redis_url | awk -F'/' '{print $NF}')
  redis_path="${WORKDIR}/$filename"
  print_message "【info】正在下载redis,下载地址 ${redis_url}"
  curl -o $redis_path $redis_url
  if [ $? -ne 0 ]; then
	  print_message "【ERROR】软件安装包下载失败，程序退出！"
	  exit 1
  fi
}

# 生成redis配置文件
redis_conf(){
  cat > $WORKDIR/redis/conf/redis-6379.conf <<EOF
bind 0.0.0.0
protected-mode no
port 6379
daemonize no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile "redis-6379.log"
databases 16
dir "$WORKDIR/redis/data"
stop-writes-on-bgsave-error no
rdbcompression yes
rdbchecksum yes
tcp-backlog 511
timeout 0
tcp-keepalive 60
save 900 1
save 300 10
save 60 3600
dbfilename "dump-6379.rdb"
masterauth "$redis_passwd"
requirepass "$redis_passwd"
repl-backlog-size 10mb
maxclients 10000
maxmemory 2gb
maxmemory-policy volatile-lru
appendonly no
appendfsync no
appendfilename "appendonly-6379.aof"
slowlog-log-slower-than 30000
slowlog-max-len 128

EOF

}

# 生成redis服务启动文件
redis_systemd_service(){
   cat > $WORKDIR/redis/conf/redis-6379.service <<EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
ExecStart=/usr/local/bin/redis-server $WORKDIR/redis/conf/redis-6379.conf
ExecStop=/usr/local/bin/redis-cli shutdown
Restart=always

[Install]
WantedBy=multi-user.target

EOF
}

redis_compile() {
  tar -zxf ${redis_path} -C $WORKDIR --overwrite
  if [ $? -ne 0 ]; then
    print_message "【ERROR】redis源码包解压失败，程序退出！"
    exit 1
  fi
  cd ${WORKDIR}/redis-${redis_version}
  make MALLOC=libc
  make install
}

deploy(){
   redis_conf="$WORKDIR/redis/conf/redis-6379.conf"
   redis_service="$WORKDIR/redis/conf/redis-6379.service"
  if [ "$deploy_mode" = "cluster" ]; then
     copy_ssh_key

     num=$(echo $iplist|awk -F' ' '{print NF}')
     if [ "$num" -ne "3" ] && [ "$num" -ne "6" ]; then
        print_message "【ERROR】集群服务器数必须是3或6，服务器数量错误，程序退出！"
        exit 1
     fi

     sed -i '$a\cluster-enabled yes' $redis_conf
     sed -i '$a\cluster-config-file nodes-6379.conf' $redis_conf
     sed -i '$a\cluster-node-timeout 15000' $redis_conf
     sed -i '$a\cluster-require-full-coverage no' $redis_conf

     if [ "$num" -eq "3" ]; then
        yes | cp $redis_conf $WORKDIR/redis/conf/redis-6380.conf
        sed -i 's/6379/6380/g' $WORKDIR/redis/conf/redis-6380.conf

        yes | cp $redis_service $WORKDIR/redis/conf/redis-6380.service
        sed -i 's/6379/6380/g' $WORKDIR/redis/conf/redis-6380.service
     fi

     cluster_nodes=""
     for ipaddr in ${iplist}; do
       ssh $sshuser@$ipaddr "mkdir -p $WORKDIR/redis/{conf,data}"
       scp /usr/local/bin/redis-cli $sshuser@$ipaddr:/usr/local/bin/redis-cli
       scp /usr/local/bin/redis-server $sshuser@$ipaddr:/usr/local/bin/redis-server
       scp /usr/local/bin/redis-benchmark $sshuser@$ipaddr:/usr/local/bin/redis-benchmark
       ssh $sshuser@$ipaddr "cd /usr/local/bin && ln -s redis-server redis-sentinel && ln -s redis-server redis-check-aof && ln -s redis-server redis-check-rdb"
       scp $redis_conf $sshuser@$ipaddr:$redis_conf
       scp $redis_service $sshuser@$ipaddr:/etc/systemd/system/redis-6379.service
       ssh $sshuser@$ipaddr "echo 'net.core.somaxconn = 1024' >> /etc/sysctl.conf"
       ssh $sshuser@$ipaddr "echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf && sysctl -p"
       if [ "$num" -eq "3" ]; then
         cluster_nodes="$cluster_nodes $ipaddr:6379 $ipaddr:6380"
          scp $WORKDIR/redis/conf/redis-6380.service $sshuser@$ipaddr:/etc/systemd/system/redis-6380.service
          scp $WORKDIR/redis/conf/redis-6380.conf $sshuser@$ipaddr:$WORKDIR/redis/conf/redis-6380.conf
          ssh $sshuser@$ipaddr "systemctl daemon-reload && systemctl start redis-6379"
          ssh $sshuser@$ipaddr "systemctl start redis-6380"
       else
          ssh $sshuser@$ipaddr "systemctl daemon-reload && systemctl start redis-6379"
          cluster_nodes="$cluster_nodes $ipaddr:6379"
       fi
     done

     print_message "【INFO】Redis集群实例：$cluster_nodes"
     master_node=$(echo $iplist|awk -F' ' '{print $1}')

     expect <<EOF
     spawn ssh $sshuser@$master_node "redis-cli -a $redis_passwd --cluster create $cluster_nodes --cluster-replicas 1"
     expect "please enter yes:"
     send "yes\r"
     send "exit\r"
     expect eof
EOF
     ssh $sshuser@$master_node "redis-cli --cluster create $cluster_nodes --cluster-replicas 1"
     if [ $? -ne 0 ]; then
       print_message "【ERROR】Redis集群部署失败，程序退出！"
       exit 1
     else
       print_message "【INFO】Redis集群部署成功！"
     fi
  else
    sed -i '$a\net.core.somaxconn = 1024' /etc/sysctl.conf
    sed -i '$a\vm.overcommit_memory = 1'  /etc/sysctl.conf
    yes | cp $redis_service /etc/systemd/system/redis-6379.service
    systemctl daemon-reload
    systemctl start redis-6379
    if [ $? -ne 0 ]; then
       print_message "【ERROR】Redis服务启动失败，程序退出！"
       exit 1
    else
       print_message "【INFO】Redis服务启动成功！"
    fi
  fi
}

run(){
  check_os
  install_depend
  download
  redis_compile
  redis_conf
  redis_systemd_service
  deploy
}

run
