#!/bin/bash

es_version="7.16.3"   # 必填，elasticsearch版本
es_data="/data/elasticsearch" # elasticsearch数据目录，默认为/var/lib/elasticsearch
IPLIST="172.16.14.25;172.16.14.26"  # elasticsearch集群IP列表, 多个IP用分号隔开,至少2个节点，需要填写偶数个节点（非必填，不填写表示单机部署，填写为集群部署）
WORKDIR="/opt/wmi"   # 工作目录，默认为/opt/wmi
LOGPATH="$WORKDIR/es_install.log"  # 日志文件
script="$WORKDIR/es_install.sh"  # 脚本文件，最好不要修改
eth="ens192"             # 网卡名称，默认为ens192


cat << EOF > $script
#!/bin/bash

es_version="$es_version"
es_data="$es_data"
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
install_elasticsearch() {

  OSRELEASE=$(awk -F'"' '/^ID=/ {print $2}' /etc/os-release)
  OSVERSION=$(awk -F'"' '/^VERSION_ID=/ {print $2}' /etc/os-release)

  if [ -z "$OSRELEASE" ]; then
    OSRELEASE=$(awk -F'=' '/^ID=/ {print $2}' /etc/os-release)
  fi

  if [ -z "$OSVERSION" ]; then
    OSVERSION=$(awk -F'=' '/^VERSION_ID=/ {print $2}' /etc/os-release)
  fi

  print_message "【INFO】当前OS为$OSRELEASE, 版本：$OSVERSION"

  print_message "【INFO】正在安装elasticsearch，版本 $es_version，请耐心等待..."
  vx=${es_version:0:1}
  case $OSRELEASE in
    "centos" | "rhel" | "fedora" | "alios" | "tencentos")
      cat << EOF > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
name=Elasticsearch repository for ${vx}.x packages
baseurl=https://artifacts.elastic.co/packages/${vx}.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
####EOF
      which yum
      if [ $? -eq 0 ]; then
        yum install elasticsearch-${es_version} -y
      else
        dnf install elasticsearch-${es_version} -y
      fi
      ;;
    "debian" | "ubuntu")
      apt-get update
      apt-get install wget -y
      wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
      apt-get install apt-transport-https -y
      echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/${vx}.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-${vx}.x.list
      apt-get install elasticsearch-${es_version} -y
      ;;
    *)
      print_message "【ERROR】暂未支持您的操作系统安装Elasticsearch，请手动安装,程序退出！"
      exit 1
      ;;
  esac

  if [ $? -ne 0 ]; then
    print_message "【ERROR】安装elasticsearch失败，程序退出！"
    exit 1
  else
    print_message "【INFO】安装elasticsearch成功！"
  fi
}

install_elasticsearch

if [ -d $es_data ];then
  rm -rf $es_data
fi
mkdir -p $es_data
chown -R elasticsearch:elasticsearch $es_data

EOF

print_message() {
  echo $1
  echo $1 >> $LOGPATH
}

