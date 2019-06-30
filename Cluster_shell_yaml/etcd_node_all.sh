#!/bin/bash
# Deploy etcd on the node1.
# 3.4.2.2 在Node节点上进行配置
# 在Node1执行脚本KubernetesInstall-06.sh。
#####ip环境
. /root/K8s/ip_2.txt
###### 
#识别master_ip及本机ip
rpm -aq net-tools || yum install net-tools  -y
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')

#####ip后两组数值
master_ip=$(grep  master_hosts_  /root/K8s/ip_2.txt |awk -F  "[.]"   '{print  $3,$4}'|sed  's/[ ]/./g')
Local_ip=$(echo  $IP| awk -F  "[.]"   '{print  $3,$4}'|sed  's/[ ]/./g')


#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################

_etcd_node () {
ETCD_SSL=/etc/etcd/ssl
mkdir -pv $ETCD_SSL
scp ${master_hosts_}:/root/K8s/Software_package/etcd-v3.3.11-linux-amd64.tar.gz /root/K8s/Software_package/
scp ${master_hosts_}:$ETCD_SSL/{ca*pem,server*pem} $ETCD_SSL/
scp ${master_hosts_}:/etc/etcd/etcd.conf /etc/etcd/
scp ${master_hosts_}:/usr/lib/systemd/system/etcd.service /usr/lib/systemd/system/
tar -xvzf /root/K8s/Software_package/etcd-v3.3.11-linux-amd64.tar.gz  -C /root/K8s/Software_package/
\cp /root/K8s/Software_package/etcd-v3.3.11-linux-amd64/etcd* /usr/local/bin/
. /etc/etcd/etcd.conf
etcd_xxx=$(echo  $ETCD_INITIAL_CLUSTER  |sed  's/,/ /g'|xargs -n 1| grep $IP |awk  -F  "="  '{print $1}')
sed -i "/ETCD_NAME/{s/etcd-0/$etcd_xxx/g}" /etc/etcd/etcd.conf
sed -i "/ETCD_LISTEN_PEER_URLS/{s/$master_ip/$Local_ip/g}"  /etc/etcd/etcd.conf
sed -i "/ETCD_LISTEN_CLIENT_URLS/{s/$master_ip/$Local_ip/g}"  /etc/etcd/etcd.conf
sed -i "/ETCD_INITIAL_ADVERTISE_PEER_URLS/{s/$master_ip/$Local_ip/g}"  /etc/etcd/etcd.conf
sed -i "/ETCD_ADVERTISE_CLIENT_URLS/{s/$master_ip/$Local_ip/g}"  /etc/etcd/etcd.conf
rm -rf /root/K8s/Software_package/etcd-v3.3.11-linux-amd64*
systemctl daemon-reload
systemctl enable etcd.service --now
systemctl status etcd  ||   systemctl restart  etcd    
}




#检查执行环境执行对应的函数组
#识别本机是哪个节点
shibieip=$(grep   $IP  /root/K8s/ip_2.txt  |awk -F  "="  '{print  $1}')
#执行对应节点的命令
case $shibieip in
        master_hosts_)
        echo '0' 
        # ssh ${master_hosts_} "test -s  /usr/lib/systemd/system/etcd.service "||{
        # sh  /root/K8s/Cluster_shell_yaml/etcd_master.sh 
        # }
        ;;
        slav*)
         echo '1' 
         ssh ${master_hosts_} "test -f  /usr/lib/systemd/system/etcd.services"
         var_1=$(echo $?)
         u=0
         while  [ $var_1 -ne 0 ]
                           do
                                   sleep 1 
                                   echo "等待etcd  master节点部署完毕"
                                    ssh ${master_hosts_} "test -s /usr/lib/systemd/system/etcd.service" && {
                                    var_2=$(ssh ${master_hosts_} "systemctl is-active  etcd")
                                    echo $var_2 |egrep "activating|active"
                                    var_3=$?
                                    [ $var_3  -eq 0  ] &&  break
                                    }
                                    let u+=i
                                    let i+=1
                                    echo $i
                                    [ $i -eq 1000 ] && {
                                            echo "[err]etcd_master节点部署超时退出"
                                            exit 1
                                            }
                          done 
         echo etcd_master部署结束                 
         _etcd_node

        ;;
esac
