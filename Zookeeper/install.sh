#!/bin/bash

zookeeper_version="3.9.2"   # 必填，zookeeper版本
IPLIST="192.168.10.11;192.168.10.12;192.168.10.13"  # zookeeper集群IP列表, 多个IP用分号隔开,至少3个节点，需要填写奇数，如3,5,7,9...（非必填，不填写表示单机部署，填写为集群部署）
WORKDIR="/opt/wmi"   # 工作目录，默认为/opt/wmi
LOGPATH="$WORKDIR/zk_install.log"  # 日志文件
script="$WORKDIR/zk_install.sh"  # 脚本文件，最好不要修改
eth="ens192"             # 网卡名称，默认为ens192

mkdir -p $WORKDIR

cat << EOF > $script
#!/bin/bash

zookeeper_version="$zookeeper_version"
WORKDIR="$WORKDIR"
LOGPATH="$LOGPATH"
IPLIST="$IPLIST"
eth="$eth"

EOF

cat << 'EOF' >> $script
print_message() {
  echo $1
  echo $1 >> $LOGPATH
}

EOF

cat << 'EOF' >> $script
install_depend() {
  OSRELEASE=$(awk -F'"' '/^ID=/ {print $2}' /etc/os-release)
  OSVERSION=$(awk -F'"' '/^VERSION_ID=/ {print $2}' /etc/os-release)

  if [ -z "$OSRELEASE" ]; then
    OSRELEASE=$(awk -F'=' '/^ID=/ {print $2}' /etc/os-release)
  fi

  if [ -z "$OSVERSION" ]; then
    OSVERSION=$(awk -F'=' '/^VERSION_ID=/ {print $2}' /etc/os-release)
  fi

  print_message "【INFO】当前OS为$OSRELEASE, 版本：$OSVERSION"

  which yum
  if [ $? -eq 0 ]; then
    yum install wget tar -y
  fi

  which apt-get
  if [ $? -eq 0 ]; then
    apt-get update
    apt-get install wget tar -y
  fi

  which dnf
  if [ $? -eq 0 ]; then
    dnf install wget tar -y
  fi

  if [ $? -ne 0 ]; then
    print_message "【ERROR】基础工具tar,wget 安装失败，程序退出！"
    exit 1
  fi
}

EOF

