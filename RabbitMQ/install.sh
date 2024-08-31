#!/bin/bash

# 本脚本仅适用于CentOS系列操作系统，其他操作系统需自行修改脚本内容

iplist="192.168.100.11 192.168.100.12 192.168.100.13" # 集群ip列表
sshuser="root"    # ssh用户名
sshpasswd="password"  # ssh密码
rabbitmq_version="3.11.8"   # rabbitmq版本，仅支持3.10.20,3.11.8,3.12.10,3.13.6；
deploy_mode="cluster" # 部署模式,cluster集群模式,standalone单机模式
WORKDIR="/opt/wmi"    # 工作目录
LOGPATH="${WORKDIR}/rabbitmq_install.log"  #日志路径

OSRELEASE=""   # 操作系统发行服务商，无需填写
OSVERSION=""   # 操作系统发行版本，无需填写
rabbitmq_path="" # rabbitmq_path, rabbitmq安装包的路径，可以不填写; 如果要填写必须和rabbitmq_version相匹配
erlang_path=""  # erlang_path, erlang安装包的路径，可以不填写; 如果要填写必须和rabbitmq版本匹配


# 消息
print_message() {
  echo $1
  echo $1 >> $LOGPATH
}

# check_os 检查操作系统类型
check_os() {
  mkdir -p $WORKDIR
  
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

# 安装依赖
install_depend() {
  case $OSRELEASE in
    "centos" | "rhel" | "fedora")
	  yum clean all
	  yum makecache
	  yum install tar wget unzip zip git automake autoconf -y
	  ;;
	"debian" | "ubuntu")
	  apt-get update
    apt-get install tar wget unzip zip git automake autoconf -y
	  ;;
	*)
	  print_message "【WARN】未知的操作系统类型,请自行安装git,automake,autoconf工具!"
    ;;
  esac
  
  if [ $? -ne 0 ]; then
    print_message "【ERROR】基础依赖工具安装失败，程序退出！"
    exit 1
  fi
}

# download下载文件
function download() {
  if [ $# -ne 2 ]; then
    print_message "[ERROR] 传递的参数有误！"
    return 1
  fi
  filepath=$1
  filename=$(echo $filepath | awk -F'/' '{print $NF}')
  abspath="${WORKDIR}/$filename"
  if [ ! -f "$filepath" ]; then
    print_message "【INFO】正在下载,$filepath"
	if [[ ! $filepath =~ ^http ]]; then
	   print_message "【ERROR】请检查$filepath是否是一个正确的URL地址？"	   
	   exit 1
	fi
	curl -o $abspath $filepath
  else
    yes | cp $filepath $abspath
  fi
  
  if [ $? -ne 0 ]; then
	print_message "【ERROR】软件安装包下载失败，程序退出！"	
	exit 1
  fi
  
  case $2 in
    "rabbitmq")
       rabbitmq_path=$abspath
	   ;;
	"erlang")
	   erlang_path=$abspath
       ;;
	*)
	   print_message "【WARN】未找到对应的应用组件"
	   ;;
  esac
}

download_rabbitmq() {
  BASE_URL="http://122.9.187.196:21666/rabbitmq"
  
  if [ -z "$erlang_path" ]; then
	case $rabbitmq_version in
		"3.10.20" | "3.11.8" | "3.12.10")
		  erlang_path=$BASE_URL/erlang-25.3.2-1.el${OSVERSION}.x86_64.rpm
		  ;;
		"3.13.6")
		  erlang_path=$BASE_URL/erlang-26.2.5.2-1.el${OSVERSION}.x86_64.rpm
		  ;;
		*)
		  print_message "【ERROR】暂未支持你选择$rabbitmq_version的RabbitMQ版本"
		  exit 1
		  ;;
	  esac
  fi
  
  if [ -z "$rabbitmq_path" ]; then
	rabbitmq_path=$BASE_URL/rabbitmq-server-generic-unix-$rabbitmq_version.tar.xz
  fi
  
  echo $erlang_path
  echo $rabbitmq_path
  
  download $erlang_path erlang
  download $rabbitmq_path rabbitmq
}

# 配置rabbitmq集群
rabbitmq_cluster() {
  num=1
  echo '' > $WORKDIR/hosts
  for ipaddr in ${iplist}; do
    echo "$ipaddr rabbitmq$num"  >> $WORKDIR/hosts
    num=$((num + 1))
  done
}

