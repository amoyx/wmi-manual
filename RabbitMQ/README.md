# RabbitMQ部署说明
本部署手册是帮助你快速在你的电脑上，下载安装并使用RabbitMQ，也可参考官方文档部署. [RabbitMQ官方文档](https://www.rabbitmq.com/docs)

由于RabbitMQ的是基于Erlang语言开发，因此安装RabbitMQ之前，需要安装Erlang环境，Erlang环境安装教程可参考 [Erlang安装文档](https://www.rabbitmq.com/docs/which-erlang)

RabbitMQ版本众多，同时Erlang版本也非常多，每个版本的Erlang都对应不同的RabbitMQ版本，因此安装RabbitMQ之前，需要确定你的Erlang版本，避免因为版本不匹配导致RabbitMQ无法启动。

RabbitMQ版本对应Erlang版本，可参考 [Erlang版本对应RabbitMQ版本](https://www.rabbitmq.com/docs/which-erlang) 部分RabbitMQ版本对应Erlang版本

<table>
  <thead>
    <tr>
	  <td>RabbitMQ</td>
      <td>3.8.30</td>
      <td>3.10.20</td>
      <td>3.11.8</td>
       <td>3.12.10</td>
      <td>3.13.6</td>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Erlang</td>
      <td>最低23.2版本<br>最高 24.3版本</td>
      <td>最低24.3.4.8版本<br>最高25.3.x版本</td>
      <td>最低25.0版本<br>最高25.3.x版本</td>
      <td>最低25.0版本<br>最高26.2.x版本</td>
      <td>最低26.0版本<br>最高26.2.x版本</td>
    </tr>
  </tbody>
</table>

### 安装包下载地址 

Erlang安装脚本，这种方式安装erlang非常简单，但是需要翻墙，如果不能科学上网，不建议使用.  [Erlang安装脚本](https://github.com/kerl/kerl) 

Erlang rpm&deb包下载 [Erlang包下载](https://www.erlang-solutions.com/downloads/#)

RabbitMQ二进制&rpm&deb包下载 [RabbitMQ包下载](https://github.com/rabbitmq/rabbitmq-server/releases)

RabbitMQ&Erlang(yum&apt)源配置文档 [官方RabbitMQ镜像源配置](https://www.rabbitmq.com/docs/install-debian)

RabbitMQ&Erlang(yum&apt)源配置本地下载，各Linux发行版本对应的源文件放在repo目录下，[本地下载](repo/rabbitmq_el7.repo) 

## RabbitMQ集群环境部署

###### 本文以Centos7系统上安装RabbitMQ 3.8.30版本为例，其他RabbitMQ版本和Linux发行版本，请参考官方文档部署

RabbitMQ大致有四种部署方式，源码方式部署、二进制文件方式部署、rpm|deb包方式部署、yum|apt镜像源方式部署，建议选择yum|apt镜像源方式部署，因为yum|apt镜像源方式部署，可选择的版本较多，另外安装时也无需关心依赖包.
+ 1）基于二进制文件方式部署,一般都是tar,zip，xz包；解压缩后，配置环境变量，然后执行./rabbitmq-server命令启动RabbitMQ
+ 2）基于源码方式部署，一般都是tar,zip，xz包；解压缩后，执行./configure命令，然后执行make命令，make install命令，然后配置环境变量，然后执行./rabbitmq-server命令启动RabbitMQ
+ 3）基于rpm|deb包方式部署，一般都是rpm,deb包；去官方下载rpm,deb包文件，然后执行rpm -ivh rabbitmq-server-***命令，或执行dpkg -i rabbitmq-server-***命令，最后执行./rabbitmq-server命令启动RabbitMQ
+ 4）基于yum|apt镜像源方式部署，配置；执行yum install rabbitmq-server命令，或执行apt install rabbitmq-server命令，通过yum|apt安装的rabbitmq，一般都生成了系统服务，可通过 systemctl start rabbitmq-server命令启动RabbitMQ

### 1.前置条件说明
+ 1.1 为了确保 RabbitMQ集群的稳定性和高可用性，最好使用3个或3个以上节点
+ 1.2 确保集群中节点都配置了镜像仓库源，能正常用yum、apt指令安装软件
+ 1.3 确保所有节点安装的Erlang和RabbitMQ版本一致
+ 1.4 确保所有节点的系统时间一致
+ 1.5 确保所有节点彼此之间能通信，关闭了selinux，关闭防火墙
+ 1.6 确保所有节点 5672，15672，25672 端口没有被占用

### 2.Erlang安装
rabbitmq集群的所有节点都需要安装Erlang环境，一定要注意版本
```
首先导入签名密钥，签名密钥文件放在key目录中，自行下载到安装的节点
# rpm --import rabbitmq-release-signing-key.asc
# rpm --import cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
# rpm --import cloudsmith.rabbitmq-server.9F4587F226208342.key

# cat /etc/os-release                // 查看系统发行版本
# curl -o /etc/yum.repos.d/rabbitmq.repo https://raw.githubusercontent.com/amoyx/wmi-manual/main/repo/rabbitmq_el7.repo // 下载镜像源配置文件   
# yum --showduplicates list erlang    // 查看Erlang可安装版本
# yum install erlang-24.2-1.el7    // 安装Erlang 24.2-1 版本
```

### 3.RabbitMQ安装
rabbitmq集群的所有节点都需要安装RabbitMQ环境，一定要注意版本
```
# yum --showduplicates list rabbitmq-server    // 查看rabbitmq可安装版本
# yum install rabbitmq-server-3.8.30-1.el7    // 安装RabbitMQ 3.8.30-1 版本
# systemctl start rabbitmq-server    // 启动rabbitmq服务
# systemctl status rabbitmq-server    // 查看rabbitmq服务状态
# systemctl enable rabbitmq-server  // 设置开机启动rabbitmq服务
# systemctl stop rabbitmq-server    // 停止rabbitmq服务

# rabbitmq-plugins list      // 查看rabbitmq插件列表, [E*] 表示该插件已启用,[E ] 表示该插件未启用
# rabbitmq-plugins enable rabbitmq_management  // 启用rabbitmq_management插件
# rabbitmqctl add_user admin abc123  // 添加用户admin, 密码为abc123 
# rabbitmqctl set_user_tags admin administrator  // 为用户分配管理权限
```
安装后，可访问web管理界面地址：http://ip:15672，用户名：admin，密码：abc123

### 4.RabbitMQ集群配置
```
配置主机名称解析
# vi /etc/hosts
192.168.10.11 rabbit1
192.168.10.12 rabbit2
192.168.10.13 rabbit3

配置Erlang Cookie, 所有节点必须一致
# cat /var/lib/rabbitmq/.erlang.cookie
# scp /var/lib/rabbitmq/.erlang.cookie rabbit2:/var/lib/rabbitmq/.erlang.cookie
# scp /var/lib/rabbitmq/.erlang.cookie rabbit3:/var/lib/rabbitmq/.erlang.cookie
# chmod 400 /var/lib/rabbitmq/.erlang.cookie   // 确保文件权限为 400
# systemctl restart rabbitmq-server   // 重启rabbitmq服务

将节点加入集群，假设主节点为rabbit1，其他节点需要加入到rabbit1节点的集群中，在rabbit2和rabbit3节点执行以下命令
# rabbitmqctl stop_app
# rabbitmqctl reset
# rabbitmqctl join_cluster rabbit@rabbit1
# rabbitmqctl start_app

检查集群状态
# rabbitmqctl cluster_status
```

## 脚本安装
本文提供了shell脚本一键安装，支持RabbitMQ单机版和集群版安装，先下载脚本install.sh，然后执行脚本，脚本会自动下载rabbitmq，并自动配置集群.

### 1.1 脚本执行前准备
+ 1）需要确保集群中所有节点时间一致
+ 2）确保集群中节点都配置了镜像仓库源，能正常用yum指令安装软件
+ 3）确保主机名称(hostname)对应的hosts文件列表一致
+ 4）确保集群中节点网络互通，同时能够访问镜像仓库
+ 5）确保启动了SSH服务，最好是提前配置了SSH免密登录
+ 6）本脚本仅支持Centos7系统，rabbitmq仅支持3.10.20,3.11.8,3.12.10,3.13.6版本安装，其他版本需自行修改脚本

### 1.2 脚本中变量说明
```
iplist="192.168.100.11 192.168.100.12 192.168.100.13" # 集群ip列表，必须3个节点
sshuser="root"    # ssh用户名
sshpasswd="password"  # ssh密码
rabbitmq_version="3.11.8"   # rabbitmq版本，仅支持3.10.20,3.11.8,3.12.10,3.13.6；
deploy_mode="cluster" # 部署模式,cluster集群模式,standalone单机模式
WORKDIR="/opt/wmi"    # 工作目录
LOGPATH="${WORKDIR}/rabbitmq_install.log"  #日志路径

OSRELEASE=""   # 操作系统发行服务商，无需填写
OSVERSION=""   # 操作系统发行版本，无需填写
rabbitmq_path="" # rabbitmq_path, rabbitmq安装包的路径，可以不填写; 如果要填写必须和rabbitmq_version相匹配
erlang_path=""  # erlang_path, erlang安装包的路径，可以不填写; 如果要填写必须和rabbitmq版本匹配
```

### 1.3 脚本执行
+ 1）下载install.sh脚本，最好是下载到一个单独的目录中，执行过程中会生成很多临时文件，以便执行完毕后清理.
+ 2）修改install.sh脚本中变量的值，根据你自己的实际场景修改配置
+ 3）给脚本执行权限 chmod +x install.sh，执行脚本 bash install.sh
