#!/bin/bash

xxl_job_version="2.4.1"
WORKDIR="/opt/wmi"
LOGPATH="/opt/wmi/xxl-job_install.log"
mysql_data_dir="/var/lib/mysql"
mysql_root_passwd="Qwert.1234"

print_message() {
    echo $1
    echo $1 >> $LOGPATH
}

install_depend() {
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
    "centos" | "rhel" | "fedora" | "tencentos" | "alios")
	     print_message "【INFO】当前OS为$OSRELEASE, 版本：$OSVERSION"
	     yum install curl tar -y
       ;;
    "debian" | "ubuntu")
	     print_message "【INFO】当前OS为$OSRELEASE, 版本：$OSVERSION"
	     apt-get update
	     apt-get install curl tar -y
       ;;
    *)
       print_message "【INFO】未识别到你的操作系统类型 $OSRELEASE!, 版本为$OSVERSION"
       ;;
  esac

  if [ $? -ne 0 ]; then
    print_message "【ERROR】基础工具tar,curl安装失败，程序退出！"
    exit 1
  fi
}

install_jdk() {
  print_message "【INFO】正在安装jdk，请稍等..."
  jdk_url="https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.tar.gz"
  curl -o $WORKDIR/jdk-17_linux-x64_bin.tar.gz $jdk_url
  tar -zxf $WORKDIR/jdk-17_linux-x64_bin.tar.gz -C $WORKDIR --overwrite
  if [ $? -ne 0 ]; then
    print_message "【ERROR】jdk安装失败，程序退出！"
    exit 1
  else
    jdk_home=$(find $WORKDIR -type d  -name "jdk-*")
    if [ -z "$jdk_home" ]; then
      print_message "【ERROR】 未找到java安装后的路径，程序退出！"
      exit 1
    fi
    ln -s $jdk_home/bin/java /usr/local/bin/java
    ln -s $jdk_home/bin/javac /usr/local/bin/javac
    print_message "【INFO】jdk安装成功，安装路径为$jdk_home！"
  fi

}

install_maven() {
  print_message "【INFO】正在安装maven，请稍等..."
  maven_url="https://mirrors.aliyun.com/apache/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz"
  curl -o $WORKDIR/apache-maven.tar.gz $maven_url
  tar -zxf $WORKDIR/apache-maven.tar.gz -C $WORKDIR --overwrite
  if [ $? -ne 0 ]; then
    print_message "【ERROR】maven安装失败，程序退出！"
    exit 1
  else
    maven_home=$(find $WORKDIR -type d  -name "apache-maven*")
    if [ -z "$maven_home" ]; then
      print_message "【ERROR】 未找到maven安装后的路径，程序退出！"
      exit 1
    fi
    ln -s $maven_home/bin/mvn /usr/local/bin/mvn
    print_message "【INFO】maven安装成功,安装路径为$maven_home！"
  fi
}

maven_settings() {
  maven_conf="$maven_home/conf/settings.xml"
  yes | cp $maven_conf $maven_home/conf/settings.xml_bak
  cat <<EOF > $maven_conf
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">
  <pluginGroups></pluginGroups>
  <proxies></proxies>
  <servers></servers>
  <mirrors>
    <mirror>
     <id>aliyunmaven</id>
     <mirrorOf>*</mirrorOf>
     <name>阿里云公共仓库</name>
     <url>https://maven.aliyun.com/repository/public</url>
    </mirror>
    <mirror>
      <id>maven-default-http-blocker</id>
      <mirrorOf>external:http:*</mirrorOf>
      <name>Pseudo repository to mirror external repositories initially using HTTP.</name>
      <url>http://0.0.0.0/</url>
      <blocked>true</blocked>
    </mirror>
  </mirrors>
  <profiles></profiles>
</settings>
EOF
}

