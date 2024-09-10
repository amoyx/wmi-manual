#!/bin/bash

IPLIST="192.168.10.11;192.168.10.12"
VIP="192.168.10.100"
WORKDIR="/opt/wmi"
LOGPATH="$WORKDIR/openresty_install.log"


print_message() {
    echo $1
    echo $1 >> $LOGPATH
}

mkdir -p $WORKDIR

  cat << 'EOF' > $WORKDIR/install_openresty.sh
#!/bin/bash

OSRELEASE=""
OSVERSION=""

EOF

  cat << 'EOF' >> $WORKDIR/install_openresty.sh

check_os() {

  OSRELEASE=$(awk -F'"' '/^ID=/ {print $2}' /etc/os-release)
  OSVERSION=$(awk -F'"' '/^VERSION_ID=/ {print $2}' /etc/os-release)

  if [ -z "$OSRELEASE" ]; then
    OSRELEASE=$(awk -F'=' '/^ID=/ {print $2}' /etc/os-release)
  fi

  if [ -z "$OSVERSION" ]; then
    OSVERSION=$(awk -F'=' '/^VERSION_ID=/ {print $2}' /etc/os-release)
  fi

  if [ $? -ne 0 ]; then
    echo "【ERROR】检测操作系统类型失败，程序退出！"
    exit 1
  fi

  echo "【INFO】当前OS为$OSRELEASE, 版本：$OSVERSION"
}

EOF

  cat << 'EOF' >> $WORKDIR/install_openresty.sh

install() {
  openresty_url="http://openresty.org"
  os_version=$(echo "$OSVERSION" |awk -F'.' '{print $1}')
  pubkey_url="https://openresty.org/package/pubkey.gpg"
  openresty_list="/etc/apt/sources.list.d/openresty.list"
  case $OSRELEASE in
    "fedora")
  	  dnf install -y dnf-plugins-core
  	  dnf config-manager --add-repo https://openresty.org/package/fedora/openresty.repo
  	  dnf install -y openresty keepalived
      ;;
    "alios")
      wget -O /etc/yum.repos.d/openresty.repo https://openresty.org/package/alinux/openresty.repo
      yum install -y openresty keepalived
      ;;
    "tencentos")
      wget -O /etc/yum.repos.d/openresty.repo https://openresty.org/package/tlinux/openresty.repo
      yum install -y openresty keepalived
      ;;
    "centos" | "rhel")
      if [ $os_version -ge 9 ]; then
        wget -O /etc/yum.repos.d/openresty.repo  https://openresty.org/package/$OSRELEASE/openresty2.repo
      else
        wget -O  /etc/yum.repos.d/openresty.repo https://openresty.org/package/$OSRELEASE/openresty.repo
      fi
      yum install -y openresty keepalived
      ;;
    "ubuntu")
      apt-get -y install --no-install-recommends wget gnupg ca-certificates lsb-release
      if [ $os_version -ge 22 ]; then
        openresty_gpg="/usr/share/keyrings/openresty.gpg"
        wget -O - $pubkey_url | sudo gpg --dearmor -o $openresty_gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=$openresty_gpg] $openresty_url/package/ubuntu $(lsb_release -sc) main" | sudo tee $openresty_list > /dev/null
      else
        wget -O - $pubkey_url | sudo apt-key add -
        echo "deb $openresty_url/package/ubuntu $(lsb_release -sc) main" | sudo tee $openresty_list
      fi
      sudo apt-get update
      sudo apt-get -y install openresty keepalived
      ;;
    "debian")
      if [ $os_version -ge 12 ]; then
        wget -O - $pubkey_url | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/openresty.gpg
      else
        wget -O - $pubkey_url | sudo apt-key add -
      fi
      codename=`grep -Po 'VERSION="[0-9]+ \(\K[^)]+' /etc/os-release`
      echo "deb $openresty_url/package/debian $codename openresty" | sudo tee $openresty_list
      sudo apt-get update
      sudo apt-get -y install openresty keepalived
      ;;
    *)
      print_message "【ERROR】本脚本不支持你的操作系统 $OSRELEASE，请自行查看官方文档安装！"
      exit 1
      ;;
  esac

  if [ $? -ne 0 ]; then
    echo "【ERROR】安装openresty或keepalived失败，程序退出！"
    exit 1
  else
    echo "【INFO】安装openresty和keepalived成功！"
  fi

  yes | cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf_bak
  yes | cp /tmp/keepalived.conf /etc/keepalived/keepalived.conf

  which systemctl

  if [ $? -eq 0 ]; then
    systemctl start keepalived
    systemctl enable keepalived
  else
    service keepalived start
  fi

  if [ $? -eq 0 ]; then
    echo "【INFO】 keepalived启动成功，程序执行Success！"
  else
     echo "【ERROR】 keepalived启动失败，程序退出！"
     exit 1
  fi

  which systemctl
  if [ $? -eq 0 ]; then
    systemctl start openresty
    systemctl enable openresty
  else
    service openresty start
  fi

  if [ $? -eq 0 ]; then
    echo "【INFO】 openresty启动成功，程序执行Success！"
    exit 0
  else
     echo "【ERROR】openresty启动失败，程序退出！"
     exit 1
  fi

}

check_os
install

EOF

keepalived_config() {
  IFS=';'
  num=1
  for ip in $IPLIST; do
    if [ $num -eq 1 ]; then
      state="MASTER"
      priority="110"
    else
      state="BACKUP"
      priority="90"
    fi
  cat << EOF > $WORKDIR/keepalived.conf
! Configuration File for keepalived
global_defs {
  router_id LVS_DEVEL
}

vrrp_instance VI_1 {
    state $state       # 设置为 MASTER 或 BACKUP
    interface ens192   # 绑定到的网络接口名称
    virtual_router_id 101  # VRRP 路由器 ID，主备需相同
    priority $priority            # 优先级，MASTER 设置较高值，BACKUP 设置较低值
    advert_int 1           # 广播间隔
    authentication {
        auth_type PASS     # 验证类型，可以是 PASS 或 AH
        auth_pass 1111     # 验证密码，主备需相同
    }
    virtual_ipaddress {
       $VIP       # 虚拟IP地址
    }
}

EOF
  num=$((num+1))

  scp $WORKDIR/keepalived.conf root@$ip:/tmp/keepalived.conf

  done
}

run() {
  keepalived_config
  for ip in $IPLIST; do
    scp $WORKDIR/install_openresty.sh root@$ip:/tmp/install_openresty.sh
    ssh root@$ip "chmod +x /tmp/install_openresty.sh && bash /tmp/install_openresty.sh"
    if [ $? -eq 0 ]; then
      echo "【INFO】 $ip openresty安装成功！"
    else
      echo "【ERROR】 $ip openresty安装失败！"
    fi
  done
}

run