get_ipaddr(){
  local_ipaddr=$(ip -4 addr show $eth | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  if [ $? -ne 0 ];
  then
    print_message "【ERROR】未获取到本机IP地址，程序退出！"
    exit 1
  fi
  print_message "【INFO】本机IP地址: $local_ipaddr"
}

es_cert(){

  if [ -f /usr/share/elasticsearch/elastic-certificates.p12 ];then
    rm -rf /usr/share/elasticsearch/elastic-certificates.p12
  fi

  if [ -f /usr/share/elasticsearch/elastic-stack-ca.p12 ];then
    rm -rf /usr/share/elasticsearch/elastic-stack-ca.p12
  fi

  /usr/share/elasticsearch/bin/elasticsearch-certutil ca
  /usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca elastic-stack-ca.p12
  if [ $? -ne 0 ]; then
    print_message "【ERROR】生成证书失败，程序退出！"
    exit 1
  fi
  mkdir -p /etc/elasticsearch/certs
  chown -R elasticsearch:elasticsearch /etc/elasticsearch/certs
  cp /usr/share/elasticsearch/elastic-certificates.p12 /etc/elasticsearch/certs/
  chmod 644 /etc/elasticsearch/certs/elastic-certificates.p12
}

elasticsearch_yml(){
  cat << EOF > $WORKDIR/elasticsearch.yml
cluster.name: es-cluster
node.name: node-1
network.host: 0.0.0.0
node.roles: ["master", "data"]
http.port: 9200
transport.tcp.port: 9300
discovery.seed_hosts: [$es_nodes]
cluster.initial_master_nodes: [$es_nodes]
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.keystore.path: /etc/elasticsearch/certs/elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: /etc/elasticsearch/certs/elastic-certificates.p12
path.data: $es_data
path.logs: /var/log/elasticsearch

EOF
}

es_password(){
  pass_txt=`yes y | /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto`
  elastic_pwd=$(echo $pass_txt |grep 'PASSWORD elastic =' |awk '{print $NF}')
  print_message "【INFO】elastic用户密码为：$elastic_pwd"
}

install_kibana() {
  print_message "【INFO】正在安装kibana，版本$es_version，请耐心等待..."
  which yum
  if [ $? -eq 0 ]; then
    yum install kibana-${es_version} -y
  fi

  which apt-get
  if [ $? -eq 0 ]; then
    apt-get update
    apt-get install kibana-${es_version} -y
  fi

  which dnf
  if [ $? -eq 0 ]; then
    dnf install kibana-${es_version} -y
  fi

  if [ $? -ne 0 ]; then
    print_message "【ERROR】安装kibana失败，程序退出！"
    exit 1
  else
    print_message "【INFO】安装kibana成功！"
  fi
}

kibana_yml() {
  cat << EOF > /etc/kibana/kibana.yml
server.host: "0.0.0.0"
server.port: 5601
elasticsearch.hosts: [$es_hosts]
elasticsearch.username: "elastic"
elasticsearch.password: "$elastic_pwd"
EOF
}

run(){
  mkdir -p $WORKDIR

  count=$(echo "$IPLIST" | awk -F';' '{print NF}')
  if [ $count -lt 2 ]; then
    print_message "【ERROR】节点数必须大于等于2，如2,4,6,8，请检查IPLIST变量配置是否正确，程序退出！"
    exit 1
  fi

  if [ $((count % 2)) -ne 0 ]; then
    print_message "【ERROR】节点数必须为偶数；如2,4,6,8，请检查IPLIST变量配置是否正确，程序退出！"
    exit 1
  fi

  get_ipaddr
  IFS=";"
  es_nodes="\"$local_ipaddr\""
  for ip in $IPLIST; do
    es_nodes="$es_nodes,\"$ip\""
  done

  es_hosts="\"http://$local_ipaddr:9200\""
  for ip in $IPLIST; do
    es_hosts="$es_hosts,\"http://$ip:9200\""
  done

  sed -i "s/####EOF/EOF/g" $script

  bash $script
  es_cert
  elasticsearch_yml
  yes | cp $WORKDIR/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
  systemctl start elasticsearch
  if [ $? -ne 0 ]; then
    print_message "【ERROR】 elasticsearch启动失败，程序退出！"
    exit 1
  fi
  systemctl enable elasticsearch

  sn=2
  for ip in $IPLIST; do
    print_message "【INFO】正在节点$ip安装elasticsearch，请耐心等待..."
    ssh root@$ip "mkdir -p $WORKDIR"
    scp $script root@$ip:$script
    ssh root@$ip "bash $script"
    scp $WORKDIR/elasticsearch.yml root@$ip:/etc/elasticsearch/elasticsearch.yml
    ssh root@$ip "sed -i 's/node-1/node-$sn/g' /etc/elasticsearch/elasticsearch.yml"
    ssh root@$ip "mkdir -p /etc/elasticsearch/certs &&  chown -R elasticsearch:elasticsearch /etc/elasticsearch/certs"
    scp /etc/elasticsearch/certs/elastic-certificates.p12 root@$ip:/etc/elasticsearch/certs/elastic-certificates.p12
    ssh root@$ip "chmod 644 /etc/elasticsearch/certs/elastic-certificates.p12"
    ssh root@$ip "systemctl start elasticsearch && systemctl enable elasticsearch"
    print_message "【INFO】节点$ip安装elasticsearch安装完毕."
  done

  es_password
  install_kibana
  kibana_yml
  systemctl start kibana
  if [ $? -ne 0 ]; then
    print_message "【ERROR】 kibana启动失败，程序退出！"
    exit 1
  else
    print_message "【INFO】 kibana启动成功！"
    print_message "【INFO】 kibana访问地址：http://$local_ipaddr:5601，用户名：elastic 密码：$elastic_pwd"
  fi
  systemctl enable kibana
}

run
