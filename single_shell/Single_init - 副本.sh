#!/bin/bash
# Deploy the master node.
rpm -aq | grep net-tools   ||  yum install net-tools -y  >   /dev/null
#检测本机master IP地址
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')
######
###### 
######
#关闭swap
swapoff -a

#etcd,k8s单机版
rpm -aq | grep net-tools   ||  yum install net-tools -y  >   /dev/null
#检测本机master IP地址
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')
######

\cp /root/Installation/k8s/cfssl* /usr/local/bin/
sleep 1
chmod +x /usr/local/bin/cfssl*
ETCD_SSL=/etc/etcd/ssl
mkdir -p $ETCD_SSL
# Create some CA certificates for etcd cluster.
cat<<EOF>$ETCD_SSL/ca-config.json
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "www": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF
cat<<EOF>$ETCD_SSL/ca-csr.json
{
    "CN": "etcd CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]
}
EOF
cat<<EOF>$ETCD_SSL/server-csr.json
{
    "CN": "etcd",
    "hosts": [
    "${IP}",
    "${IP}",
    "${IP}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]
}
EOF
cd $ETCD_SSL
cfssl_linux-amd64 gencert -initca ca-csr.json | cfssljson_linux-amd64 -bare ca -
cfssl_linux-amd64 gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssljson_linux-amd64 -bare server
cd ~
# ca-key.pem  ca.pem  server-key.pem  server.pem
ls $ETCD_SSL/*.pem

####################################################################################
###################################################################################
####################################################################################
####################################################################################
####################################################################################

#02 配置etcd服务
######
mkdir -p  /etc/etcd/
ETCD_CONF=/etc/etcd/etcd.conf
ETCD_SSL=/etc/etcd/ssl
ETCD_SERVICE=/usr/lib/systemd/system/etcd.service
tar -xzf /root/Installation/k8s/etcd-v3.3.11-linux-amd64.tar.gz  -C /root/Installation/k8s/
\cp -p /root/Installation/k8s/etcd-v3.3.11-linux-amd64/etc* /usr/local/bin/

# The etcd configuration file. 
cat>$ETCD_CONF<<EOF
#[Member]
ETCD_NAME="etcd-01"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="http://${IP}:2380"
ETCD_LISTEN_CLIENT_URLS="http://${IP}:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://${IP}:2379"
ETCD_INITIAL_CLUSTER="etcd-01=http://${IP}:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

# The etcd servcie configuration file.
cat>$ETCD_SERVICE<<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=$ETCD_CONF
ExecStart=/usr/local/bin/etcd \
--name=\${ETCD_NAME} \
--data-dir=\${ETCD_DATA_DIR} \
--listen-peer-urls=\${ETCD_LISTEN_PEER_URLS} \
--listen-client-urls=\${ETCD_LISTEN_CLIENT_URLS},http://127.0.0.1:2379 \
--advertise-client-urls=\${ETCD_ADVERTISE_CLIENT_URLS} \
--initial-advertise-peer-urls=\${ETCD_INITIAL_ADVERTISE_PEER_URLS} \
--initial-cluster=\${ETCD_INITIAL_CLUSTER} \
--initial-cluster-token=\${ETCD_INITIAL_CLUSTER_TOKEN} \
--initial-cluster-state=new \
--cert-file=/etc/etcd/ssl/server.pem \
--key-file=/etc/etcd/ssl/server-key.pem \
--peer-cert-file=/etc/etcd/ssl/server.pem \
--peer-key-file=/etc/etcd/ssl/server-key.pem \
--trusted-ca-file=/etc/etcd/ssl/ca.pem \
--peer-trusted-ca-file=/etc/etcd/ssl/ca.pem
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable etcd.service --now
systemctl status etcd  




####################################################################################
####################################################################################
####################################################################################
####################################################################################
#ETCD

#安装 Flannel网络
sh  +x  /root/Installation/shell/Flannel.sh
#安装 Flannel网络

echo  安装Flannel网络结束



KUBE_SSL=/etc/kubernetes/ssl
mkdir -p $KUBE_SSL

# Create CA.
cat>$KUBE_SSL/ca-config.json<<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF
cat>$KUBE_SSL/ca-csr.json<<EOF
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF
cat>$KUBE_SSL/server-csr.json<<EOF
{
    "CN": "kubernetes",
    "hosts": [
      "10.0.0.1",
      "127.0.0.1",
      "${IP}",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF
cd $KUBE_SSL
cfssl_linux-amd64 gencert -initca ca-csr.json | cfssljson_linux-amd64 -bare ca -
cfssl_linux-amd64 gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes server-csr.json | cfssljson_linux-amd64 -bare server

# Create kube-proxy CA.
cat>$KUBE_SSL/kube-proxy-csr.json<<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "ST": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
cfssl_linux-amd64 gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson_linux-amd64 -bare kube-proxy
ls *.pem
cd ~


#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################
# 3.6.2 安装配置kube-apiserver服务
# 将备好的安装包解压，并移动到相关目录，进行相关配置，执行脚本KubernetesInstall-10.sh。
#master上执行
KUBE_ETC=/etc/kubernetes
KUBE_API_CONF=/etc/kubernetes/apiserver.conf
tar -xvzf /root/Installation/k8s/kubernetes-server-linux-amd64.tar.gz  -C  /root/Installation/k8s/
mv /root/Installation/k8s/kubernetes/server/bin/{kube-apiserver,kube-scheduler,kube-controller-manager} /usr/local/bin/

# Create a token file.
cat>$KUBE_ETC/token.csv<<EOF
$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

# Create a kube-apiserver configuration file.
cat >$KUBE_API_CONF<<EOF
KUBE_APISERVER_OPTS="--logtostderr=true \
--v=4 \
--etcd-servers=http://${IP}:2379 \
--bind-address=${IP} \
--insecure-port=19090 \
--insecure-bind-address=0.0.0.0 \
--secure-port=6443 \
--advertise-address=0.0.0.0 \
--allow-privileged=true \
--service-cluster-ip-range=10.0.0.0/24 \
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota,NodeRestriction \
--authorization-mode=RBAC,Node \
--enable-bootstrap-token-auth \
--token-auth-file=$KUBE_ETC/token.csv \
--service-node-port-range=30000-50000 \
--tls-cert-file=$KUBE_ETC/ssl/server.pem  \
--tls-private-key-file=$KUBE_ETC/ssl/server-key.pem \
--client-ca-file=$KUBE_ETC/ssl/ca.pem \
--service-account-key-file=$KUBE_ETC/ssl/ca-key.pem \
--etcd-cafile=/etc/etcd/ssl/ca.pem \
--etcd-certfile=/etc/etcd/ssl/server.pem \
--etcd-keyfile=/etc/etcd/ssl/server-key.pem"
EOF
#--authorization-mode=RBAC,Node \
#--authorization-rbac-super-user=kubectl \

# Create the kube-apiserver service.
cat>/usr/lib/systemd/system/kube-apiserver.service<<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service

[Service]
EnvironmentFile=-$KUBE_API_CONF
ExecStart=/usr/local/bin/kube-apiserver \$KUBE_APISERVER_OPTS
Restart=on-failure
LimitNOFILE=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-apiserver.service --now
systemctl status kube-apiserver.service



# --------------------- # --------------------- # --------------------- 
# 参数说明：

# –logtostderr：启用日志。
# –v：日志等级。
# –etcd-servers：etcd集群地址。
# –bind-address：监听地址。
# –secure-port：https安全端口。
# –advertise-address：集群通告地址。
# –allow-privileged：启用授权。
# –service-cluster-ip-range：Service虚拟IP地址段。
# –enable-admission-plugins：准入控制模块。
# –authorization-mode：认证授权，启用RBAC授权和节点自管理。
# –enable-bootstrap-token-auth：启用TLS bootstrap功能。
# –token-auth-file：token文件。
# –service-node-port-range：Service Node类型默认分配端口范围。
# --------------------- # --------------------- # --------------------- 
#

#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################
#####安装配置kube-scheduler服务
#master上执行
KUBE_ETC=/etc/kubernetes
KUBE_SCHEDULER_CONF=$KUBE_ETC/kube-scheduler.conf
cat>$KUBE_SCHEDULER_CONF<<EOF
KUBE_SCHEDULER_OPTS="--logtostderr=true \
--v=4 \
--master=127.0.0.1:19090 \
--leader-elect"
EOF

cat>/usr/lib/systemd/system/kube-scheduler.service<<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-$KUBE_SCHEDULER_CONF
ExecStart=/usr/local/bin/kube-scheduler \$KUBE_SCHEDULER_OPTS
Restart=on-failure
LimitNOFILE=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-scheduler.service --now
sleep 5
systemctl status kube-scheduler.service





# 参数说明：

# –master：连接本地apiserver。
# –leader-elect：当该组件启动多个时，自动选举（HA），被选为 leader的节点负责处理工作，其它节点为阻塞状态。

#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################
#master上执行
#安装配置kube-controller服务
KUBE_CONTROLLER_CONF=/etc/kubernetes/kube-controller-manager.conf

cat>$KUBE_CONTROLLER_CONF<<EOF
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \
--v=4 \
--master=127.0.0.1:19090 \
--leader-elect=true \
--address=127.0.0.1 \
--service-cluster-ip-range=10.0.0.0/24 \
--cluster-name=kubernetes \
--cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem \
--cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem  \
--root-ca-file=/etc/kubernetes/ssl/ca.pem \
--service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem"
EOF

cat>/usr/lib/systemd/system/kube-controller-manager.service<<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-$KUBE_CONTROLLER_CONF
ExecStart=/usr/local/bin/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS
Restart=on-failure
LimitNOFILE=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-controller-manager.service --now
sleep 5
systemctl status kube-controller-manager.service




##############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################
#master上执行
#移动kkubectl工具检查集群状态
mv /root/Installation/k8s/kubernetes/server/bin/kubectl /usr/local/bin/
ss -lntup| grep api

 kubectl -s  http://${IP}:19090 get cs





##############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################
# 3.7.1 创建bootstrap和kube-proxy的kubeconfig文件
# Master apiserver启用TLS认证后，Node节点kubelet组件想要加入集群，必须使用CA签发的有效证书才能与apiserver通信，
# 当Node节点很多时，签署证书是一件很繁琐的事情，因此有了TLS Bootstrapping机制，kubelet会以一个低权限用户自动向apiserver申请证书，kubelet的证书由apiserver动态签署。在前面创建的token文件在这一步派上了用场，在Master节点上执行脚本KubernetesInstall-14.sh创建bootstrap.kubeconfig和kube-proxy.kubeconfig。
#master执行
#####ip环境
#####ip环境
BOOTSTRAP_TOKEN=$(awk -F "," '{print $1}' /etc/kubernetes/token.csv)
KUBE_SSL=/etc/kubernetes/ssl/
KUBE_APISERVER="https://${IP}:6443"

cd $KUBE_SSL
# Set cluster parameters.
kubectl  config set-cluster kubernetes \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig

# Set client parameters.
kubectl   config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig

# Set context parameters. 
kubectl  config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig

# Set context.
kubectl   config use-context default --kubeconfig=bootstrap.kubeconfig

# Create kube-proxy kubeconfig file. 
kubectl  config set-cluster kubernetes \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig

kubectl   config set-credentials kube-proxy \
  --client-certificate=./kube-proxy.pem \
  --client-key=./kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl   config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl   config use-context default --kubeconfig=kube-proxy.kubeconfig
cd ~

# Bind kubelet-bootstrap user to system cluster roles.
kubectl   -s  http://${IP}:19090  create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap




#sleep
kubectl -s  http://${IP}:19090  get cs




#单机加入node节点

_master_node  ()  {
KUBE_CONF=/etc/kubernetes
KUBE_SSL=$KUBE_CONF/ssl
mkdir -p  $KUBE_SSL
\cp /root/Installation/k8s/kubernetes/server/bin/{kube-proxy,kubelet} /usr/local/bin/
\cp $KUBE_CONF/ssl/{bootstrap.kubeconfig,kube-proxy.kubeconfig} $KUBE_CONF
cat>$KUBE_CONF/kube-proxy.conf<<EOF
KUBE_PROXY_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=$IP \
--cluster-cidr=10.0.0.0/24 \
--kubeconfig=$KUBE_CONF/kube-proxy.kubeconfig"
EOF
cat>/usr/lib/systemd/system/kube-proxy.service<<EOF
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
EnvironmentFile=-/etc/kubernetes/kube-proxy.conf
#ExecStart=/usr/local/bin/kube-proxy $KUBE_PROXY_OPTS
Restart=on-failure
ExecStart=/usr/local/bin/kube-proxy \
  --bind-address=10.210.28.142 \
  --hostname-override=10.210.28.142 \
  --kubeconfig=/etc/kubernetes/ssl/kube-proxy.kubeconfig \
--masquerade-all \
  --proxy-mode=ipvs \
  --ipvs-min-sync-period=5s \
  --ipvs-sync-period=5s \
  --ipvs-scheduler=rr \
  --logtostderr=true \
  --v=2 \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-proxy.service --now
sleep 5
systemctl status kube-proxy.service -l
cat>$KUBE_CONF/kubelet.yaml<<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: $IP
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDNS: ["10.0.0.2"]
clusterDomain: cluster.local.
failSwapOn: false
authentication:
  anonymous:
    enabled: true
EOF
cat>$KUBE_CONF/kubelet.conf<<EOF
KUBELET_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=$IP \
--kubeconfig=$KUBE_CONF/kubelet.kubeconfig \
--bootstrap-kubeconfig=$KUBE_CONF/bootstrap.kubeconfig \
--config=$KUBE_CONF/kubelet.yaml \
--cert-dir=$KUBE_SSL \
--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0   \
--max-pods=254"
EOF
cat>/usr/lib/systemd/system/kubelet.service<<EOF
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=$KUBE_CONF/kubelet.conf
ExecStart=/usr/local/bin/kubelet \$KUBELET_OPTS
Restart=on-failure
KillMode=process
LimitNOFILE=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet.service --now 
sleep 5
systemctl status kubelet.service -l

}


_master_node 

####接受crs
_approve_csr ()  {
# Approve kubelet CSR请求
# 可以手动或自动approve CSR请求。推荐使用自动的方式，因为从 v1.8 版本开始，可以自动轮转approve csr后生成的证书。未approve之前如下：
CSRS=$(/usr/local/bin/kubectl -s  http://${IP}:19090  get csr | awk '{if(NR>1) print $1}')
for csr in $CSRS;
    do
        /usr/local/bin/kubectl  -s  http://${IP}:19090  certificate approve $csr;
    done
/usr/local/bin/kubectl -s  http://${IP}:19090  get node
/usr/local/bin/kubectl -s  http://${IP}:19090  get cs
#####ip环境
# .  /root/Installation/ip.txt
# master_ip=${IP}
######
sleep 1
/usr/local/bin/kubectl -s  http://${IP}:19090 label node ${IP}  node-role.kubernetes.io/master='master'
/usr/local/bin/kubectl -s  http://${IP}:19090  get node
/usr/local/bin/kubectl -s  http://${IP}:19090  create clusterrolebinding system:anonymous   --clusterrole=cluster-admin   --user=system:anonymous
}
_approve_csr


#加入环境变量
cat >>/root/.bash_profile  << 'EOF'
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')
alias kubectl="/usr/local/bin/kubectl -s http://${IP}:19090"
EOF





#新增证书文件


cat /etc/kubernetes/kubelet.kubeconfig > /root/.kube/config

