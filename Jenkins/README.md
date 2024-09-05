# Jenkins部署说明
本说明书将指导您如何在Linux操作系统上 <b>[下载](https://get.jenkins.io/war-stable/)</b> 安装并使用Jenkins，也可参考官方文档部署. [Jenkins官方文档](https://www.jenkins.io/doc/book/installing/)

### 1. 准备工作
#### 1.1 系统要求
* 操作系统：Linux（CentOS、Ubuntu、Debian 等），Jenkins几乎支持所有操作系统，可查看支持的[操作系统](https://www.jenkins.io/download/)
* Java：Jenkins 需要 Java 运行时环境（JRE），最新的Jenkins大多数版本仅支持Java 11 ，Java 17，Java 21；安装时选择合适java版本。

#### 1.2 安装 Java
CentOS/RHEL系统
```
# yum install fontconfig java-17-openjdk -y
```
Debian/Ubuntu系统
```
# apt-get update
# apt-get install fontconfig openjdk-17-jre -y
```
验证安装,确保 Java 版本符合 Jenkins 的要求
```
# java -version
```

### 2.安装 Jenkins
#### 2.1 添加 Jenkins 软件源
Jenkins 官方提供了安装软件包的 Yum/Apt 仓库，您需要先添加 Jenkins 仓库，然后再使用包管理器安装。<br>
对于 CentOS/RHEL：
```
# wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
```
对于 Debian/Ubuntu:
```
# wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

# echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
    
```

#### 2.2 安装 Jenkins
对于 CentOS/RHEL
```
查看jenkins版本
# yum --showduplicates list jenkins

安装指定jenkins版本
# yum install jenkins-2.462.1 -y

默认安装的是最新版本
# yum install jenkins -y     
```
对于 Debian/Ubuntu：
```
查看jenkins版本
# apt-cache showpkg jenkins

安装jenkins
# apt update
# apt-get install jenkins -y
```

#### 2.3 配置修改
```
# vi /usr/lib/systemd/system/jenkins.service
Environment="JENKINS_HOME=/var/lib/jenkins"  # jenkins home目录，所有jenkins产生的数据都保存在此目录下，默认为/var/lib/jenkins
Environment="JAVA_HOME=/usr/local/java-17-openjdk"      # java home目录
Environment="JENKINS_JAVA_CMD=/usr/local/java-17-openjdk/bin/java" # java命令的路径
Environment="JENKINS_PORT=8080"  # 监听的端口,默认为8080
```

#### 2.4 启动 Jenkins 服务
```
# systemctl start jenkins
# systemctl enable jenkins

查看jenkins服务状态
#systemctl status jenkins 
```

### 三、配置 Jenkins

#### 3.1 访问 Jenkins Web 界面
打开浏览器，访问 Jenkins Web 界面。默认情况下，Jenkins 运行在端口 8080：
```
http://<your-server-ip>:8080
```

#### 3.2 解锁 Jenkins
第一次访问 Jenkins 时，它会要求输入初始管理员密码。该密码存储在 /var/lib/jenkins/secrets/initialAdminPassword 文件中;如果你更改了Jenkins 的默认安装目录，那么这个文件路径也会改变。
```
# cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### 3.3 完成安装
* 在解锁后，Jenkins 会提示安装插件。建议选择 “Install suggested plugins” 以安装推荐的插件集。
* 插件安装完成后，创建一个新的管理员用户。填写用户名、密码和电子邮件等信息，然后点击 “Save and Continue”。
* 设置 Jenkins 的 URL（通常保持默认即可），然后点击 “Save and Finish”。
* Jenkins 将显示安装完成页面。点击 “Start using Jenkins”，进入 Jenkins 的主界面。

#### 3.4 配置Slave从节点
当你想将
系统管理 -> Manage Nodes（节点管理） -> New Node(新建节点)，配置节点信息，如名称、描述、任务并发数、标签、远程工作目录、启动方式等

节点两种启动方式：
* 1.通过Java Web启动代理
需要在客户端上安装agent
```
下载anget.jar包，<your-server-ip> 就是Jenkins的IP
# curl -sO http://<your-server-ip>:8080/jnlpJars/agent.jar

# java -jar agent.jar -url http://<your-server-ip>:8080 -secret 生成的密钥 -name 创建节点时的名称 -workDir "/data/jenkins"
```

* 2.Launch agent via SSH (通过SSH启动代理)
```
# 需要配置 主机名，端口，java 路径，密钥等信息
```

## 四、脚本安装
本文提供了shell脚本一键安装，先下载脚本install.sh，然后执行脚本，脚本会自动安装Jenkins.

### 4.1 脚本执行注意事项
* 需要root用户执行脚本，执行过程中会创建jenkins用户，避免权限不足执行失败.
* 请确保已配置软件源，能正常安装 fontconfig，curl，tar包即可.
* 脚本执行过程中，会安装jdk17，下载jenkins.war包，安装时间有点长，请耐心等待.

### 4.2 脚本中变量说明
Jenkins <b>[版本](https://get.jenkins.io/war-stable/)</b> 查看
```
jenkins_version="12.10.0"                  # 必填，jenkins安装版本，如 2.462.1 2.452.2 2.401.2等；
jenkins_home="/var/lib/jenkins"            # 必填，jenkins安装和数据存储目录
http_port="8080"                           # 必填，jenkins服务监听端口
```

### 4.3 脚本执行
+ 1）下载install.sh脚本，最好是下载到一个单独的目录中，执行过程中会生成一些临时文件，以便执行完毕后清理.
+ 2）修改install.sh脚本中变量的值，根据你自己的实际场景修改配置
+ 3）给脚本执行权限 chmod +x install.sh，执行脚本 bash install.sh
