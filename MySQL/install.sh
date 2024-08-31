#!/bin/bash

DEPLOY_MODE="cluster"   # 部署模式,cluster主从模式,standalone单机模式, 为单机模式时，部署在本机，无需填写IP_LIST, SSH_USER
IP_LIST="192.168.10.11 192.168.10.12 192.168.10.13"   # 主从模式，节点IP列表，格式为：192.168.10.11 192.168.10.12 192.168.10.13； 第一个IP为主节点IP，其他为从节点IP
SSH_USER="root"         # ssh用户，需自行提前配置ssh免密，最好是root, 因为需要创建用户
MYSQL_VERSION="8.0.36"        # 安装的mysql版本
MYSQL_ROOT_PASSWD="Qwert.12345" # mysql root密码
MYSQL_REPL_USER="repl"          # 用于同步数据库的用户名
MYSQL_REPL_PASSWD="Zxcv.1234"   # 用于同步数据库的用户密码
WORKDIR="/opt/wmi"    # 工作目录
LOGPATH="${WORKDIR}/mysql_install.log"  #日志路径
OSRELEASE=""   # 操作系统发行服务商，无需填写
FILEPATH=""   # 无需填写

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
	  yum install tar curl -y
	  ;;
	"debian" | "ubuntu")
	  apt-get update
    apt-get install tar curl -y
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

  filepath="https://cdn.mysql.com/archives"
  case $MYSQL_VERSION in
    "5.6.1"* | "5.6.2"* | "5.6.3"*)
      filepath="$filepath/mysql-5.6/mysql-$MYSQL_VERSION-linux-glibc2.5-x86_64.tar.gz"
      ;;
    "5.6.4"*)
      filepath="$filepath/mysql-5.6/mysql-$MYSQL_VERSION-linux-glibc2.12-x86_64.tar.gz"
      ;;
    "5.7.1"* )
       filepath="$filepath/mysql-5.7/mysql-$MYSQL_VERSION-linux-glibc2.5-x86_64.tar.gz"
       ;;
     "5.7.2"* | "5.7.3"* | "5.7.4"*)
       filepath="$filepath/mysql-5.7/mysql-$MYSQL_VERSION-linux-glibc2.12-x86_64.tar.gz"
       ;;
     "8.0.1"* | "8.0.2"*)
       filepath="$filepath/mysql-8.0/mysql-$MYSQL_VERSION-linux-glibc2.12-x86_64.tar.xz"
       ;;
     "8.0.3"*)
       filepath="$filepath/mysql-8.0/mysql-$MYSQL_VERSION-linux-glibc2.17-x86_64.tar.xz"
       ;;
     "8.1.0")
       filepath="$filepath/mysql-8.1/mysql-8.1.0-linux-glibc2.17-x86_64.tar.xz"
       ;;
     "8.2.0")
       filepath="$filepath/mysql-8.2/mysql-8.2.0-linux-glibc2.17-x86_64.tar.xz"
       ;;
     "8.3.0")
       filepath="$filepath/mysql-8.3/mysql-8.3.0-linux-glibc2.17-x86_64.tar.xz"
       ;;
     "8.4.0")
       filepath="$filepath/mysql-8.4/mysql-8.4.0-linux-glibc2.17-x86_64.tar.xz"
       ;;
     *)
       print_message "【ERROR】不支持该 $MYSQL_VERSION 版本，请检查版本号是否正确！"
       exit 1
       ;;
  esac

  filename=$(echo $filepath | awk -F'/' '{print $NF}')
  abspath="${WORKDIR}/$filename"
	print_message "【INFO】正在下载,$filepath"
	curl -o $abspath $filepath

	if [ ! -f $abspath ]; then
	  print_message "【ERROR】文件下载失败，程序退出!"
	  exit 1
	fi
  FILEPATH=$abspath
}

mysql_cnf(){
  cat <<EOF > $WORKDIR/my.cnf
[mysqld]
server-id = 11
port = 3306
character_set_server=utf8mb4
user = mysql
skip_name_resolve = 1
max_connections = 800
datadir = /data/mysql5_7/data
pid-file = /data/mysql5_7/data/mysqld.pid
lower_case_table_names = 1
log_error = /data/mysql5_7/log/error.log
slow_query_log = 1
slow_query_log_file = /data/mysql5_7/log/slow.log
master_info_repository = TABLE
relay_log_info_repository = TABLE
log-bin = /data/mysql5_7/binlog/mysql-bin
sync_binlog = 1
log_slave_updates
binlog_format = row
relay_log =/data/mysql5_7/relaylog/relay-bin
relay_log_recovery = 1
slave_skip_errors = ddl_exist_errors
innodb_buffer_pool_size = 4G
innodb_log_group_home_dir = /data/mysql5_7/redolog/
innodb_undo_directory = /data/mysql5_7/undolog/
sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'
innodb_data_file_path=ibdata1:4096M:autoextend
innodb_data_home_dir=/data/mysql5_7/data

EOF

}

