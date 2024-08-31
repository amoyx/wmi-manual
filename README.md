# wmi-manual
wmi-manual 是一份用于互联网微服务中间件安装部署的手册，涉及GitLab、MySQL、Redis、Nacos、RabbitMQ、ElasticSearch、Jenkins、Apollo、Nginx等常用中间件，满足95%以上工作场景需要，让运维和开发再也不用整天为搭建中间件环境发愁.

**微服务特性：集群、高可用、WEB服务、数据库、缓存、注册中心、配置中心、消息队列、日志管理、监控服务、容器服务、代码管理、任务调度等**

本项目在实验中基于CentOS 7操作系统，兼容主要Linux发行版本，在实际部署时，需要了解JDK、Maven、Nginx、Linux等基础知识，以便更好排错及处理实际遇到的问题。

推荐版本一览
<table>
  <thead>
    <tr>
      <td>JDK</td>
      <td>jdk 8</td>
      <td>jdk 17</td>
      <td>jdk 18</td>
      <td></td>
      <td></td>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Maven</td>
      <td>apache-maven-3.3.9</td>
      <td>apache-maven-3.6.3</td>
      <td>apache-maven-3.9.8</td>
      <td></td>
      <td></td>
    </tr>
  </tbody>
  <tbody>
      <tr>
      <td>MySQL</td>
      <td>5.6.36+</td>
      <td>5.7.28+</td>
      <td>8.0.26+</td>
      <td></td>
      <td></td>
    </tr>
  </tbody>  
  <tbody>
    <tr>
      <td>Redis</td>
      <td>Redis 4.0</td>
      <td>Redis 5.0</td>
      <td>Redis 6.2</td>
	  <td>Redis 7.0</td>
	  <td></td>	  
    </tr>
  </tbody> 
  <tbody>
    <tr>
      <td>Nacos</td>
      <td>2.0.3</td>
      <td>2.1.0</td>
      <td>2.2.0</td>
      <td></td>
      <td></td>
    </tr>
  </tbody>  
  <tbody>
    <tr>
      <td>RabbitMQ</td>
	  <td>3.8.30</td>
      <td>3.10.30</td>
      <td>3.11.8</td>
      <td></td>
      <td></td>
    </tr>
  </tbody>    
  <tbody>
    <tr>
      <td>GitLab</td>
      <td>gitlab-ce-10.1.0</td>
      <td>gitlab-ce-12.x</td>
      <td>gitlab-ce-14.x</td>
	  <td>gitlab-ce-16.x</td>
      <td></td>
    </tr>
  </tbody>  
  <tbody>
    <tr>
      <td>Nginx</td>
      <td>1.14.x</td>
      <td>1.16.x</td>
	  <td>1.18.x</td>
	  <td>1.20.x</td>	  
	  <td>1.22.x</td>		  
    </tr>
  </tbody>   
  <tbody>
    <tr>
      <td>ElasticSearch</td>
      <td>6.8.2</td>
      <td>7.10.1</td>
	  <td>7.14.2</td>
	  <td>8.13.3</td>
      <td></td>
    </tr>
  </tbody>
  <tbody>
    <tr>
      <td>Kubernetes</td>
      <td>1.20.6</td>
      <td>1.22.5</td>
      <td>1.24.4</td>
	  <td>1.26.1</td>
	  <td>1.28.3</td>	  
    </tr>
  </tbody>   
</table>

