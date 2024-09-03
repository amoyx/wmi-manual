# GitLab部署说明
本部署手册是帮助你快速在你的电脑上，<b>[下载](https://packages.gitlab.com/gitlab/gitlab-ce)</b> 安装并使用GitLab，也可参考官方文档部署. [GitLab官方文档](https://docs.gitlab.cn/jh/install/requirements.html)

GitLab 提供了两个主要版本：GitLab Community Edition (gitlab-ce) 和 GitLab Enterprise Edition (gitlab-ee),以下是它们的主要区别：

<table>
    <thead>
      <tr>
        <th>特性</th>
        <th>GitLab CE (Community Edition)</th>
        <th>GitLab EE (Enterprise Edition)</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>许可证</td>
        <td>开源 (MIT)</td>
        <td>商业（带有高级许可）</td>
      </tr>
    </tbody>
    <tbody>
      <tr>
        <td>基本功能</td>
        <td>包括</td>
        <td>包含 CE 所有功能</td>
      </tr>
    </tbody> 
    <tbody>
      <tr>
        <td>高级安全功能</td>
        <td>不提供</td>
        <td>提供 (如容器和依赖项扫描)</td>
      </tr>
    </tbody>
    <tbody>
      <tr>
        <td>高级 CI/CD 功能</td>
        <td>基本支持</td>
        <td>提供更高级的 CI/CD 管理功能</td>
      </tr>
    </tbody>
    <tbody>
      <tr>
        <td>集成与管理</td>
        <td>基本集成和用户管理</td>
        <td>提供高级集成、用户和组管理</td>
      </tr>
    </tbody>     
    <tbody>
      <tr>
        <td>支持</td>
        <td>社区支持</td>
        <td>官方支持（付费）</td>
      </tr>
    </tbody> 
    <tbody>
      <tr>
        <td>使用场景</td>
        <td>个人、开源项目、小型团队</td>
        <td>大型团队、企业、组织</td>
      </tr>
    </tbody> 
  </table>

#### 选择哪一个?
GitLab-CE：适合需要基本 DevOps 功能的小型团队、开源项目和个人用户，免费使用。

GitLab-EE：适合需要高级功能、企业级支持以及高安全性要求的大型企业和组织，付费使用。

#### 操作系统支持？
GitLab并不支持所有操作系统，安装前先查看官方文档，目前查询到的支持的操作系统有：
* Ubuntu
* Debian
* AlmaLinux
* CentOS
* OpenCloudOS
* Alibaba Cloud Linux
* Kylin
* OpenEuler
* 不支持：Arch Linux，Fedora，FreeBSD，Gentoo，macOS，Windows

#### 安装需求
* Gitlab 依赖 PostgreSQL，Redis，Nginx
* 由于组件较多，最好准备一台 CPU 4核、8GB+内存、100G+磁盘的服务器
* Gitlab 占用的端口比较多，最好用一台干净的服务器，以免安装时造成端口冲突
* 查看gitlab-ce有哪些 <b>[版本](https://packages.gitlab.com/gitlab/gitlab-ce)</b>

## 一、Gitlab环境搭建
###### 本文以Centos7系统上安装GitLab-CE 16.11.8版本为例，gitlab-ce版本非常多，如果想安装其他版本，请查看官方文档
### 1.1 安装gitlab-ce
```
安装yum源
# curl -o script.rpm.sh  https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh
# chmod +x script.rpm.sh
# bash script.rpm.sh
# ls /etc/yum.repos.d/gitlab_gitlab-ce.repo   检查是否生成该文件

查看可安装的gitlab-ce版本
# yum --showduplicates list gitlab-ce   

安装 gitlab-ce
# yum install gitlab-ce-16.11.8 -y
```
### 1.2 配置gitlab-ce
参考[配置](gitlab.rb)
```
# vi /etc/gitlab/gitlab.rb
external_url 'http://gitlab.example.com'  # 对外暴露的域名

# gitlab-ctl reconfigure  # 加载配置并启动服务
```

### 1.3 gitlab启动和状态查看
```
启动gitlab服务
# gitlab-ctl start

查看状态
# gitlab-ctl status  

重启gitlab服务
# gitlab-ctl restart

停止gitlab服务
# gitlab-ctl stop 
```

### 1.4 访问gitlab
浏览器访问：http://gitlab.example.com，默认用户名：root，密码查看：cat /etc/gitlab/initial_root_password

### 1.5 常用gitlab指令说明
```
查看日志
# gitlab-ctl tail

重启单个模块
# gitlab-ctl restart <service_name>
# gitlab-ctl restart nginx
# gitlab-ctl stop postgresql

检查配置
# gitlab-rake gitlab:check SANITIZE=true

清理 Git 存储库
# gitlab-rake gitlab:cleanup:repos

检查并重新加载 LDAP 用户授权
# gitlab-rake gitlab:ldap:check

创建备份
# gitlab-backup create

恢复备份
# gitlab-backup restore BACKUP=<备份文件名>
```

## 二、脚本安装
本文提供了shell脚本一键安装，先下载脚本install.sh，然后执行脚本，脚本会自动安装gitlab.

### 2.1 脚本执行前准备
确保是一台新服务器，里面没有安装其他服务，避免因为端口冲突导致gitlab安装失败

### 2.2 脚本中变量说明
```
gitlab_version="12.10.0"                  # 必填，gitlab-ce版本，如 10.2.8 12.10.0 15.3.2 16.1.6 17.0.6等；
external_url="http://gitlab.mydomain.cn"  # 必填，访问GitLab的域名，如 http://gitlab.yourdomain.com
```

### 2.3 脚本执行
+ 1）下载install.sh脚本，最好是下载到一个单独的目录中，执行过程中会生成一些临时文件，以便执行完毕后清理.
+ 2）修改install.sh脚本中变量的值，根据你自己的实际场景修改配置
+ 3）给脚本执行权限 chmod +x install.sh，执行脚本 bash install.sh
