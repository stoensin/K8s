#!/bin/bash
#############修改段01#################################
_yumrepo () {
rpm -ivh /root/K8s/yum/deltarpm-3.6-3.el7.x86_64.rpm  
rpm -ivh /root/K8s/yum/libxml2-python-2.9.1-6.el7_2.3.x86_64.rpm  
rpm -ivh /root/K8s/yum/python-deltarpm-3.6-3.el7.x86_64.rpm   
rpm -ivh /root/K8s/yum/createrepo-0.9.9-28.el7.noarch.rpm
/usr/bin/createrepo -pdo /root/K8s/yum/  /root/K8s/yum/
tar  -czvPf /etc/yum.repos.d/yum_repo_bak.tar.gz /etc/yum.repos.d/*
rm -f  /etc/yum.repos.d/*.repo
> /etc/yum.repos.d/aios.repo 
cat >>/etc/yum.repos.d/aios.repo <<EOF
[K8s]
name=K8s
baseurl=file:///root/K8s/yum
enabled=1
gpgcheck=0
EOF
yum clean all
yum list &&echo '本地yum源测试成功'
}
_yumrepo
#k8s初始化环境
cat>/etc/sysctl.d/kubernetes.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p /etc/sysctl.d/kubernetes.conf>&/dev/null
##########
# sleep 1
sed  's/TimeoutSec=0/TimeoutSec=200/g' /usr/lib/systemd/system/rc-local.service -i
sed -i 's#=enforcing#=disabled#g' /etc/selinux/config
setenforce 0
getenforce
systemctl stop firewalld.service
systemctl disable firewalld.service

#####docker
_docker  (){
yum install /root/K8s/yum/docker-ce-18.06.1.ce-3.el7.x86_64.rpm   -y
systemctl start docker
docker -v
mkdir -pv /etc/docker
systemctl daemon-reload
systemctl restart docker
systemctl restart docker
sudo systemctl enable docker
docker --version
}
_docker 
