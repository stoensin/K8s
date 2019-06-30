#!/bin/bash
basepath=$(cd `dirname $0`; pwd)
echo $basepath
ln  -sf /root/K8s/  ${basepath}/  /root/
#合并kubernetes-server-linux-amd64.tar.gz分卷,(解决git不能上传大于100M的问题)git下来后只会在第一次执行
ls -l   /root/K8s/Software_package/kubernetes-server-linux-amd64.tar.a*  2> /dev/null && {
cat   /root/K8s/Software_package/kubernetes-server-linux-amd64.tar.a*  > /root/K8s/Software_package/kubernetes-server-linux-amd64.tar.gz 
rm -f /root/K8s/Software_package/kubernetes-server-linux-amd64.tar.a*
tar xzvf  /root/K8s/Software_package/kubernetes-server-linux-amd64.tar.gz  -C /root/K8s/Software_package/
}
 
. /root/K8s/single_shell/var_.sh

sleep 5

##########
#选择集群安装或者单机安装
_menu_A 


