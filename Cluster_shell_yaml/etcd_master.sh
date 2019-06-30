#!/bin/bash
. /root/K8s/ip_2.txt
rpm -aq | grep net-tools   ||  yum install net-tools -y  >   /dev/null
#检测本机master IP地址
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')


master_ip=$(grep  master_hosts  /root/K8s/ip_2.txt |awk -F  "="   '{print  $2}' |xargs)








\cp /root/K8s/Software_package/cfssl* /usr/local/bin/
sleep 1
chmod +x /usr/local/bin/cfssl*
ETCD_SSL=/etc/etcd/ssl
mkdir -pv $ETCD_SSL
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

#note节点ip
note_ip=$(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|grep -v $master_hosts_  |sed  's/^/"&/g'|sed 's/$/",/g' |sed 's/ //g'|sed '$s/,$//')
cat<<EOF>$ETCD_SSL/server-csr.json
{
    "CN": "etcd",
    "hosts": [
    "${master_ip}",
${note_ip}
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
####################################################################################
####################################################################################
####################################################################################
####################################################################################
note=$(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|grep $master_ip -v)
note_2=$(echo $note |xargs -n 1  |awk '{for(i=1;i<=NF;i++){printf "etcd-+=https://"$i" "}{print ""}}' |awk -v RS="+" '{n+=1;printf $0n}'|sed 's/$/&:2380/g'|sed 's/$/&,/g' |xargs |awk  '{$NF="";print}'|sed   's/ //g'|sed 's/.$//')

#02 配置etcd服务
######
mkdir -pv  /etc/etcd/
ETCD_CONF=/etc/etcd/etcd.conf
ETCD_SSL=/etc/etcd/ssl
ETCD_SERVICE=/usr/lib/systemd/system/etcd.service
tar -xzf /root/K8s/Software_package/etcd-v3.3.11-linux-amd64.tar.gz  -C /root/K8s/Software_package/
\cp -p /root/K8s/Software_package/etcd-v3.3.11-linux-amd64/etc* /usr/local/bin/

# The etcd configuration file. 
cat>$ETCD_CONF<<EOF
#[Member]
ETCD_NAME="etcd-0"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://${master_ip}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${master_ip}:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${master_ip}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://${master_ip}:2379"
ETCD_INITIAL_CLUSTER="etcd-0=https://${master_ip}:2380,${note_2}"
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
#systemctl restart etcd.service
timeout 5 systemctl enable etcd.service --now
systemctl status etcd
systemctl is-active  etcd  
echo ok


####################################################################################
####################################################################################
####################################################################################
####################################################################################
####################################################################################