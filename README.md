
# K8s升级替换v1.14.0   v1.15.0
#如果不需要使用v1.14.0  v1.15.0直接默认一键安装即可。master分支默认的是v1.13.2
## 默认版本为v1.13.2,提供升级软件包v14  v15自行下载后放到  K8s/Software_package  目录即可(务必删除原有的)
链接：https://pan.baidu.com/s/1Sb8WH_z-dUI8z2vLEYWa_w 
提取码：0eyz 
![输入图片说明](https://images.gitee.com/uploads/images/2019/0629/223656_83724e63_525507.png "屏幕截图.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0629/223707_c0937c7b_525507.png "屏幕截图.png")


放入前务必执行以下操作
``` shell
rm -fv  K8s/Software_package/kubernetes-server-linux-amd64.tar.a*
```
![输入图片说明](https://images.gitee.com/uploads/images/2019/0629/224709_8790eed8_525507.png "屏幕截图.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0629/224720_0ca3c7a0_525507.png "屏幕截图.png")

华丽分界线。。。。。。。。。。。。。。
===
#### 介绍
一键安装命令(要求centos7系统为新装系统无任何软件环境可联网)


```
yum install wget  unzip  -y ;wget  https://codeload.github.com/szbjb/K8s/zip/master  && unzip    master* && mv  -v  K8s-master  K8s  && cd K8s/ && sh install.sh

```

视频演示地址
===
https://www.bilibili.com/video/av57242055?from=search&seid=4003077921686184728


#### 测试环境
* VMware15虚拟化平台，所有服务器节点2核2G
* 已测2-20节点安装正常
* 建议新装centos7.6系统,环境干净(不需要提前安装任何软件不需要提前安装docker).集群功能至少2台服务器节点


网络  | 系统  | 内核版本 | IP获取方式 | docker版本 | Kubernetes版本 |K8s集群安装方式 |
---- | ----- | ------  | ---- |  ---- | ---- | ---- |
桥接模式  | 新装CentOS7.6.1810 (Core) | 3.10.0-957.el7.x86_64 | 手动设置固定IP(不能dhcp获取所有节点) | 18.06.1-ce | v1.13.2  | 二进制包安装  |



#### 安装教程
```
yum install wget  unzip  -y
wget  https://gitee.com/q7104475/K8s/repository/archive/master.zip
unzip  master.zip
cd K8s/ && sh install.sh
```
#### 使用说明

1. xxxx
2. xxxx
3. xxxx

#### 参与贡献


#### 使用截图
![输入图片说明](https://images.gitee.com/uploads/images/2019/0701/095702_04b50cfc_525507.png "屏幕截图.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151653_e76832a6_525507.png "QQ图片20190305151528.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151703_5da78708_525507.png "QQ图片20190305151533.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151710_92e5f5ba_525507.png "QQ图片20190305151537.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151718_c3218e5c_525507.png "QQ图片20190305151541.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151726_dcc498bc_525507.png "QQ图片20190305151544.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151734_c2361acc_525507.png "QQ图片20190305151519.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151746_8b15d028_525507.png "QQ图片20190305151556.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151753_8597d7c3_525507.png "QQ图片20190305151600.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151759_3cc9716d_525507.png "QQ图片20190305151548.png")
![输入图片说明](https://images.gitee.com/uploads/images/2019/0305/151804_c09e620b_525507.png "QQ图片20190305151553.png")

交流群
====
![输入图片说明](https://images.gitee.com/uploads/images/2019/0629/175427_0e439feb_525507.png "屏幕截图.png")
* Q群名称：K8s自动化部署交流
* Q群   号：893480182


更新日志
===
2019-7-1
新增单机版 web图形化控制台dashboard
K8s单机版安装完毕,web控制界面dashboard地址为                           http://IP:42345