#!/bin/bash
iplist="192.168.100.11 192.168.100.12 192.168.100.13"
sshuser="root"
sshpasswd="password"
jdk_path="https://developer-public-1256405155.cos.ap-shanghai.myqcloud.com/jdk-8u421-linux-x64.tar.gz"
nacos_path="https://developer-public-1256405155.cos.ap-shanghai.myqcloud.com/nacos-server-2.3.0.zip"
dt=$(date +%y%m%d)
WORKDIR="/opt/wmi$dt"
LOGPATH="${WORKDIR}/install.log"
deploy_mode="cluster"
nacos_dbhost="192.168.100.8"
nacos_dbport="3306"
nacos_dbname="nacos"
nacos_dbuser="nacos"
nacos_dbpasswd="dbpasswod"
OSRELEASE=""
OSVERSION=""


# check_os 检查操作系统类型
function check_os() {
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
  echo $msg
  echo $msg > $LOGPATH
}

# 检查包是否安装
function check_package_install(){
  result=0
  if [ "$#" -lt 1 ]; then
    msg="【ERROR】至少传递一个参数"
	echo $msg
    echo $msg >> $LOGPATH
    return 1
  fi
  case $OSRELEASE in
    "centos" | "rhel" | "fedora")
	  packages=$(rpm -qa)
	  ;;
	"debian" | "ubuntu")
      packages=$(dpkg -l)
	  ;;
	*)
	  packages=""
	  return 1
      ;;
  esac
  
  for pk in "$@"; do
    search=$(echo "$packages"|grep "$pk")
	if [ -z "$search" ]; then
	   return 1
	fi
  done
  return $result
}

# install_depend 安装依赖
function install_depend(){
  msg="正在安装基础依赖...."
  echo $msg
  echo $msg >> $LOGPATH  
  check_package_install "wget" "unzip" "zip" "tar"
  status=$?
  if [ $status -eq 1 ]; then
    case $OSRELEASE in
      "centos" | "rhel" | "fedora")
	    yum clean all
        yum makecache
        yum install wget unzip zip tar -y
	    ;;
	  "debian" | "ubuntu")
	    apt-get update
	    apt-get install wget unzip zip tar -y
	    ;;
      *)
        msg="【WARN】未知的系统，跳过软件依赖安装."
	    echo $msg
        echo $msg >> $LOGPATH
        ;;
    esac
	if [ $? -ne 0 ]; then
	   msg="【ERROR】基础依赖工具安装失败，程序退出！"
	   echo $msg
       echo $msg >> $LOGPATH
	   exit 1
	fi
  fi
}

# 下载包文件
function download() {
  if [ $# -ne 2 ]; then
    msg="[ERROR] 传递的参数有误！"
	echo $msg
    echo $msg >> $LOGPATH
    return 1
  fi
  filepath=$1
  filename=$(echo $filepath | awk -F'/' '{print $NF}')
  abspath="${WORKDIR}/$filename"
  if [ ! -f "$filepath" ]; then
    msg="【info】jdk本地文件不存在，正在下载, 下载地址 $filepath"
	echo $msg
    echo $msg >> $LOGPATH	
	if [[ ! $filepath =~ ^http ]]; then
	   msg="【ERROR】请检查$jdk_path是不是一个正确的URL地址!"
	   echo $msg
       echo $msg >> $LOGPATH		   
	   exit 1
	fi
	wget -O $abspath $filepath
  else
    yes | cp $filepath $abspath
  fi
  
  if [ $? -ne 0 ]; then
	msg="【ERROR】软件安装包下载失败，程序退出！"
	echo $msg
    echo $msg >> $LOGPATH		
	exit 1
  fi
  
  case $2 in
    "jdk")
       jdk_path=$abspath
	   ;;
	"nacos")
	   nacos_path=$abspath
       ;;
	*)
	   msg="【WARN】未找到对应的应用组件"
	   echo $msg
       echo $msg >> $LOGPATH	
	   ;;
  esac
  	
}