mysql_service() {
  cat <<EOF > $WORKDIR/mysql.service
[Unit]
Description=MySQL Server
After=network.target
After=syslog.target

[Service]
User=mysql
Group=mysql
Type=forking
PIDFile=/data/mysql5_7/data/mysqld.pid
TimeoutSec=0
ExecStart=$WORKDIR/mysqlroot/bin/mysqld --daemonize --pid-file=/data/mysql5_7/data/mysqld.pid
LimitNOFILE = 5000
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF

}

deploy() {

  ext=$(echo $FILEPATH | awk -F'.' '{print $NF}')
  if [ "$ext" = "gz" ]; then
    tar -zxf $FILEPATH -C $WORKDIR --overwrite
  elif [ "$ext" = "xz" ]; then
    tar -Jxf $FILEPATH -C $WORKDIR --overwrite
  fi

  if [ $? -ne 0 ]; then
    print_message "【ERROR】$FILEPATH 解压失败，程序退出！"
    exit 1
  fi

  myroot=$(find $WORKDIR -type d -name "mysql-$MYSQL_VERSION-linux*")
  if [ ! -d "$myroot" ]; then
     print_message "【ERROR】$myroot mysql工作目录不存在，程序退出！"
     exit 1
  fi

  my_cnf="$WORKDIR/my.cnf"
  my_service="$WORKDIR/mysql.service"
  my_dirname=$(echo $myroot | awk -F'/' '{print $NF}')
  sed -i "s/mysql5_7/mysql-$MYSQL_VERSION/g" $my_cnf
  sed -i "s/mysql5_7/mysql-$MYSQL_VERSION/g" $my_service
  sed -i "s/mysqlroot/$my_dirname/g" $my_service

  if [ "$DEPLOY_MODE" = "cluster" ]; then
     node_num=$(echo $IP_LIST|awk -F' ' '{print NF}')
     if [ $node_num -lt 2 ]; then
        print_message "【ERROR】mysql主从模式至少2个节点，程序退出！"
        exit 1
     fi
     master_ip=$(echo $IP_LIST | awk '{print $1}')
     sed -i '$a\gtid_mode=ON' $my_cnf
     sed -i '$a\enforce_gtid_consistency=ON' $my_cnf
     sed -i '$a\master_info_repository=TABLE' $my_cnf
     sed -i '$a\binlog_gtid_simple_recovery=ON' $my_cnf
     sed -i '$a\relay_log_info_repository=TABLE' $my_cnf
     num=100
     for ipaddr in $IP_LIST; do
        ssh $SSH_USER@$ipaddr "grep -q 'mysql' /etc/passwd && echo 'mysql user exists' || groupadd mysql && useradd -r -g mysql mysql"
        ssh $SSH_USER@$ipaddr "mkdir -p ${WORKDIR}"
        if [ $? -ne 0 ]; then
          print_message "【ERROR】$ipaddr节点创建mysql用户失败，程序退出！"
          exit 1
        fi

        ssh $SSH_USER@$ipaddr "test -d  /data/mysql-$MYSQL_VERSION && rm -rf /data/mysql-$MYSQL_VERSION && mkdir -p /data/mysql-$MYSQL_VERSION/{binlog,data,log,redolog,relaylog,undolog} || mkdir -p /data/mysql-$MYSQL_VERSION/{binlog,data,log,redolog,relaylog,undolog}"
        ssh $SSH_USER@$ipaddr "chown -R  mysql:mysql /data/mysql-$MYSQL_VERSION"

        num=$((num+1))
        yes | cp $my_cnf /tmp/my_cnf_$num
        sed -i "s/server-id = 11/server-id = $num/g" /tmp/my_cnf_$num
        scp /tmp/my_cnf_$num $ipaddr:/etc/my.cnf
        rm -rf /tmp/my_cnf_$num
        scp $my_service $ipaddr:/etc/systemd/system/mysqld.service

        case $OSRELEASE in
          "centos" | "rhel" | "fedora")
            ssh $SSH_USER@$ipaddr "yum install tar -y"
          ;;
          "debian" | "ubuntu")
            ssh $SSH_USER@$ipaddr "apt-get update && apt-get install tar -y"
            ;;
          *)
            print_message "【INFO】无需安装."
            ;;
        esac

        print_message "【INFO】$FILEPATH 文件正在复制到$ipaddr节点中."
        scp $FILEPATH $ipaddr:$FILEPATH

        print_message "【INFO】$FILEPATH 文件正在$ipaddr节点解压中."
        if [ "$ext" = "gz" ]; then
          ssh $SSH_USER@$ipaddr "tar -zxf $FILEPATH -C $WORKDIR --overwrite"
        elif [ "$ext" = "xz" ]; then
          ssh $SSH_USER@$ipaddr "tar -Jxf $FILEPATH -C $WORKDIR --overwrite"
        fi
        if [ $? -ne 0 ]; then
          print_message "【ERROR】$FILEPATH文件在$ipaddr节点中解压失败，程序退出！"
          exit 1
        fi

        print_message "【INFO】正在初始化$ipaddr节点mysql实例."
        ssh $SSH_USER@$ipaddr "$myroot/bin/mysqld --initialize --user=mysql"
        if [ $? -ne 0 ]; then
          print_message "【ERROR】$ipaddr节点mysql实例初始化失败，程序退出！"
          exit 1
        fi

        temp_passwd=$(ssh $SSH_USER@$ipaddr "grep 'temporary password' /data/mysql-$MYSQL_VERSION/log/error.log | awk 'END {print \$NF}'")
        if [ "$temp_passwd" = "" ]; then
          print_message "【ERROR】$ipaddr节点未查到临时密码，程序退出！"
          exit 1
        fi
        print_message "【INFO】$ipaddr节点临时密码 $temp_passwd"

        ssh $SSH_USER@$ipaddr "systemctl daemon-reload"
        ssh $SSH_USER@$ipaddr "systemctl enable mysqld"
        ssh $SSH_USER@$ipaddr "systemctl start mysqld"

        ssh $SSH_USER@$ipaddr "$myroot/bin/mysqladmin -u root -p'$temp_passwd'  password '$MYSQL_ROOT_PASSWD'"

        if [ "$ipaddr" = "$master_ip" ]; then
          ssh $SSH_USER@$ipaddr "$myroot/bin/mysql -u root -p$MYSQL_ROOT_PASSWD -e \"CREATE USER '$MYSQL_REPL_USER'@'%' IDENTIFIED BY '$MYSQL_REPL_PASSWD';\""
          ssh $SSH_USER@$ipaddr "$myroot/bin/mysql -u root -p$MYSQL_ROOT_PASSWD -e \"GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '$MYSQL_REPL_USER'@'%';\""
          if [[ $MYSQL_VERSION == 8* ]]; then
            ssh $SSH_USER@$ipaddr "$myroot/bin/mysql -u root -p$MYSQL_ROOT_PASSWD -e \"ALTER USER '$MYSQL_REPL_USER'@'%' IDENTIFIED WITH 'mysql_native_password' BY '$MYSQL_REPL_PASSWD';\""
          fi
          ssh $SSH_USER@$ipaddr "$myroot/bin/mysql -u root -p$MYSQL_ROOT_PASSWD -e 'FLUSH PRIVILEGES;'"
        else
          ssh $SSH_USER@$ipaddr "$myroot/bin/mysql -u root -p$MYSQL_ROOT_PASSWD -e \"CHANGE MASTER TO MASTER_HOST='$master_ip',master_user='$MYSQL_REPL_USER',master_password='$MYSQL_REPL_PASSWD',MASTER_AUTO_POSITION=1; \""
          ssh $SSH_USER@$ipaddr "$myroot/bin/mysql -u root -p$MYSQL_ROOT_PASSWD -e \"START SLAVE;\""
        fi
     done
  else
     has_user=$(grep -c "mysql" /etc/passwd)
     if [ $has_user -eq 0 ]; then
       groupadd mysql
       useradd -r -g mysql mysql
       if [ $? -ne 0 ]; then
         print_message "【ERROR】创建mysql用户失败，程序退出！"
         exit 1
       fi
     fi

     if [ -d "/data/mysql-$MYSQL_VERSION" ];then
       rm -rf /data/mysql-$MYSQL_VERSION
     fi
     mkdir -p /data/mysql-$MYSQL_VERSION/{binlog,data,log,redolog,relaylog,undolog}
     chown -R mysql:mysql /data/mysql-$MYSQL_VERSION

     yes | cp $my_cnf /etc/my.cnf
     yes | cp $my_service /etc/systemd/system/mysqld.service

     print_message "【INFO】正在初始化mysql实例."
     $myroot/bin/mysqld --initialize --user=mysql
     if [ $? -ne 0 ]; then
       print_message "【ERROR】mysql实例初始化失败，程序退出！"
       exit 1
     fi

     temp_passwd=`grep 'temporary password' /data/mysql-$MYSQL_VERSION/log/error.log | awk 'END {print $NF}'`
     if [ "$temp_passwd" = "" ]; then
       print_message "【ERROR】未查到临时密码，程序退出！"
       exit 1
     fi
     print_message "【INFO】临时密码为: $temp_passwd"
     systemctl daemon-reload
     systemctl enable mysqld
     systemctl start mysqld
     $myroot/bin/mysqladmin -u root -p"$temp_passwd" password "$MYSQL_ROOT_PASSWD"
  fi
}

run() {
  check_os
  install_depend
  download
  mysql_cnf
  mysql_service
  deploy
}

run
