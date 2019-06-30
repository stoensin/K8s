#!/bin/bash
#!/bin/bash
#3.7.2 配置kube-proxy和kubelet服务
# 因为kubernetes-server-linux-amd64.tar.gz已经在Master节点的HOME目录解压，所以可以在各节点上执行脚本KubernetesInstall-15.sh。
#node节点执行
#####ip环境
#####ip环境
. /root/K8s/ip_2.txt
master_ip=${master_hosts_}
note=$(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|grep $master_ip -v)
#识别master_ip及本机ip
rpm -aq net-tools || yum install net-tools  -y
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')

######
######

_node () {
KUBE_CONF=/etc/kubernetes
KUBE_SSL=$KUBE_CONF/ssl
IP=${IP}
mkdir -pv $KUBE_SSL
scp ${master_hosts_}:/root/K8s/Software_package/kubernetes/server/bin/{kube-proxy,kubelet} /usr/local/bin/
scp ${master_hosts_}:$KUBE_CONF/ssl/{bootstrap.kubeconfig,kube-proxy.kubeconfig} $KUBE_CONF
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
EnvironmentFile=-$KUBE_CONF/kube-proxy.conf
ExecStart=/usr/local/bin/kube-proxy \$KUBE_PROXY_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-proxy.service --now
sleep 20
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
--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
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

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet.service --now
sleep 20
systemctl status kubelet.service -l
}




# 以上脚本有多少个Node节点就在相应的Node节点上执行多少次，每次执行只需修改IP的值即可。
# 参数说明：
# –hostname-override：在集群中显示的主机名。
# –kubeconfig：指定kubeconfig文件位置，会自动生成。
# –bootstrap-kubeconfig：指定刚才生成的bootstrap.kubeconfig文件。
# –cert-dir：颁发证书存放位置。
# –pod-infra-container-image：管理Pod网络的镜像。
# --------------------- 

#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################
#将master作为node节点
_master_node  ()  {
KUBE_CONF=/etc/kubernetes
KUBE_SSL=$KUBE_CONF/ssl
IP=${master_ip}
mkdir -pv  $KUBE_SSL
\cp /root/K8s/Software_package/kubernetes/server/bin/{kube-proxy,kubelet} /usr/local/bin/
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
EnvironmentFile=-$KUBE_CONF/kube-proxy.conf
ExecStart=/usr/local/bin/kube-proxy \$KUBE_PROXY_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-proxy.service --now
sleep 20
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
--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
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

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet.service --now
sleep 20
systemctl status kubelet.service -l

}


#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################




#识别master_ip及本机ip
rpm -aq net-tools || yum install net-tools  -y
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')
#检查执行环境执行对应的函数组
#识别本机是哪个节点
shibieip=$(grep   $IP  /root/K8s/ip_2.txt  |awk -F  "="  '{print  $1}')
case $shibieip in
        master_hosts_)
        echo '0' 
        _master_node
        ;;
        slav*)
         echo '1' 
         _node
        ;;
esac

#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################
_approve_csr ()  {
# Approve kubelet CSR请求
# 可以手动或自动approve CSR请求。推荐使用自动的方式，因为从 v1.8 版本开始，可以自动轮转approve csr后生成的证书。未approve之前如下：
CSRS=$(/usr/local/bin/kubectl get csr | awk '{if(NR>1) print $1}')
for csr in $CSRS;
    do
        /usr/local/bin/kubectl certificate approve $csr;
    done
/usr/local/bin/kubectl get node
/usr/local/bin/kubectl get cs
#####ip环境
.  /root/K8s/ip_2.txt
master_ip=${master_hosts_}
######
sleep 1
/usr/local/bin/kubectl label node ${master_ip}  node-role.kubernetes.io/master='master'
for var_3  in  $(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|grep $master_ip -v)
  do 
    /usr/local/bin/kubectl label node ${var_3}  node-role.kubernetes.io/node='node'
done
/usr/local/bin/kubectl get node
}


# 查看集群状态



#master节点接收Approve kubelet CSR请求
#检查安装note节点数量
note_Number=$(cat /root/K8s/ip_2.txt |wc -l)
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')
shibieip=$(grep   $IP  /root/K8s/ip_2.txt  |awk -F  "="  '{print  $1}')
case $shibieip in
        master_hosts_)
        echo '0' 
        var_1=$(/usr/local/bin/kubectl get csr | awk '{if(NR>1) print $1}' |wc  -l)
         u=0
         while  [ $var_1 -lt $note_Number ]
                           do
                                   sleep 1 
                                   echo "等待etcd  master节点部署完毕"
                                    var_2=$(/usr/local/bin/kubectl get csr | awk '{if(NR>1) print $1}' |wc  -l)
                                    [ $var_2  -eq $note_Number  ] &&  {
                                    note_pending=$(/usr/local/bin/kubectl get csr| grep  "Pending"|wc -l)
                                    [ $note_pending  -eq $note_Number  ] && break
                                      }


                                    let u+=i
                                    let i+=1
                                    echo $i
                                    [ $i -eq 1000 ] && {
                                            echo "[err]k8s_note节点部署超时退出"
                                            exit 1
                                            }
                          done 
         echo etcd_master部署结束 
         sleep 3
        _approve_csr
        ;;
esac



