#!/bin/bash

jenkins_version="2.462.1"
WORKDIR="/opt/wmi"
jenkins_home="$WORKDIR/jenkins"
http_port="8080"
LOGPATH="/opt/wmi/jenkins_install.log"


print_message() {
    echo $1
    echo $1 >> $LOGPATH
}

install_depend() {
  mkdir -p $WORKDIR
  mkdir -p $jenkins_home
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
	     yum install fontconfig curl tar -y
       ;;
    "debian" | "ubuntu")
	     print_message "【INFO】当前OS为$OSRELEASE, 版本：$OSVERSION"
	     apt-get update
	     apt-get install fontconfig curl tar -y
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

add_user(){
  print_message "【INFO】正在创建Jenkins用户，请稍等..."
  id -u jenkins > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    groupadd jenkins
    useradd -r -g jenkins jenkins
  else
    print_message "【INFO】jenkins用户已存在，跳过创建步骤！"
  fi
}

install_jdk() {
  print_message "【INFO】正在安装JDK，请稍等..."
  jdk_url="https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.tar.gz"
  filepath="$WORKDIR/jdk-17_linux-x64_bin.tar.gz"
  curl -o $filepath $jdk_url
  tar -zxf $filepath -C $WORKDIR --overwrite

  if [ $? -ne 0 ]; then
    print_message "【ERROR】jdk 安装失败，程序退出！"
    exit 1
  else
    print_message "【INFO】JDK 安装成功！"
  fi
}

install_jenkins() {
    print_message "【INFO】正在下载Jenkins.war包，请稍等..."
    jenkins_url="https://mirror.twds.com.tw/jenkins/war-stable/$jenkins_version/jenkins.war"
    curl -o $jenkins_home/jenkins.war $jenkins_url

    if [ $? -ne 0 ]; then
      print_message "【ERROR】jenkins.war 下载失败，程序退出！"
      exit 1
    else
      print_message "【INFO】jenkins.war 下载成功！"
    fi

    curl -o /usr/bin/jenkins http://122.9.187.196:21666/jenkins/jenkins
    chmod +x /usr/bin/jenkins
    chown -R jenkins:jenkins $jenkins_home
}

jenkins_service(){
  cat << EOF > /etc/systemd/system/jenkins.service
[Unit]
Description=Jenkins Continuous Integration Server
Requires=network.target
After=network.target

[Service]
Type=notify
NotifyAccess=main
ExecStart=/usr/bin/jenkins
Restart=on-failure
SuccessExitStatus=143
User=jenkins
Group=jenkins
Environment="JENKINS_HOME=$jenkins_home"
WorkingDirectory=$jenkins_home
Environment="JENKINS_WAR=$jenkins_home/jenkins.war"
Environment="JENKINS_WEBROOT=$jenkins_home/war"
Environment="JENKINS_LOG=$jenkins_home/jenkins_output.log"
Environment="JAVA_HOME=$WORKDIR/jdk-17.0.12"
Environment="JENKINS_JAVA_CMD=$WORKDIR/jdk-17.0.12/bin/java"
Environment="JAVA_OPTS=-Djava.awt.headless=true"
Environment="JENKINS_PORT=$http_port"

[Install]
WantedBy=multi-user.target

EOF
}

run(){
  install_depend
  add_user
  install_jdk
  install_jenkins
  jenkins_service

  systemctl daemon-reload
  systemctl enable jenkins
  systemctl start jenkins

  if [ $? -ne 0 ]; then
    print_message "【ERROR】jenkins服务启动失败，程序退出！"
    exit 1
  else
    passwd=$(cat $jenkins_home/secrets/initialAdminPassword)
    print_message "【INFO】jenkins服务启动成功！初始密码：$passwd"
  fi
}

run