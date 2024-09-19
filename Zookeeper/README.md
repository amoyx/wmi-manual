# Zookeeper部署说明
本部署手册是帮助你快速在你的电脑上，下载安装并使用Zookeeper分布式协调服务，也可参考官方文档部署. [Zookeeper官方文档](https://zookeeper.apache.org/releases.html)

### Zookeeper集群架构图
<img alt="zookeeper-cluster-mode" src="../pics/zookeeper_cluster_mode.jfif">

### 一、Zookeeper环境搭建

###### 注：本文以Centos7系统上搭建Zookeeper 3.9.2 版本环境，如果是其他操作系统，请参考[官方文档](https://zookeeper.apache.org/releases.html)部署

#### 1.1 准备工作
在部署zookeeper 之前，需要确保以下环境和依赖已经安装和配置：
* 操作系统：Linux (CentOS, Ubuntu)
* Java 版本：JDK 1.8+
* Zookeeper版本：选择合适的稳定<b>[版本](https://archive.apache.org/dist/zookeeper/)</b>
* Zookeeper 的集群通常由3台或5台服务器组成（为了保证容错能力，Zookeeper集群最好使用奇数台服务器);假设本次实验(192.168.10.11，192.168.10.12，192.168.10.13)

####  1.2 安装Java环境
在192.168.10.11，192.168.10.12，192.168.10.13上执行
```
# yum install java-1.8.0-openjdk
# java -version
```

#### 1.3 安装Zookeeper
在192.168.10.11，192.168.10.12，192.168.10.13上执行
```
# mkdir /opt && cd /opt
# wget https://archive.apache.org/dist/zookeeper/zookeeper-3.9.2/apache-zookeeper-3.9.2-bin.tar.gz
# tar -zxvf apache-zookeeper-3.9.2-bin.tar.gz

# vi /opt/apache-zookeeper-3.9.2-bin/conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper  # 这是存储数据的目录，可以自定义路径
clientPort=2181
initLimit=10
syncLimit=5

#集群配置
server.1=192.168.10.11:2888:3888
server.2=192.168.10.12:2888:3888
server.3=192.168.10.13:2888:3888

为每个节点设置myid
# echo "1" > /var/lib/zookeeper/myid  # 仅在192.168.10.11 服务器上
# echo "2" > /var/lib/zookeeper/myid  # 仅在192.168.10.12 服务器上
# echo "3" > /var/lib/zookeeper/myid  # 仅在192.168.10.13 服务器上

启动服务
# /opt/apache-zookeeper-3.9.2-bin/bin/zkServer.sh start

也可以制作成系统服务
# vi /etc/systemd/system/zookeeper.service
[Unit]
Description=Zookeeper
After=network.target

[Service]
Type=forking
ExecStart=/opt/apache-zookeeper-3.9.2-bin/bin/zkServer.sh start
ExecStop=/opt/apache-zookeeper-3.9.2-bin/bin/zkServer.sh stop
ExecReload=/opt/apache-zookeeper-3.9.2-bin/bin/zkServer.sh restart
User=root
Group=root
Restart=on-failure

[Install]
WantedBy=multi-user.target

启动服务
# systemctl daemon-reload
# systemctl start zookeeper
# systemctl enable zookeeper
```

## 二、脚本安装
本文提供了shell脚本一键安装，先下载脚本install.sh，然后执行脚本，脚本会自动安装zookeeper集群.

### 2.1 脚本执行前准备
* 需要提前配置好SSH免密登录，且保证节点间的操作系统一致
* 需要用root管理员用户执行该脚本，执行过程中会创建相应用户，避免因为权限导致脚本执行失败
* 确保2888,3888,2181 端口没有被占用，避免因为端口冲突导致apollo安装失败
* 如果不配置IPLIST，则单机部署(部署在执行节点),如果是配置了，则部署集群（部署在IPLIST的IP节点）

### 2.2 脚本中变量说明
```
zookeeper_version="3.9.2"   # 必填，zookeeper版本
IPLIST="192.168.10.11;192.168.10.12;192.168.10.13" # （非必填，不填写表示单机部署，填写为集群部署） zookeeper集群IP列表, 多个IP用分号隔开,至少3个节点，需要填写奇数，如3,5,7,9...
WORKDIR="/opt/wmi"   # 必填，工作目录，默认为/opt/wmi
LOGPATH="$WORKDIR/zk_install.log"  # 必填，日志文件
script="$WORKDIR/zk_install.sh"  # 必填，脚本文件，最好不要修改
eth="ens192"             # 必填，网卡名称，默认为ens192
```

### 2.3 脚本执行
+ 1）下载install.sh脚本，最好是下载到一个单独的目录中，执行过程中会生成一些临时文件，以便执行完毕后清理.
+ 2）修改install.sh脚本中变量的值，根据你自己的实际场景修改配置
+ 3）给脚本执行权限 chmod +x install.sh，执行脚本 bash install.sh
