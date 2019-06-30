#!/bin/bash
# 3.5 部署Flannel网络
# 由于Flannel需要使用etcd存储自身的一个子网信息，所以要保证能成功连接Etcd，写入预定义子网段。写入的Pod网段${CLUSTER_CIDR}必须是/16段地址
# ，必须与kube-controller-manager的–-cluster-cidr参数值一致。一般情况下，在每一个Node节点都需要进行配置，执行脚本KubernetesInstall-08.sh。
#####ip环境
#####ip环境
. /root/K8s/ip_2.txt
master_ip=${master_hosts_}
note=$(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|grep $master_ip -v)



echo $note |xargs -n 1  |awk '{for(i=1;i<=NF;i++){printf "etcd-+=https://"$i" "}{print ""}}' |awk -v RS="+" '{n+=1;printf $0n}'|sed 's/$/&:2380,/g' |xargs |sed 's/4:2380,/ /g'| sed 's/ //g'|sed '$s/,$//'
###### 
var_01=$(echo $note |xargs -n 1  |sed  's/^/https:\/\/&/g'|sed 's/$/&:2379,/g'|xargs | sed 's/ //g')
var_02=$(echo $note |xargs -n 1  |sed  's/^/https:\/\/&/g'|sed 's/$/&:2379,\\/g' | awk 'NF{a=$0}END{print a}'|sed  's/,\\//'|sed 's/$/&"/g')
######
KUBE_CONF=/etc/kubernetes
FLANNEL_CONF=$KUBE_CONF/flannel.conf
mkdir -pv $KUBE_CONF
tar -xvzf /root/K8s/Software_package/flannel-v0.11.0-linux-amd64.tar.gz  -C  /root/K8s/Software_package/
cd  /root/K8s/Software_package/
mv {flanneld,mk-docker-opts.sh} /usr/local/bin/

yy_01=$(echo '$var_01')
oo_02=$(echo '$var_02')
etcdctl   --ca-file=/etc/etcd/ssl/ca.pem  --cert-file=/etc/etcd/ssl/server.pem  --key-file=/etc/etcd/ssl/server-key.pem  --endpoints="https://${master_ip}:2379,${yy_01}${oo_02}" cluster-health



# Writing into a predetermined subnetwork.
cd /etc/etcd/ssl
etcdctl \
--ca-file=ca.pem --cert-file=server.pem --key-file=server-key.pem \
--endpoints="https://${master_ip}:2379,$(echo $note |xargs -n 1  |sed  's/^/https:\/\/&/g'|sed 's/$/&:2379,/g' |xargs |sed '$s/,$//'| sed 's/ //g')" \
set /coreos.com/network/config  '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'
cd ~

#Configuration the flannel service.
cat>$FLANNEL_CONF<<EOF
FLANNEL_OPTIONS="--etcd-endpoints=https://${master_ip}:2379,$(echo $note |xargs -n 1  |sed  's/^/https:\/\/&/g'|sed 's/$/&:2379,/g' |xargs |sed '$s/,$//'| sed 's/ //g') -etcd-cafile=/etc/etcd/ssl/ca.pem -etcd-certfile=/etc/etcd/ssl/server.pem -etcd-keyfile=/etc/etcd/ssl/server-key.pem"
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