cat << 'EOF' >> $script
get_ipaddr(){
  local_ipaddr=$(ip -4 addr show $eth | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  if [ $? -ne 0 ];
  then
    print_message "【ERROR】未获取到本机IP地址，程序退出！"
    exit 1
  fi
  print_message "【INFO】本机IP地址: $local_ipaddr"
}

EOF

cat << 'EOF' >> $script
download() {
  if [ $# -lt 2 ]; then
    echo "【ERROR】：需要传递2个参数，请检查参数传入是否有误,程序退出！"
    exit 1
  fi

  print_message "【INFO】正在下载$1文件，请稍等..."
  wget -O $WORKDIR/$1 $2

  if [ $? -ne 0 ]; then
    print_message "【ERROR】下载$1文件失败，程序退出！"
    exit 1
  else
    print_message "【INFO】下载$1文件成功！"
  fi
}

download_file() {
  jdk_url="https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.tar.gz"
  download "jdk.tar.gz" "$jdk_url"

  zk_url="https://dlcdn.apache.org/zookeeper/zookeeper-${zookeeper_version}/apache-zookeeper-${zookeeper_version}-bin.tar.gz"
  download "zookeeper.tar.gz" "$zk_url"
}

EOF

cat << 'EOF' >> $script
install_jdk() {
  tar -zxf $WORKDIR/jdk.tar.gz -C $WORKDIR --overwrite
  if [ $? -ne 0 ]; then
    print_message "【ERROR】jdk解压失败，程序退出！"
    exit 1
  else
    jdk_home=$(find $WORKDIR -type d  -name "jdk-*")
    if [ -z "$jdk_home" ]; then
      print_message "【ERROR】 未找到java安装后的路径，程序退出！"
      exit 1
    fi
    ln -s $jdk_home/bin/java /usr/local/bin/java
    ln -s $jdk_home/bin/javac /usr/local/bin/javac
    print_message "【INFO】jdk安装成功，JAVA_HOME路径为$jdk_home！"
  fi
}

EOF

cat << 'EOF' >> $script
install_zookeeper(){
  tar -zxf $WORKDIR/zookeeper.tar.gz -C $WORKDIR --overwrite
  if [ $? -ne 0 ]; then
    print_message "【ERROR】zookeeper解压失败，程序退出！"
    exit 1
  else
    zk_home=$(find $WORKDIR -type d  -name "apache-zookeeper-*")
    if [ -z "$zk_home" ]; then
      print_message "【ERROR】 未找到zookeeper安装后的路径，程序退出！"
      exit 1
    fi
    mkdir -p $zk_home/data
    print_message "【INFO】zookeeper安装成功，zookeeper_home路径为$zk_home！"
  fi
}

EOF

cat << 'EOF' >> $script
zoo_cfg() {
   cat << EOF > $zk_home/conf/zoo.cfg
tickTime=2000
initLimit=10
syncLimit=5
dataDir=$zk_home/data
clientPort=2181
maxClientCnxns=60
autopurge.snapRetainCount=3
autopurge.purgeInterval=1

####EOF

IFS=';'
sn=1
for ip in $IPLIST;do
  echo "server.$sn=$ip:2888:3888" >> $zk_home/conf/zoo.cfg
  if [ "$ip" == "$local_ipaddr" ]; then
    echo "$sn" > $zk_home/data/myid
  fi
  sn=$((sn+1))
done
}

EOF

cat << 'EOF' >> $script
zookeeper_service() {
  cat << EOF > /etc/systemd/system/zookeeper.service
[Unit]
Description=Zookeeper
After=network.target

[Service]
Type=forking
ExecStart=$zk_home/bin/zkServer.sh start
ExecStop=$zk_home/bin/zkServer.sh stop
ExecReload=$zk_home/bin/zkServer.sh restart
User=root
Group=root
Restart=on-failure

[Install]
WantedBy=multi-user.target

####EOF
}

EOF

cat << 'EOF' >> $script
run() {
  install_depend
  if [ -n "$1" ] && [ "$1" == "download" ]; then
    download_file
  else
    get_ipaddr
    install_jdk
    install_zookeeper
    zoo_cfg
    zookeeper_service

    systemctl daemon-reload
    systemctl enable zookeeper
    systemctl start zookeeper
    if [ $? -ne 0 ]; then
      print_message "【ERROR】zookeeper启动失败，程序退出！"
      exit 1
    else
      print_message "【INFO】zookeeper启动成功！"
    fi
  fi
}

run $1
EOF

run(){
  sed -i "s/####EOF/EOF/g" $script

  if [ -n "$IPLIST" ];then
    count=$(echo "$IPLIST" | awk -F';' '{print NF}')
    if (( count < 3 )); then
      echo "【ERROR】节点数必须大于等于3，如3,5,7,9，请检查IPLIST变量配置是否正确，程序退出！"
      exit 1
    fi

    if (( count % 2 == 0 )); then
      echo "【ERROR】节点数必须为奇数；如3,5,7,9，请检查IPLIST变量配置是否正确，程序退出！"
      exit 1
    fi
  fi

  chmod +x $script
  bash $script "download"
  if [ -z "$IPLIST" ];then
    bash $script
  else
    IFS=';'
    for ip in $IPLIST;do
      echo "【INFO】正在安装zookeeper到$ip节点..."
      ssh root@$ip "mkdir -p $WORKDIR"
      scp $WORKDIR/jdk.tar.gz root@$ip:$WORKDIR/jdk.tar.gz
      scp $WORKDIR/zookeeper.tar.gz root@$ip:$WORKDIR/zookeeper.tar.gz
      scp $script root@$ip:$script
      ssh root@$ip "chmod +x $script && bash $script"
      if [ $? -ne 0 ]; then
        echo "【ERROR】zookeeper安装到$ip节点失败，请检查日志！"
        exit 1
      else
        echo "【INFO】zookeeper安装到$ip节点成功！"
      fi
    done
  fi
}

run
