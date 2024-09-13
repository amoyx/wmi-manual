#!/bin/bash

apollo_version="2.2.0"
IPLIST="172.16.14.25;172.16.14.26"
WORKDIR="/opt/wmi"
LOGPATH="/opt/wmi/apollo_install.log"
mysql_data_dir="/var/lib/mysql"
mysql_root_passwd="Qwert.1234"
eth="ens192"  # 网卡名称

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

apollo_env(){
  env_list=""
  IFS=';'
  if [ -n "$IPLIST" ]; then
    num=1
    for ip in $IPLIST; do
      if [ $num -eq 1 ]; then
        env_list="qa"
      fi

      if [ $num -eq 2 ]; then
        env_list="${env_list};pre"
      fi

      if [ $num -eq 3 ]; then
        env_list="${env_list};prod"
      fi
      num=$((num+1))
    done
  fi
  print_message "【INFO】本次部署的Apollo环境列表: dev;$env_list"
}

install_depend() {
  mkdir -p $WORKDIR
  OSRELEASE=$(awk -F'"' '/^ID=/ {print $2}' /etc/os-release)
  OSVERSION=$(awk -F'"' '/^VERSION_ID=/ {print $2}' /etc/os-release)

  if [ -z "$OSRELEASE" ]; then
    OSRELEASE=$(awk -F'=' '/^ID=/ {print $2}' /etc/os-release)
  fi

  if [ -z "$OSVERSION" ]; then
    OSVERSION=$(awk -F'=' '/^VERSION_ID=/ {print $2}' /etc/os-release)
  fi

  print_message "【INFO】当前OS为$OSRELEASE, 版本：$OSVERSION"
  case $OSRELEASE in
    "centos" | "rhel" | "tencentos" | "alios")
	     yum install wget unzip tar -y
       ;;
     "fedora")
       dnf wget unzip tar -y
       ;;
    "debian" | "ubuntu")
	     apt-get update
	     apt-get install wget tar unzip -y
       ;;
    *)
       print_message "【WARN】你的操作系统未知，请自行安装wget tar unzip软件包！"
       ;;
  esac

  if [ $? -ne 0 ]; then
    print_message "【ERROR】基础工具tar,wget,unzip 安装失败，程序退出！"
    exit 1
  fi
}

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

