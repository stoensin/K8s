#!/bin/bash
#检测集群端口占用,进程占用,目录占用情况
.  /root/K8s/ip_2.txt
 > /root/K8s/Cluster_shell_yaml/err_check.log

#########################系统防火墙 SELinux关闭  swap关闭##############################
ansible  all  -m shell  -a  "sed  's/TimeoutSec=0/TimeoutSec=200/g' /usr/lib/systemd/system/rc-local.service -i"
ansible  all  -m shell  -a  "sed -i 's#=enforcing#=disabled#g' /etc/selinux/config"
ansible  all  -m shell  -a  "setenforce 0" > /dev/null
ansible  all  -m shell  -a  "getenforce"
ansible  all  -m shell  -a  "getenforce"| grep Enforcing >/dev/null  && echo  "Selinux关闭失败,请检查服务器,手动关闭Selinux" >>/root/K8s/Cluster_shell_yaml/err_check.log
ansible  all  -m shell  -a  "systemctl stop firewalld.service"
ansible  all  -m shell  -a  "systemctl disable firewalld.service"
ansible  all  -m shell  -a  "systemctl  is-active  firewalld.service" >/dev/null  && echo "防火墙关闭失败,请检查服务器" >>/root/K8s/Cluster_shell_yaml/err_check.log
##>>>swap交换分区关闭
ansible all -m shell  -a " swapoff  -a" >/dev/null
#########################系统防火墙 SELinux关闭##############################
yum_repo=1
yum_status=93
for var_01 in  $(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|xargs)
        do 
        #K8s.repo  yum文件检测
        var_01_a=$(ansible all  -m shell  -a "ls  -l  /etc/yum.repos.d/*.repo|wc -l"|grep -A 1  ${var_01}|grep -v  rc=0)
        [ $var_01_a = 1 ] || echo "主机 ${var_01}存在多个repo文件，请检查/etc/yum.repos.d/目录下仅只有一个K8s.repo"  >>/root/K8s/Cluster_shell_yaml/err_check.log
        #K8s 本地yum源有效性检测
        var_01_a1=$(ansible all  -m shell -a  " yum repolist all "|grep -A 4  ${var_01}|grep  K8s|awk '{print $NF}')
        [  $var_01_a1   = $yum_status ] || echo "主机 ${var_01} K8s本地yum源异常，请检查/root/K8s/yum/目录是否存在，目录下是否有对应的rpm软件包"  >>/root/K8s/Cluster_shell_yaml/err_check.log
done 
########################本地yK8s yum源检测##############################################


#jdk  docker 环境 一致性#jdk  docker 环境 一致性#jdk  docker 环境 一致性#jdk  docker 环境 一致性
#jdk
# jdk_return_value=$( ansible all -m  shell -a "java -version" | grep FAILED|wc  -l)
# if  [ $jdk_return_value -ne 3  ]
#     then 
#       ansible all -m  shell -a "java -version"||{
#       jdk_check=$(ansible all -m  shell -a "java -version"|grep FAILED |awk '{print  $1}')
#       [ ! -n  "$jdk_check" ] || echo "主机${jdk_check}jdk环境异常，请使用java -version命令,whereis java命令检查集群jdk安装路径是否一致,务必使用/root/K8s/yum/jdk-linux-x64.rpm安装。" >>/root/K8s/Cluster_shell_yaml/err_check.log
#       }
# fi

#docker 版本一致性检查
for var_01 in  $(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|xargs)
        do 
       var_01_b=$(ansible $var_01 -m  shell -a "docker version|grep  Version|head  -n 1"|grep -A 1 ${var_01} |grep -v rc=  |grep  -o  "18.06.1-ce")
       ansible  ${var_01} -m  shell -a "docker version"|grep  "Version" && {
[  $var_01_b = 18.06.1-ce ]  || echo  "主机${var_01}docker版本不是18.06.1-ce，请重新安装18.06.1-ce版本"  >>/root/K8s/Cluster_shell_yaml/err_check.log
}

done 



####################端口号检查
for var_01 in  $(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|xargs)
        do 
       ansible ${var_01} -m shell   -a  "ss -lntup| egrep  \"27017|3306|2181|2888|3888|9092|6379|6380|6381|6382|22222|22223|22224|22225|19090|6433|2379|2380|7777|18081|18083\"" >/dev/null  && {
       echo "主机${var_01}存在以下端口占用，请停止相关服务接触端口占用"
       echo "主机${var_01}存在以下端口占用，请停止相关服务接触端口占用"  >>/root/K8s/Cluster_shell_yaml/err_check.log
       ansible ${var_01} -m shell   -a  "ss -lntup| egrep  \"27017|3306|2181|2888|3888|9092|6379|6380|6381|6382|22222|22223|22224|22225|19090|6433|2379|2380|7777|18081|18083\"" 
       ansible   ${var_01} -m shell   -a  "ss -lntup| egrep  \"27017|3306|2181|2888|3888|9092|6379|6380|6381|6382|22222|22223|22224|22225|19090|6433|2379|2380|7777|18081|18083\"" >>/root/K8s/Cluster_shell_yaml/err_check.log
}

done 



#根分区可用容量检查
#/分区可用空间不得低于5Gb
df=55552928
for var_01 in  $(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|xargs)
        do 

        var_01_d=$(ansible ${var_01} -m shell   -a    "df" | grep -v rc= | egrep    "/$" |awk '{print  $4}')
        [[ $var_01_d  -lt  $df ]] && {
        echo  "${var_01}主机根分区可用内存不足5Gb,安装终止"   >>/root/K8s/Cluster_shell_yaml/err_check.log
        }

done 


#############显卡驱动版本及显卡型号#####################################