-注：安装中间件用到的软件包文件已上传至云盘 [软件包下载](https://pan.baidu.com/s/1iW86DlOrECdycPFi8-G8YQ?pwd=cs1c)

## 国内开源镜像站
部署中间件服务时，需要安装wget、unzip、tar等常用软件，请事先配置好yum、apt等镜像源，以避免安装时报错，部分国内开源镜像站如下：
<table>
  <thead>
    <tr>
	  <td></td>
      <td>CentOS</td>
      <td>Debian</td>
      <td>Fedora</td>
      <td>Ubuntu</td>
	  <td>epel</td>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>腾讯云镜像源</td>
      <td>
	     <a href="https://mirrors.tencent.com/repo/centos6_base.repo">CentOS 6</a></br>
		 <a href="https://mirrors.tencent.com/repo/centos7_base.repo">CentOS 7</a></br>
		 <a href="https://mirrors.tencent.com/repo/centos8_base.repo">CentOS 8</a>
	  </td>
      <td>
	    <a href="https://mirrors.tencent.com/repo/debian8_sources.list">Debian 8</a></br>
	    <a href="https://mirrors.tencent.com/repo/debian9_sources.list">Debian 9</a></br>
		<a href="https://mirrors.tencent.com/repo/debian10_sources.list">Debian 10</a>
	  </td>
      <td>
	     <a href="https://mirrors.tencent.com/repo/fedora.repo">Fedora</a>
	  </td>
	  <td>
	    <a href="https://mirrors.tencent.com/repo/ubuntu18_sources.list">Ubuntu 18</a></br>
		<a href="https://mirrors.tencent.com/repo/ubuntu20_sources.list">Ubuntu 20</a></br>
		<a href="https://mirrors.tencent.com/repo/ubuntu22_sources.list">Ubuntu 22</a>
	  </td>
	  <td>
	  	<a href="https://mirrors.tencent.com/repo/epel-6.repo">epel 6</a></br>
		<a href="https://mirrors.tencent.com/repo/epel-7.repo">epel 7</a>
	  </td>
    </tr>
  </tbody>
  <tbody>
      <tr>
	  <td>阿里云镜像源</td>
      <td>
	    <a href="https://mirrors.aliyun.com/repo/Centos-6.repo">CentOS 6</a></br>
		<a href="https://mirrors.aliyun.com/repo/Centos-7.repo">CentOS 7</a></br>
		<a href="https://mirrors.aliyun.com/repo/Centos-8.repo">CentOS 8</a>
	  </td>
      <td>
	    <a href="https://developer.aliyun.com/mirror/debian?spm=a2c6h.13651102.0.0.7fb11b114KpJne">debian 9.x (stretch)</a></br>
		<a href="https://developer.aliyun.com/mirror/debian?spm=a2c6h.13651102.0.0.7fb11b114KpJne">debian 10.x (buster)</a></br>
		<a href="https://developer.aliyun.com/mirror/debian?spm=a2c6h.13651102.0.0.7fb11b114KpJne">debian 11.x (bullseye)</a>	  
	  </td>
      <td>
	  	<a href="https://mirrors.aliyun.com/repo/fedora.repo">Fedora</a>
	  </td>
      <td>
	    <a href="https://developer.aliyun.com/mirror/ubuntu?spm=a2c6h.13651102.0.0.41b01b11n2Y2lw">ubuntu 18.04 LTS (bionic) </a></br>
		<a href="https://developer.aliyun.com/mirror/ubuntu?spm=a2c6h.13651102.0.0.41b01b11n2Y2lw">ubuntu 20.04 LTS (focal) </a></br>
		<a href="https://developer.aliyun.com/mirror/ubuntu?spm=a2c6h.13651102.0.0.41b01b11n2Y2lw">ubuntu 22.04 LTS (jammy)</a></br>
        <a href="https://developer.aliyun.com/mirror/ubuntu?spm=a2c6h.13651102.0.0.41b01b11n2Y2lw">ubuntu 24.04 (noble)</a>		    
	  </td>
	  <td>
	  	<a href="https://mirrors.aliyun.com/repo/epel-6.repo">epel 6</a></br>
		<a href="https://mirrors.aliyun.com/repo/epel-7.repo">epel 7</a>
	  </td>	  
    </tr>
  </tbody>  
  <tbody>
    <tr>
      <td>网易云镜像源</td>
      <td>
	    <a href="https://mirrors.163.com/.help/CentOS6-Base-163.repo">CentOS 6</a></br>
		<a href="https://mirrors.163.com/.help/CentOS7-Base-163.repo">CentOS 7</a></br>  
	  </td>
      <td>
	    <a href="https://mirrors.163.com/.help/sources.list.stretch">debian (stretch)</a></br>
		<a href="https://mirrors.163.com/.help/sources.list.buster">debian (buster)</a></br>
		<a href="https://mirrors.163.com/.help/sources.list.bullseye">debian (bullseye)</a></br>
        <a href="https://mirrors.163.com/.help/sources.list.bookworm">debian (bookworm)</a>		
	  </td>
      <td>
	    <a href="https://mirrors.163.com/.help/fedora-163.repo">Fedora</a>
	  </td>
	  <td>
	    <a href="https://mirrors.163.com/.help/sources.list.bionic">ubuntu 18.04 LTS (bionic) </a></br>
		<a href="https://mirrors.163.com/.help/sources.list.focal">ubuntu 20.04 LTS (focal) </a></br>
		<a href="https://mirrors.163.com/.help/sources.list.jammy">ubuntu 22.04 LTS (jammy)</a></br>
        <a href="https://mirrors.163.com/.help/sources.list.lunar">ubuntu 23.04 (lunar)</a>			  
	  </td>
	  <td></td>	  
    </tr>
  </tbody> 
  <tbody>
    <tr>
      <td>华为云镜像源</td>
      <td>
	    <a href="https://mirrors.huaweicloud.com/repository/conf/CentOS-7-anon.repo">CentOS 7</a></br>
		<a href="https://mirrors.huaweicloud.com/repository/conf/CentOS-8-anon.repo">CentOS 8</a></br>  
	  </td>
      <td>
	    <a href="https://mirrors.huaweicloud.com/mirrorDetail/5ea14e0757bdf83a14170fdf?mirrorName=debian&catalog=os">debian (stretch)</a></br>
		<a href="https://mirrors.huaweicloud.com/mirrorDetail/5ea14e0757bdf83a14170fdf?mirrorName=debian&catalog=os">debian (buster)</a></br>
		<a href="https://mirrors.huaweicloud.com/mirrorDetail/5ea14e0757bdf83a14170fdf?mirrorName=debian&catalog=os">debian (bullseye)</a></br>
        <a href="https://mirrors.huaweicloud.com/mirrorDetail/5ea14e0757bdf83a14170fdf?mirrorName=debian&catalog=os">debian (bookworm)</a>		
	  </td>
      <td>
	    <a href="https://mirrors.huaweicloud.com/mirrorDetail/5ea14dee7c04483df02c7103?mirrorName=fedora&catalog=os">Fedora</a>
	  </td>
	  <td>
	    <a href="https://mirrors.huaweicloud.com/mirrorDetail/5ea14ecab05943f36fb75ee7?mirrorName=ubuntu&catalog=os">ubuntu</a>		  
	  </td>
	  <td>
	    <a href="https://mirrors.huaweicloud.com/mirrorDetail/5ea154f4e2d71cf5b9fb037d?mirrorName=epel&catalog=os">epel</a>
	  </td>	 
    </tr>
  </tbody>
</table>


## 部署准备

大多数中间件集群模式需要用到3~6个节点，在部署前最好先准备3台以上服务器，不少命令可能需要root权限运行，最好以root用户进行实践，以免带来不必要的错误！

### 1.基础系统配置

+ 4g内存/50g硬盘（该配置仅测试用）；生产环境中以业务实际需求进行规划
+ 最小化安装`CentOS 7 Minimal`或者`Ubuntu 16.04 server`
+ 配置基础网络、更新源、SSH登录等

### 2.在每个节点安装依赖工具

如用于下载wget、curl的工具，用于解压包tar、unzip的软件包。

### 3.准备ssh免密登陆

配置从部署节点能够ssh免密登陆所有节点.

``` bash
#$IP为所有节点地址包括自身，按照提示输入yes 和root密码
ssh-copy-id $IP 
```

### 4.下载安装包

安装包已放在网盘，请提前将安装包从云盘下载至部署节点 [软件包下载](https://pan.baidu.com/s/1iW86DlOrECdycPFi8-G8YQ?pwd=cs1c)，也可以自行去官方网站下载不同版本