# rabbitmq_service生成启动服务
rabbitmq_service() {
   cat > $WORKDIR/rabbitmq-server.service <<EOF
[Unit]
Description=RabbitMQ broker
After=syslog.target network.target

[Service]
Type=notify
User=$sshuser
Group=$sshuser
UMask=0027
NotifyAccess=all
TimeoutStartSec=600
LimitNOFILE=32768
Restart=on-failure
RestartSec=10
WorkingDirectory=/var/lib/rabbitmq
ExecStart=${WORKDIR}/rabbitmq_server-${rabbitmq_version}/sbin/rabbitmq-server
ExecStop=${WORKDIR}/rabbitmq_server-${rabbitmq_version}/sbin/rabbitmqctl shutdown
SuccessExitStatus=69

[Install]
WantedBy=multi-user.target

EOF

}

# 部署rabbitmq
deploy(){
	if [ "$deploy_mode" = "cluster" ]; then
	  rabbitmq_cluster
	  node_num=$(echo $iplist|awk -F' ' '{print NF}')
    if [ $node_num -lt 3 ]; then
       print_message "【ERROR】rabbitmq集群模式至少3个节点，程序退出！"
       exit 1
    fi

	  master_node=$(echo $iplist|awk -F' ' '{print $1}')
	  for ipaddr in ${iplist}; do
      ssh $sshuser@$ipaddr "mkdir -p $WORKDIR"
      ssh $sshuser@$ipaddr 'mkdir -p /var/lib/rabbitmq'
      ssh $sshuser@$ipaddr 'yum install tar -y'
      scp $rabbitmq_path $sshuser@$ipaddr:$rabbitmq_path
      scp $erlang_path $sshuser@$ipaddr:$erlang_path
      scp $WORKDIR/hosts $sshuser@$ipaddr:/etc/hosts
	    scp $WORKDIR/rabbitmq-server.service $sshuser@$ipaddr:/etc/systemd/system/rabbitmq-server.service
		
      ssh $sshuser@$ipaddr "yum localinstall $erlang_path -y"
      if [ $? -ne 0 ]; then
        print_message "【ERROR】$erlang_path在${ipaddr}节点安装失败，程序退出！"
        exit 1
      fi
		
      ssh $sshuser@$ipaddr "tar -Jxf $rabbitmq_path -C $WORKDIR --overwrite"
      if [ $? -ne 0 ]; then
        print_message "【ERROR】$rabbitmq_path在${ipaddr}节点安装错误，程序退出！"
        exit 1
      fi
		
      ssh $sshuser@$ipaddr 'systemctl daemon-reload'
      ssh $sshuser@$ipaddr 'systemctl start rabbitmq-server'
      ssh $sshuser@$ipaddr 'systemctl enable rabbitmq-server'
	  done
	  
	  scp $sshuser@$master_node:~/.erlang.cookie ${WORKDIR}/rabbitmq_cookie
	  
	  if [ $? -ne 0 ]; then
      print_message "【ERROR】获取$master_node节点cookie错误，程序退出！"
      exit 1
	  fi	  

	  rabbitmq_bin=${WORKDIR}/rabbitmq_server-${rabbitmq_version}/sbin
	  
	  for ipaddr in ${iplist};do
	    if [ "$ipaddr" = "$master_node" ]; then
		    continue
		  fi
		
      scp ${WORKDIR}/rabbitmq_cookie $sshuser@$ipaddr:~/.erlang.cookie
      ssh $sshuser@$ipaddr "chmod 400 ~/.erlang.cookie"
      ssh $sshuser@$ipaddr "${rabbitmq_bin}/rabbitmqctl stop_app"
      ssh $sshuser@$ipaddr "${rabbitmq_bin}/rabbitmqctl reset"
      ssh $sshuser@$ipaddr "${rabbitmq_bin}/rabbitmqctl join_cluster rabbit@rabbitmq1"
      ssh $sshuser@$ipaddr "${rabbitmq_bin}/rabbitmqctl start_app"
		
      if [ $? -ne 0 ]; then
        print_message "【ERROR】${ipaddr}节点加入集群失败，程序退出！"
        exit 1
      fi
	  done
	  
	  ssh $sshuser@$master_node "${rabbitmq_bin}/rabbitmqctl cluster_status"
	else
	  yum localinstall $erlang_path -y
	  if [ $? -ne 0 ]; then
      print_message "【ERROR】$erlang_path安装失败，程序退出！"
      exit 1
	  fi
	  
	  tar -Jxf $rabbitmq_path -C $WORKDIR --overwrite
	  if [ $? -ne 0 ]; then
      print_message "【ERROR】$rabbitmq_path安装失败，程序退出！"
      exit 1
	  fi
	  
	  yes | cp $WORKDIR/rabbitmq-server.service /etc/systemd/system/rabbitmq-server.service
	  
	  systemctl daemon-reload
    systemctl start rabbitmq-server
	fi
}

run(){
  check_os
  install_depend
  download_rabbitmq
  rabbitmq_service
  deploy
}

run