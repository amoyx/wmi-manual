#!/bin/bash


# 检查包是否安装
function check_package_install(){
  result=0
  if [ "$#" -lt 1 ]; then
    msg="[ERROR] 至少传递一个参数"
	echo $msg
    echo $msg >> $LOGPATH		
    return 1
  fi
  case $OSRELEASE in
    "centos" | "rhel" | "fedora" | "tencentos")
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
      "centos" | "rhel" | "fedora" | "tencentos")
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
	else
	  msg="【INFO】基础依赖工具安装成功！"
	  echo $msg
      echo $msg >> $LOGPATH	  
	fi
  fi
}

# uncompress 解压缩文件
function uncompress() {
  filename=$1
  if [ ! -f "$filename" ]; then
    msg="【ERROR】$filename文件不存在，请检查路径是否正确!"
	echo $msg
    echo $msg >> $LOGPATH	
	exit 1
  fi 
  ext=$(echo $filename | awk -F'.' '{print $NF}')
  case $ext in 
    "zip")
	  unzip -o -d $WORKDIR $filename
	  ;;
	"gz" | "tgz")
	  tar -zxf $filename -C $WORKDIR --overwrite-dir
	  ;;
	"bz2" | "bz")
	  tar -jxf $filename -C $WORKDIR --overwrite-dir
	  ;;	
	"Z")
	  tar -Zxf $filename -C $WORKDIR --overwrite-dir
	  ;;	  
	*)
      msg="【ERROR】未识别到你的文件类型，请检查$filename是否压缩文件！"
	  echo $msg
      echo $msg >> $LOGPATH	  
	  exit 1
      ;;
  esac
  
  if [ $? -ne 0 ]; then
	msg="【ERROR】软件包${filename}解压失败，程序退出！"
	echo $msg
    echo $msg >> $LOGPATH	 	
	exit 1
  fi
}

function install_jdk() {
  uncompress $jdk_path
  home=$(find $WORKDIR  -type d -name "jdk*"  -cmin -60|awk 'NR==1 {print $0}')
  if [ -n "$home" ] && [ -d $home ]; then
     java_home=$home
     echo "export JAVA_HOME=${home}" >> ~/.bash_profile
	 echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> ~/.bash_profile
  fi
}

function install_nacos() {
  uncompress $nacos_path
  home=$(find $WORKDIR  -type d -name "nacos*"  -cmin -60|awk 'NR==1 {print $0}')
  sed -i "2a JAVA_HOME=${java_home}" $home/bin/startup.sh
  yes | cp $WORKDIR/application.properties $home/conf/application.properties
  if [ "$deploy_mode" = "cluster" ]; then
    yes | cp $WORKDIR/cluster.conf $home/conf/cluster.conf
  fi
  yes | cp $WORKDIR/nacos.service /etc/systemd/system/nacos.service
}


function run() {
  install_depend
  install_jdk
  install_nacos
  systemctl daemon-reload
  systemctl start nacos
}

run
if [ $? -ne 0 ]; then
   msg="【ERROR】Nacos服务安装失败，程序退出！"
   echo $msg
   echo $msg >> $LOGPATH	
   exit 1
else
   msg="【INFO】Nacos服务安装成功！"
   echo $msg
   echo $msg >> $LOGPATH
fi
