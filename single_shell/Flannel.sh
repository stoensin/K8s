#!/bin/bash
# 3.5 部署Flannel网络
# 由于Flannel需要使用etcd存储自身的一个子网信息，所以要保证能成功连接Etcd，写入预定义子网段。写入的Pod网段${CLUSTER_CIDR}必须是/16段地址
# ，必须与kube-controller-manager的–-cluster-cidr参数值一致。一般情况下，在每一个Node节点都需要进行配置，执行脚本KubernetesInstall-08.sh。
#####ip环境
rpm -aq | grep net-tools   ||  yum install net-tools -y  >   /dev/null
#检测本机master IP地址
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')
#####ip环境
######
KUBE_CONF=/etc/kubernetes
FLANNEL_CONF=$KUBE_CONF/flannel.conf
mkdir -p $KUBE_CONF
tar -xvzf /root/Installation/k8s/flannel-v0.11.0-linux-amd64.tar.gz  -C  /root/Installation/k8s/
cd  /root/Installation/k8s/
mv {flanneld,mk-docker-opts.sh} /usr/local/bin/
# Check whether etcd cluster is healthy.
etcdctl \
--ca-file=/etc/etcd/ssl/ca.pem \
--cert-file=/etc/etcd/ssl/server.pem \
--key-file=/etc/etcd/ssl/server-key.pem \
--endpoints="http://${IP}:2379" cluster-health

# Writing into a predetermined subnetwork.
cd /etc/etcd/ssl
etcdctl \
--ca-file=ca.pem --cert-file=server.pem --key-file=server-key.pem \
--endpoints="http://${IP}:2379" \
set /coreos.com/network/config  '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'
cd ~

# Configuration the flannel service.
cat>$FLANNEL_CONF<<EOF
FLANNEL_OPTIONS="--etcd-endpoints=http://${IP}:2379 -etcd-cafile=/etc/etcd/ssl/ca.pem -etcd-certfile=/etc/etcd/ssl/server.pem -etcd-keyfile=/etc/etcd/ssl/server-key.pem"
EOF
cat>/usr/lib/systemd/system/flanneld.service<<EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network-online.target network.target
Before=docker.service

[Service]
Type=notify
EnvironmentFile=$FLANNEL_CONF
ExecStart=/usr/local/bin/flanneld --ip-masq $FLANNEL_OPTIONS
ExecStartPost=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/subnet.env
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Modify the docker service.
sed -i.bak -e '/ExecStart/i EnvironmentFile=\/run\/flannel\/subnet.env' -e 's/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd $DOCKER_NETWORK_OPTIONS/g' /usr/lib/systemd/system/docker.service

# Start or restart related services.
systemctl daemon-reload
systemctl enable flanneld --now
systemctl restart docker
systemctl status flanneld || systemctl restart  flanneld
systemctl status docker
ip address show