unzip_file() {
    if [ $# -lt 2 ]; then
      echo "【ERROR】：需要传递2个参数，请检查参数传入是否有误,程序退出！"
      exit 1
    fi
    print_message "【INFO】正在解压$1文件，请稍等..."

    unzip -o $WORKDIR/$1 -d $WORKDIR/$2
    if [ $? -ne 0 ]; then
      print_message "【ERROR】$1文件解压失败，程序退出！"
      exit 1
    else
      print_message "【INFO】$1文件解压成功."
    fi
}

install_jdk() {
  jdk_url="https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.tar.gz"
  jdk_filename="jdk.tar.gz"
  download "$jdk_filename" "$jdk_url"

  tar -zxf $WORKDIR/$jdk_filename -C $WORKDIR --overwrite
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

install_mysql() {
  mysql_filename="mysql.tar.xz"
  mysql_url="https://cdn.mysql.com/archives/mysql-8.0/mysql-8.0.36-linux-glibc2.17-x86_64.tar.xz"
  download "${mysql_filename}" "$mysql_url"

  tar -Jxf $WORKDIR/${mysql_filename} -C $WORKDIR --overwrite
  if [ $? -ne 0 ]; then
    print_message "【ERROR】mysql安装失败，程序退出！"
    exit 1
  else
    mysql_home=$(find $WORKDIR -type d  -name "mysql-*")
    if [ -z "$mysql_home" ]; then
      print_message "【ERROR】 未找到mysql安装后的路径，程序退出！"
      exit 1
    fi
    print_message "【INFO】mysql安装成功,安装路径为$mysql_home！"
  fi
}

my_cnf(){
  cat <<EOF > /etc/my.cnf
[mysqld]
port = 3306
character_set_server=utf8mb4
user = mysql
datadir=$mysql_data_dir
socket=$mysql_data_dir/mysql.sock
log-error=$mysql_data_dir/mysqld.log
pid-file=$mysql_data_dir/mysqld.pid
lower_case_table_names = 1
innodb_buffer_pool_size = 2G
sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'
EOF
}

mysql_service() {
  cat <<EOF > /etc/systemd/system/mysqld.service
[Unit]
Description=MySQL Server
After=network.target
After=syslog.target

[Service]
User=mysql
Group=mysql
Type=forking
PIDFile=$mysql_data_dir/mysqld.pid
TimeoutSec=0
ExecStart=${mysql_home}/bin/mysqld --daemonize --pid-file=$mysql_data_dir/mysqld.pid
LimitNOFILE = 5000
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF
}

mysql_import() {
  if [ $# -lt 1 ]; then
    echo "【ERROR】：需要传递1个参数，请检查参数传入是否有误,程序退出！"
    exit 1
  fi

  ${mysql_home}/bin/mysql -u root -p"$mysql_root_passwd" --socket=$mysql_data_dir/mysql.sock $1 < ${WORKDIR}/$2
  if [ $? -ne 0 ]; then
    print_message "【ERROR】数据库脚本$2导入失败，程序退出！"
    exit 1
  else
    print_message "【INFO】数据库脚本$2导入成功."
  fi
}

mysql_exec(){
    if [ $# -lt 1 ]; then
      echo "【ERROR】：需要传递2个参数，请检查参数传入是否有误,程序退出！"
      exit 1
    fi

    ${mysql_home}/bin/mysql -u root -p"$mysql_root_passwd" --socket=$mysql_data_dir/mysql.sock -e "$1"

    if [ $? -ne 0 ]; then
      print_message "【ERROR】SQL指令 $1 执行失败，程序退出！"
      exit 1
    else
      print_message "【INFO】SQL指令 $1 执行成功."
    fi
}

start_mysql(){
  install_mysql
  my_cnf
  mysql_service

  id -u mysql > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    groupadd mysql
    useradd -s /sbin/nologin -r -g mysql mysql
  fi

  if [ -d "$mysql_data_dir" ]; then
    rm -rf $mysql_data_dir
  fi
  mkdir -p $mysql_data_dir
  chown -R mysql:mysql $mysql_data_dir

  print_message "【INFO】正在初始化mysql数据库，请稍等..."
  ${mysql_home}/bin/mysqld --initialize --user=mysql
  if [ $? -ne 0 ]; then
    print_message "【ERROR】mysql实例初始化失败，程序退出！"
    exit 1
  fi

  temp_passwd=`grep 'temporary password' $mysql_data_dir/mysqld.log | awk 'END {print $NF}'`
  if [ -z "$temp_passwd" ]; then
    print_message "【ERROR】未查到临时密码，程序退出！"
    exit 1
  fi
  print_message "【INFO】临时密码为: $temp_passwd"

  systemctl daemon-reload
  systemctl enable mysqld
  systemctl start mysqld
  if [ $? -ne 0 ]; then
    print_message "【ERROR】mysql服务启动失败，程序退出！"
    exit 1
  fi

  ${mysql_home}/bin/mysqladmin -u root -p"$temp_passwd" --socket=$mysql_data_dir/mysql.sock password "$mysql_root_passwd"
  if [ $? -ne 0 ]; then
    print_message "【ERROR】修改mysql root密码失败，程序退出！"
    exit 1
  fi

  mysql_exec "CREATE DATABASE ApolloPortalDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
  mysql_exec "CREATE DATABASE ApolloConfigDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
  mysql_exec "CREATE USER 'apollo'@'%' IDENTIFIED BY 'Asdf.1234';"
  # ALTER USER 'apollo'@'%' IDENTIFIED WITH mysql_native_password BY 'Asdf.1234'; mysql 8.0以后版本navicat客户端连接时需要修改插件
  mysql_exec "GRANT ALL PRIVILEGES ON ApolloConfigDB.* TO 'apollo'@'%';"
  mysql_exec "GRANT ALL PRIVILEGES ON ApolloPortalDB.* TO 'apollo'@'%';"

  if [ -n "$env_list" ];then
    for env_name in $env_list; do
      mysql_exec "CREATE DATABASE ApolloConfigDB_${env_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
      mysql_exec "GRANT ALL PRIVILEGES ON ApolloConfigDB_${env_name}.* TO 'apollo'@'%';"
    done
  fi

  mysql_exec "FLUSH PRIVILEGES;"
  print_message "【INFO】创建Apollo数据库Success，用户apollo，密码 Asdf.1234"
}

# 修改apollo配置文件
apollo_properties(){
    cat <<EOF > $WORKDIR/application-github.properties
spring.datasource.url = jdbc:mysql://${local_ipaddr}:3306/ApolloConfigDB?characterEncoding=utf8
spring.datasource.username = apollo
spring.datasource.password = Asdf.1234
EOF

  apollo_config_properties="$WORKDIR/apollo-configservice/config/application-github.properties"
  if [ -f $apollo_config_properties ];then
    mv $apollo_config_properties ${apollo_config_properties}_bak
  fi
  cp $WORKDIR/application-github.properties $apollo_config_properties

  apollo_admin_properties="$WORKDIR/apollo-adminservice/config/application-github.properties"
  if [ -f $apollo_admin_properties ];then
    mv $apollo_admin_properties ${apollo_admin_properties}_bak
  fi
  cp $WORKDIR/application-github.properties $apollo_admin_properties

  apollo_portal_properties="$WORKDIR/apollo-portal/config/application-github.properties"
  if [ -f $apollo_portal_properties ]; then
    mv $apollo_portal_properties ${apollo_portal_properties}_bak
  fi
  cp $WORKDIR/application-github.properties $apollo_portal_properties
  sed -i 's/ApolloConfigDB/ApolloPortalDB/g' $apollo_portal_properties

  apollo_env_properties="$WORKDIR/apollo-portal/config/apollo-env.properties"
  echo "dev.meta=http://${local_ipaddr}:8080" > $apollo_env_properties
  if [ -n "$env_list" ] && [ -n "$IPLIST" ] ;then
    sn=1
    for env_name in $env_list; do
      ip=$(echo $IPLIST | cut -d' ' -f$sn)
      echo "${env_name}.meta=http://${ip}:8080" >> $apollo_env_properties
      sn=$((sn+1))
    done
  fi
}

# 生成apollo系统服务
apollo_service(){
  cat <<EOF > $WORKDIR/apollo-config.service
[Unit]
Description=Apollo Config Service
After=network.target

[Service]
Type=forking
User=apollo
Group=apollo
ExecStart=$WORKDIR/apollo-configservice/scripts/startup.sh
Restart=on-failure
RestartSec=5
ExecStop=$WORKDIR/apollo-configservice/scripts/shutdown.sh
WorkingDirectory=$WORKDIR/apollo-configservice
Environment=JAVA_HOME=$jdk_home

[Install]
WantedBy=multi-user.target
EOF

  apollo_config_service="/etc/systemd/system/apollo-config.service"
  if [ -f $apollo_config_service ]; then
    rm -rf $apollo_config_service
  fi
  cp $WORKDIR/apollo-config.service $apollo_config_service

  apollo_admin_service="/etc/systemd/system/apollo-admin.service"
  if [ -f $apollo_admin_service ]; then
    rm -rf $apollo_admin_service
  fi
  cp $WORKDIR/apollo-config.service $apollo_admin_service
  sed -i 's/apollo-configservice/apollo-adminservice/g' $apollo_admin_service

   apollo_portal_service="/etc/systemd/system/apollo-portal.service"
   if [ -f $apollo_portal_service ]; then
     rm -rf $apollo_portal_service
   fi
   cp $WORKDIR/apollo-config.service $apollo_portal_service
   sed -i 's/apollo-configservice/apollo-portal/g' $apollo_portal_service
}

# apollo多环境SQL处理
apollo_multi_env(){
    if [ -n "$env_list" ] && [ -n "$IPLIST" ] ;then
      env_value="dev"
      for env_name in $env_list; do
        mysql_import "ApolloConfigDB_${env_name}" "apolloconfigdb.sql"
        env_value="$env_value,$env_name"
      done
      server_value="{\"DEV\":\"http://$local_ipaddr:8080\""
      sn=1
      env_key="QA"
      for ip in $IPLIST; do
        if [ $sn -eq 1 ]; then
          env_key="QA"
        fi
        if [ $sn -eq 2 ]; then
          env_key="PRE"
        fi
        if [ $sn -eq 3 ]; then
          env_key="PROD"
        fi
        server_value="$server_value,\"$env_key\":\"http://$ip:8080\""
        sn=$((sn+1))
      done
      server_value="$server_value}"
    fi
}

install_apollo() {
  id -u apollo > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    groupadd apollo
    useradd -s /sbin/nologin -r -g apollo apollo
  fi

  # 由于github下载速度过慢且经常超时，这里改成了自己的下载站点
  base_url="http://122.9.187.196:21666/apollo/v${apollo_version}"
  download "apolloconfigdb.sql" "$base_url/apolloconfigdb.sql"
  download "apolloportaldb.sql" "$base_url/apolloportaldb.sql"
  download "apollo-configservice.zip" "$base_url/apollo-configservice-${apollo_version}-github.zip"
  download "apollo-adminservice.zip" "$base_url/apollo-adminservice-${apollo_version}-github.zip"
  download "apollo-portal.zip" "$base_url/apollo-portal-${apollo_version}-github.zip"

  mkdir -p $WORKDIR/{apollo-configservice,apollo-adminservice,apollo-portal}
  mkdir -p /opt/logs
  unzip_file "apollo-configservice.zip" "apollo-configservice"
  unzip_file "apollo-adminservice.zip" "apollo-adminservice"
  unzip_file "apollo-portal.zip" "apollo-portal"

  sed -i 's/Use ApolloConfigDB;//g' $WORKDIR/apolloconfigdb.sql
  sed -i 's/CREATE DATABASE IF NOT EXISTS ApolloConfigDB DEFAULT CHARACTER SET = utf8mb4;//g' $WORKDIR/apolloconfigdb.sql

  apollo_properties
  apollo_service
  chown -R apollo:apollo $WORKDIR/apollo-configservice
  chown -R apollo:apollo $WORKDIR/apollo-adminservice
  chown -R apollo:apollo $WORKDIR/apollo-portal
  chown -R apollo:apollo /opt/logs

  mysql_import "ApolloConfigDB" "apolloconfigdb.sql"
  mysql_import "ApolloPortalDB" "apolloportaldb.sql"
  apollo_multi_env

  if [ -n "$IPLIST" ]; then
    sn=1
    for ip in $IPLIST; do
      env_name=$(echo "$env_list" | cut -d';' -f$sn)
      echo "当前环境: $env_name, 序号 $sn"
      ssh root@$ip "mkdir -p $WORKDIR /opt/logs"
      ssh root@$ip "id -u apollo > /dev/null 2>&1 && echo 'apollo user exist' || groupadd apollo && useradd -s /sbin/nologin -r -g apollo apollo"
      scp -r $jdk_home root@$ip:$WORKDIR/
      scp -r $WORKDIR/apollo-configservice root@$ip:$WORKDIR/
      scp -r $WORKDIR/apollo-adminservice root@$ip:$WORKDIR/
      ssh root@$ip "sed -i 's/ApolloConfigDB/ApolloConfigDB_${env_name}/g' $WORKDIR/apollo-configservice/config/application-github.properties"
      ssh root@$ip "sed -i 's/ApolloConfigDB/ApolloConfigDB_${env_name}/g' $WORKDIR/apollo-adminservice/config/application-github.properties"
      ssh root@$ip "chown -R apollo.apollo $WORKDIR/{apollo-configservice,apollo-adminservice} && chown -R apollo.apollo /opt/logs"
      scp /etc/systemd/system/apollo-config.service root@$ip:/etc/systemd/system/apollo-config.service
      scp /etc/systemd/system/apollo-admin.service root@$ip:/etc/systemd/system/apollo-admin.service
      ssh root@$ip "systemctl daemon-reload"
      ssh root@$ip "systemctl enable apollo-config"
      ssh root@$ip "systemctl enable apollo-admin"
      ssh root@$ip "systemctl start apollo-config"
      ssh root@$ip "systemctl start apollo-admin"
      sn=$((sn+1))
    done
  fi

  systemctl daemon-reload
  systemctl enable apollo-config
  systemctl enable apollo-admin
  systemctl enable apollo-portal
  systemctl start apollo-config
  systemctl start apollo-admin
  systemctl start apollo-portal

  if [ $? -ne 0 ]; then
    print_message "【ERROR】apollo服务启动失败，请检查日志/opt/logs"
    exit 1
  else
    print_message "【SUCCESS】apollo服务启动成功，SUCCESS!"
    print_message "【INFO】请访问 http://${local_ipaddr}:8070 查看apollo服务，默认用户名：apollo 密码：admin"
    exit 0
  fi

   # "UPDATE apolloconfigdb.serverconfig SET `VALUE`='$env_value' WHERE 'KEY'='apollo.portal.envs';"
   # "UPDATE apolloconfigdb.serverconfig SET `VALUE`='$server_value' WHERE `KEY`='apollo.portal.meta.servers';"
}

run(){
  get_ipaddr
  apollo_env
  install_depend
  install_jdk
  start_mysql
  install_apollo
}

run
