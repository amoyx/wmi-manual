#!/bin/bash

gitlab_version="12.10.0"                  # gitlab-ce版本，如 10.2.8 12.10.0 15.3.2 16.1.6 17.0.6等；
external_url="http://gitlab.mydomain.cn"  # 访问GitLab的域名，如 http://gitlab.yourdomain.com
LOGPATH="gitlab_install.log"              # 日志路径

# 消息
print_message() {
  echo $1
  echo $1 >> $LOGPATH
}

deploy() {
  if [ -z "$gitlab_version" ]; then
    print_message "【ERROR】GitLab版本不能为空，请配置GitLab版本，如10.2.8 12.10.0 15.3.2 等"
    exit 1
  fi

  if [ -z "$external_url" ]; then
    print_message "【ERROR】external_url不能为空，请配置external_url域名地址，如http://gitlab.mydomain.cn"
    exit 1
  fi

  os_release=$(awk -F'"' '/^ID=/ {print $2}' /etc/os-release)
  os_version=$(awk -F'"' '/^VERSION_ID=/ {print $2}' /etc/os-release)

  if [ -z "$os_release" ]; then
    os_release=$(awk -F'=' '/^ID/ {print $2}' /etc/os-release)
  fi

  if [ -z "$os_version" ]; then
    os_version=$(awk -F'=' '/^VERSION_ID/ {print $2}' /etc/os-release)
  fi

  case $os_release in
    "centos" | "rhel" | "debian" | "ubuntu" | "alios" | "tencentos")
	     msg="【INFO】当前OS为$os_release, 版本：$os_version"
       ;;
    *)
       msg="【ERROR】不支持的操作系统类型 $os_release!, 版本为$os_version，程序退出!"
       print_message $msg
       exit 1
       ;;
  esac

  print_message "【INFO】开始配置及安装gitlab-ce，请耐心等待...."

  if [ "$os_release" = "ubuntu" ] || [ "$os_release" = "debian" ]; then
     curl -o script.deb.sh https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh
     chmod +x script.deb.sh
     bash script.deb.sh
     if [ $? -ne 0 ]; then
        print_message "【ERROR】deb源安装失败，程序退出！"
        exit 1
     fi

     apt-get update
     apt-get install -y gitlab-ce-${gitlab_version}
  else
    curl -o script.rpm.sh  https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh
    chmod +x script.rpm.sh
    bash script.rpm.sh

    if [ $? -ne 0 ]; then
       print_message "【ERROR】yum源安装失败，程序退出！"
       exit 1
    fi

    yum makecache
    yum install -y gitlab-ce-${gitlab_version}
  fi

  if [ $? -ne 0 ]; then
     print_message "【ERROR】gitlab-ce安装失败，程序退出！"
     exit 1
  fi

  yes | cp /etc/gitlab/gitlab.rb /etc/gitlab/gitlab.rb_bak

cat << EOF > /etc/gitlab/gitlab.rb

external_url '${external_url}'

EOF

  gitlab-ctl reconfigure

  if [ $? -ne 0 ]; then
     print_message "【ERROR】gitlab-ce启动失败，程序退出！"
     exit 1
  else
     passwd=$(cat /etc/gitlab/initial_root_password |grep 'Password:'|awk '{print \$NF}')
     print_message "【INFO】gitlab-ce start successfully，安装完成！"
     print_message "【INFO】登录用户名：root，初始密码：$passwd"
  fi
}

deploy