# nacos服务配置文件
function nacos_application_properties(){

  nacos_token=$(head -c 32 /dev/urandom | base64)
  nacos_identity_key=$(head -c 8 /dev/urandom | base64)
  nacos_identity_value=$(head -c 8 /dev/urandom | base64)
  
  cat > $WORKDIR/application.properties <<EOF
server.servlet.contextPath=/nacos
server.error.include-message=ALWAYS
server.port=8848
spring.sql.init.platform=mysql
db.num=1
db.url.0=jdbc:mysql://${nacos_dbhost}:${nacos_dbport}/${nacos_dbname}?characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=false&serverTimezone=Asia/Shanghai
db.user.0=${nacos_dbuser}
db.password.0=${nacos_dbpasswd}
db.pool.config.connectionTimeout=30000
db.pool.config.validationTimeout=10000
db.pool.config.maximumPoolSize=20
db.pool.config.minimumIdle=2
nacos.config.push.maxRetryTime=50
nacos.core.auth.system.type=nacos
nacos.core.auth.enabled=true
nacos.core.auth.caching.enabled=true
nacos.core.auth.server.identity.key=${nacos_identity_key}
nacos.core.auth.server.identity.value=${nacos_identity_value}
nacos.core.auth.plugin.nacos.token.cache.enable=false
nacos.core.auth.plugin.nacos.token.expire.seconds=18000
nacos.core.auth.plugin.nacos.token.secret.key=${nacos_token}  
EOF

}

# nacos集群配置文件
function nacos_cluster_conf(){
  for ip in ${iplist}; do
    echo "$ip:8848" >>  $WORKDIR/cluster.conf
  done 
}

# 制作nacos启动服务
function nacos_systemd_sevice(){
   if [ "$deploy_mode" = "cluster" ]; then
      startup="$WORKDIR/nacos/bin/startup.sh"
   else
      startup="$WORKDIR/nacos/bin/startup.sh -m standalone"
   fi
   
   cat > $WORKDIR/nacos.service <<EOF  
[Unit]
Description=This is Nacos Server
After=network.target

[Service]
Type=forking
ExecStart=$startup
ExecStop=$WORKDIR/nacos/bin/shutdown.sh
Restart=on-failure
RestartSec=10s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
 
}

# copy_ssh_key 配置ssh免密通信
function copy_ssh_key() {
  yum -y install sshpass
  if [[ ! -f ~/.ssh/id_rsa ]]; then
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
  fi
  
  for ipaddr in ${iplist}; do
    sshpass -p ${sshpasswd} ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@$ipaddr
	if [ $? -ne 0 ]; then
	  msg="【ERROR】配置SSH免密登录错误，程序退出！"
	  echo $msg
      echo $msg >> $LOGPATH	
	  exit 1
    fi
  done
}

# env_prep 环境准备
function env_prep(){
  if [ ! -d ${WORKDIR} ]; then
    mkdir -p ${WORKDIR}
  fi
  check_os
  install_depend
  download $jdk_path jdk
  download $nacos_path nacos
  nacos_application_properties
  nacos_systemd_sevice
  if [ "$deploy_mode" = "cluster" ]; then
    nacos_cluster_conf
    copy_ssh_key
  fi
  client=$WORKDIR/client.sh
  wget -O $client https://developer-public-1256405155.cos.ap-shanghai.myqcloud.com/nacos/client.sh
  sed -i "2a WORKDIR=${WORKDIR}" $client
  sed -i "2a LOGPATH=${LOGPATH}" $client
  sed -i "2a deploy_mode=${deploy_mode}" $client
  sed -i "2a jdk_path=${jdk_path}" $client
  sed -i "2a nacos_path=${nacos_path}" $client
  sed -i "2a java_home=''" $client
  sed -i "2a OSRELEASE=${OSRELEASE}" $client
}

env_prep

if [ "$deploy_mode" = "cluster" ]; then
  for ipaddr in ${iplist}; do
    ssh $sshuser@$ipaddr "mkdir -p $WORKDIR"
    scp $jdk_path $sshuser@$ipaddr:$jdk_path
	scp $nacos_path $sshuser@$ipaddr:$nacos_path
    scp $WORKDIR/application.properties  $sshuser@$ipaddr:$WORKDIR/application.properties
	scp $WORKDIR/cluster.conf $sshuser@$ipaddr:$WORKDIR/cluster.conf
	scp $WORKDIR/nacos.service $sshuser@$ipaddr:$WORKDIR/nacos.service
	scp $WORKDIR/client.sh $sshuser@$ipaddr:$WORKDIR/client.sh
	ssh $sshuser@$ipaddr "bash $WORKDIR/client.sh"
	if [ $? -ne 0 ]; then
	  msg="【ERROR】复制文件到${ipaddr}节点错误，程序退出！"
	  echo $msg
      echo $msg >> $LOGPATH	
	  exit 1
    fi
  done
else
  bash client.sh
fi