install_mysql() {
  print_message "【INFO】正在下载mysql安装包，请稍等..."
  mysql_url="https://cdn.mysql.com/archives/mysql-8.0/mysql-8.0.36-linux-glibc2.17-x86_64.tar.xz"
  curl -o $WORKDIR/mysql.tar.xz $mysql_url
  tar -Jxf $WORKDIR/mysql.tar.xz -C $WORKDIR --overwrite
  if [ $? -ne 0 ]; then
    print_message "【ERROR】mysql安装失败，程序退出！"
    exit 1
  else
    mysql_home=$(find $WORKDIR -type d  -name "mysql-*")
    if [ -z "$mysql_home" ]; then
      print_message "【ERROR】 未找到mysql安装后的路径，程序退出！"
      exit 1
    fi
    mysql_bin_files=$(ls $mysql_home/bin)
    for file in $mysql_bin_files;do
       ln -s $mysql_home/bin/$file /usr/local/bin/$file
    done
    print_message "【INFO】mysql安装成功,安装路径为$mysql_home！"
  fi
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
ExecStart=/usr/local/bin/mysqld --daemonize --pid-file=$mysql_data_dir/mysqld.pid
LimitNOFILE = 5000
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF
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

start_mysql(){
  print_message "【INFO】正在创建mysql用户，请稍等..."
  id -u mysql > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    groupadd mysql
    useradd -s /sbin/nologin -r -g mysql mysql
  else
    print_message "【INFO】mysql用户已存在，跳过创建步骤！"
  fi

  if [ -d "$mysql_data_dir" ]; then
    rm -rf $mysql_data_dir
  fi
  mkdir -p $mysql_data_dir
  chown -R mysql:mysql $mysql_data_dir

  print_message "【INFO】正在初始化mysql数据库，请稍等..."
  mysqld --initialize --user=mysql
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

  mysqladmin -u root -p"$temp_passwd" --socket=$mysql_data_dir/mysql.sock password "$mysql_root_passwd"
  if [ $? -ne 0 ]; then
    print_message "【ERROR】修改mysql root密码失败，程序退出！"
    exit 1
  fi

  mysql -u root -p"$mysql_root_passwd" --socket=$mysql_data_dir/mysql.sock -e "CREATE DATABASE xxl_job CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
  mysql -u root -p"$mysql_root_passwd" --socket=$mysql_data_dir/mysql.sock -e "CREATE USER 'xxljob'@'%' IDENTIFIED BY 'Asdf.1234';"
  mysql -u root -p"$mysql_root_passwd" --socket=$mysql_data_dir/mysql.sock -e "GRANT ALL PRIVILEGES ON xxl_job.* TO 'xxljob'@'%';"
  mysql -u root -p"$mysql_root_passwd" --socket=$mysql_data_dir/mysql.sock -e "FLUSH PRIVILEGES;"
  if [ $? -ne 0 ]; then
    print_message "【ERROR】创建xxl_job数据失败，程序退出！"
    exit 1
  else
    print_message "【INFO】创建 xxl_job数据库，用户xxljob，密码 Asdf.1234 成功!"
  fi
}

xxl_job_script(){
  cat <<EOF > /usr/local/bin/xxl-job-admin.sh
#!/bin/bash
# 启动 xxl-job-admin 的脚本

# 定义 xxl-job-admin 主目录
XXL_JOB_HOME="$WORKDIR/xxl-job-$xxl_job_version"

# 定义 JAR 包路径
JAR_PATH="\$XXL_JOB_HOME/xxl-job-admin/target/xxl-job-admin-$xxl_job_version.jar"

# 定义 Java 启动参数
JAVA_OPTS="-Xms1g -Xmx1g"

# 定义日志输出目录
LOG_PATH="\$XXL_JOB_HOME/xxl-job-admin.log"

JAVA_CMD="/usr/local/bin/java"

# 启动 xxl-job-admin 并将日志输出到文件
nohup \$JAVA_CMD \$JAVA_OPTS -jar \$JAR_PATH > \$LOG_PATH 2>&1 &
echo \$! > \$XXL_JOB_HOME/xxl-job-admin.pid
echo "xxl-job-admin started."

EOF
  chmod +x /usr/local/bin/xxl-job-admin.sh
}

xxl_job_service() {
  cat <<EOF > /etc/systemd/system/xxl-job-admin.service
[Unit]
Description=XXL-JOB Admin Service
After=syslog.target network.target

[Service]
Type=forking
User=root
ExecStart=/usr/local/bin/xxl-job-admin.sh
ExecStop=/bin/kill -15 \$MAINPID
PIDFile=$WORKDIR/xxl-job-$xxl_job_version/xxl-job-admin.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF
}

install_xxl_job() {
  print_message "【INFO】正在下载xxl-job安装包，请稍等..."
  xxl_job_url="https://codeload.github.com/xuxueli/xxl-job/tar.gz/refs/tags/$xxl_job_version"
  curl -o $WORKDIR/xxl-job.tar.gz $xxl_job_url
  tar -zxf $WORKDIR/xxl-job.tar.gz -C $WORKDIR --overwrite
  if [ $? -ne 0 ]; then
    print_message "【ERROR】xxl-job解压失败，程序退出！"
    exit 1
  else
    xxl_job_home="$WORKDIR/xxl-job-$xxl_job_version"
    if [ ! -d "$xxl_job_home" ]; then
      print_message "【ERROR】 未找到xxl-job安装后的路径，程序退出！"
      exit 1
    fi

    print_message "【INFO】正在导入xxl-job数据库脚本，请稍等..."
    mysql -uroot -p$mysql_root_passwd --socket=$mysql_data_dir/mysql.sock xxl_job < $xxl_job_home/doc/db/tables_xxl_job.sql
    if [ $? -ne 0 ]; then
      print_message "【ERROR】 xxl-job数据库脚本执行失败，程序退出！"
      exit 1
    fi

    properties="$xxl_job_home/xxl-job-admin/src/main/resources/application.properties"
    sed -i "s|^spring.datasource.url=.*|spring.datasource.url=jdbc:mysql://127.0.0.1:3306/xxl_job?useUnicode=true\&characterEncoding=UTF-8\&autoReconnect=true\&serverTimezone=Asia\/Shanghai\&useSSL=false" $properties
    sed -i 's|^spring\.datasource\.username=.*|spring.datasource.username=xxljob|' $properties
    sed -i 's|^spring\.datasource\.password=.*|spring.datasource.password=Asdf.1234|' $properties
    if [ $? -ne 0 ]; then
      print_message "【ERROR】 xxl-job配置文件修改失败，程序退出！"
      exit 1
    fi

    cd $xxl_job_home
    print_message "【INFO】开始编译打包xxl-job，请稍等..."
    mvn clean package -Dmaven.test.skip=true
    if [ $? -ne 0 ]; then
      print_message "【ERROR】 xxl-job编译打包失败，程序退出！"
      exit 1
    fi

    print_message "【INFO】正在启动xxl-job-admin服务，请稍等..."
    xxl_job_script
    xxl_job_service
    systemctl daemon-reload
    systemctl enable xxl-job-admin
    systemctl start xxl-job-admin
    if [ $? -ne 0 ]; then
      print_message "【ERROR】 xxl-job-admin服务启动失败，程序退出！"
      exit 1
    else
      print_message "【INFO】xxl-job-admin服务启动成功, 工作目录为 $xxl_job_home！"
      print_message "【INFO】xxl-job-admin访问地址为 http://<your-server-ip>:8080/xxl-job-admin,默认用户名密码为 admin/123456"
    fi
  fi
}

run(){
  install_depend
  install_jdk
  install_maven
  maven_settings
  install_mysql
  my_cnf
  mysql_service
  start_mysql
  install_xxl_job
}

run