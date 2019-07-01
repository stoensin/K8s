#!/bin/bash
#本地yum源
_yumrepo () {
rpm -ivh /root/K8s/yum/deltarpm-3.6-3.el7.x86_64.rpm
rpm -ivh /root/K8s/yum/libxml2-python-2.9.1-6.el7_2.3.x86_64.rpm
rpm -ivh /root/K8s/yum/python-deltarpm-3.6-3.el7.x86_64.rpm
rpm -ivh /root/K8s/yum/createrepo-0.9.9-28.el7.noarch.rpm
/usr/bin/createrepo -pdo /root/K8s/yum/  /root/K8s/yum/
tar  -czvPf /etc/yum.repos.d/yum_repo_bak.tar.gz /etc/yum.repos.d/*
rm -f  /etc/yum.repos.d/*.repo
> /etc/yum.repos.d/K8s.repo
cat >>/etc/yum.repos.d/K8s.repo <<EOF
[K8s]
name=K8s
baseurl=file:///root/K8s/yum
enabled=1
gpgcheck=0
EOF
yum clean all
yum list &&echo '本地yum源测试成功'
yum install vim -y
}
#


#获取集群ip
_cluster_ip  ()  {
if (whiptail --title "导入集群IP地址(包含本机ip默认第一个ip对应本机ip作为master)" --yes-button "YES" --no-button "NO"  --yesno "批量导入集群IP地址?" 10 60) then
    echo "You chose Skittles Exit status was $?."
    echo  ok
    rm -f   /root/K8s/.ip.txt*
    rm -f   /root/K8s/ip.txt
    > /root/K8s/ip.txt
cat >  /root/K8s/ip.txt <<EOF
#按下字母i键进入编辑模式,将ip批量粘贴进来即可
#格式如下(不包含#号),导入完毕后wq退出即可继续后面的操作
#x.x.x.x
#x.x.x.x
#x.x.x.x
EOF
    vim /root/K8s/ip.txt
    echo  IP导入完毕
else
    echo "You chose M&M's. Exit status was $?."
    echo  no
    exit 1
fi
}




#批量导入ip集群安装向导
_Cluste_K8s_One_click   ()  {
#获取集群ip
_cluster_ip
rpm -aq | grep net-tools   ||  yum install net-tools -y  >   /dev/null
#检测本机master IP地址
net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')
password_=$(whiptail --title "#请输入集群服务器统一的root密码 并回车#" --passwordbox "请确认所有节点root密码一致,确定提交?" 10 60 3>&1 1>&2 2>&3)
master_hosts_=$(whiptail --title "#请输入本机Ip(master)并回车#" --inputbox "请检查IP是否一致,确定提交?" 10 60 "$IP" 3>&1 1>&2 2>&3)



#批处理ip.txt
grep -v  "^#" /root/K8s/ip.txt |sed  "/$master_hosts_/d" | awk '{for(i=1;i<=NF;i++){printf "slave+_hosts_="$i" "}{print ""}}' |awk -v RS="+" '{n+=1;printf $0n}'  > /root/K8s/ip_2.txt
sed -i '$d' /root/K8s/ip_2.txt   
sed "s/^.*${master_hosts_}.*$/k8s_master=${master_hosts_}/"  /root/K8s/ip_2.txt  -i
sed  "/$master_hosts_/d"  /root/K8s/ip_2.txt  -i
echo  "master_hosts_=$master_hosts_"  >>  /root/K8s/ip_2.txt



#检查ip连通性,生成集群ip配置文件路径:/root/K8s/ip_2.txt
. /root/K8s/ip_2.txt


for  var_1  in  $( awk -F  "="   '{print  $2}'  /root/K8s/ip_2.txt |xargs)
    do
echo  "检查 $var_1 连通性....." 
  ping $var_1    -w 1 -t 50 |grep -Eo "received, 0%"| grep -Eo 0  >/dev/null   ||   {
  clear 
  echo "$var_1    所输入IP无效,安装终止"
exit 1
  }
done

#安装ansible 集群面交互环境
yum install ansible   libselinux-python   sshpass   -y   >   /dev/null
#ansible调优
sed  s/'#host_key_checking = False'/'host_key_checking = False'/g   /etc/ansible/ansible.cfg  -i
sed  s/'#pipelining = False'/'pipelining = True'/g   /etc/ansible/ansible.cfg  -i
sed      '/^GSSAPI/s/yes/no/g;  /UseDNS/d; /Protocol/aUseDNS no'    /etc/ssh/sshd_config   -i
echo  'gather_facts: nogather_facts: no' >> /etc/ansible/ansible.cfg
systemctl restart  sshd
#
#清除本地ssh环境
\rm -f ~/.ssh/*
#创建秘钥对
ssh-keygen -t dsa -f /root/.ssh/id_dsa -N  ""   &>/dev/null

#配置免交互登录
for  ip  in  $(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|xargs)
do
sshpass   -p  "$password_"  ssh-copy-id   -i  /root/.ssh/id_dsa.pub   root@$ip   -o StrictHostKeyChecking=no 

if [ $? -eq 0 ] 
    then
    echo   " host  $ip     成功！！！！"
            else
            echo   " host  $ip    失败!!!!" 
	    exit 1 
	
fi  
done



###配置ansible hosts文件
grep   master /etc/ansible/hosts  || {
cat >>/etc/ansible/hosts<<EOF
[master]
$master_hosts_


[slave]
$(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|grep -v $master_hosts_)


[all]
$master_hosts_
$(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|grep -v $master_hosts_)


EOF
} 
###
##note节点ssh优化
#
ansible  all  -m shell -a "sed      '/^GSSAPI/s/yes/no/g;  /UseDNS/d; /Protocol/aUseDNS no'    /etc/ssh/sshd_config   -i"
ansible  all  -m shell -a "systemctl restart sshd"
##ssh优化

echo    
echo "=============end=====END========================" 
#检测分发效果连通性,批量配置主机名
for var_2 in  $(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt|grep $master_hosts_ -v|xargs)
do
  echo "==============host  $ip  info============================"
   grep  master /etc/hostname    ||  hostnamectl  set-hostname  K8s-master
   hostnamectl  set-hostname  K8s-master
   let u+=i
   let i+=1
   ssh root@$var_2  " hostnamectl  set-hostname  K8s-node${i}"
   echo  "K8s-node${i}-$var_2"
done
        



echo "===========END==================END====================="



#拷贝安装文件至slave节点
cat  >  /root/K8s/Cluster_shell_yaml/copy.yaml   <<EOF
- hosts: [all]
  tasks:
    - name: 系统初始化
      shell: systemctl stop firewalld.service
      shell: sed  's/TimeoutSec=0/TimeoutSec=200/g' /usr/lib/systemd/system/rc-local.service -i
      shell: setenforce 0
      shell: getenforce
      shell: sed -i 's#=enforcing#=disabled#g' /etc/selinux/config
 

- hosts: [slave]
  tasks: 
    - name: 拷贝安装文件到slave节点<a01>
      copy: src=/root/K8s/  dest=/root/K8s/
    - name: 执行系统初始化脚本<a02>
      shell: rpm -ivh /root/K8s/yum/deltarpm-3.6-3.el7.x86_64.rpm
      shell: rpm -ivh /root/K8s/yum/libxml2-python-2.9.1-6.el7_2.3.x86_64.rpm
      shell: rpm -ivh /root/K8s/yum/python-deltarpm-3.6-3.el7.x86_64.rpm
      shell: rpm -ivh /root/K8s/yum/createrepo-0.9.9-28.el7.noarch.rpm
      shell: /usr/bin/createrepo -pdo /root/K8s/yum/  /root/K8s/yum/
      shell: yum clean all
      shell: yum list echo '本地yum源测试成功'
      shell: echo '本地yum源测试成功'
    - name: ansible客户端插件安装install_libselinux-python<a03>
      yum: name=libselinux-python state=latest  disable_gpg_check=yes
    - name: ansible客户端插件安装install_ntp<a04>
      yum: name=ntp    state=latest  disable_gpg_check=yes
    - name: ansible客户端插件安装install_net-tools<a05>
      yum: name=net-tools   state=latest  disable_gpg_check=yes
    - name: ansible客户端插件安装install_net-tools<a06>
      yum: name=net-tools   state=latest  disable_gpg_check=yes
    - name: ansible客户端插件安装install_sshpass<a07>
      yum: name=sshpass   state=latest  disable_gpg_check=yes
    - name: ansible客户端插件安装install_sshpass<a08>
      yum: name=rsync   state=latest  disable_gpg_check=yes   

EOF

cat  > /root/K8s/yum/K8s.repo   <<EOF
[K8s]
name=K8s
baseurl=file:///root/K8s/yum
enabled=1
gpgcheck=0
EOF



ansible slave  -m  shell -a  "tar  -czvPf /etc/yum.repos.d/yum_repo_bak.tar.gz /etc/yum.repos.d/*"
ansible slave  -m  shell -a  "rm -f  /etc/yum.repos.d/*.repo"
ansible slave  -m copy  -a  "src=/root/K8s/yum/K8s.repo   dest=/etc/yum.repos.d/"



#配置slave节点 本地Yum源
ansible all  -m shell -a  "yum clean all "  >  /dev/null 
ansible all  -m shell -a  " yum list "  >  /dev/null 
yum_echo=$?
if [ $yum_echo -ne 0 ]
    then  
       ansible-playbook      /root/K8s/Cluster_shell_yaml/copy.yaml     -vvv
       else
       ansible slave  -m shell -a  " /usr/bin/rsync -av  $master_hosts_:/root/K8s/  /root/K8s/"
fi

#配置集群面交互登录
#检测分发效果连通性
for var_3 in  $(awk -F  "="   '{print  $2}' /root/K8s/ip_2.txt  | grep -v $master_hosts_ |xargs)
do
  echo "==============host  $var_3  info============================"
    ssh root@$var_3 "rm -f  /root/.ssh/id_dsa"
    ssh root@$var_3 "ssh-keygen -t dsa -f /root/.ssh/id_dsa -N  \"\"   &>/dev/null"
    ssh root@$var_3 "sshpass   -p  "$password_"  ssh-copy-id   -i  /root/.ssh/id_dsa.pub   root@$master_hosts_   -o StrictHostKeyChecking=no"
done

#时间同步ntp服务端客户端配置
#定时同步时间定时任务
crontab -l  |grep  ntp1.aliyun.com   > /dev/null  ||   echo  '*/5 * * * * /usr/sbin/ntpdate ntp1.aliyun.com >/dev/null 2>&1'  >> /var/spool/cron/root
yum install ntp  -y    
cat >/etc/ntp.conf <<EOF
driftfile /var/lib/ntp/drift
restrict default kod nomodify notrap nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery
restrict 127.0.0.1 
restrict -6 ::1
server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
server 127.127.1.0  iburst   # local clock 使用本机时间作为时间服务的标准
fudge 127.127.1.0 stratum 10 #这个值不能太高0-15，太高会报错
EOF
cat >/etc/sysconfig/ntpd <<EOF
# Drop root to id 'ntp:ntp' by default.
OPTIONS="-u ntp:ntp -p /var/run/ntpd.pid -g"
SYNC_HWCLOCK=yes
EOF

#时间同步服务端启动,加开机自启
systemctl restart  ntpd.service
systemctl enable  ntpd.service

#验证

#配置客户端同步时间
ansible slave  -m  shell -a  "crontab  -l| grep  $master_hosts_"    ||  {
        ansible slave  -m  shell -a  "echo  '*/5 * * * * /usr/sbin/ntpdate $master_hosts_  >/dev/null 2>&1'  >>  /var/spool/cron/root"
        ansible slave  -m  shell -a  "crontab  -l| grep  $master_hosts_" 
}
#同步时间
sleep 2 
echo 同步时间,检查ntp服务是否可用
sleep 2
echo 同步时间,检查ntp服务是否可用
sleep 2
echo 同步时间,检查ntp服务是否可用

clear 
sleep  5
ansible slave -m shell -a  "ntpdate  $master_hosts_;hostname;date"
echo   ansible环境配置结束,ntp时间同步配置结束
sleep 5
#

####################分割线##############################3
#master节点配置dns服务
yum install dnsmasq -y  
systemctl restart dnsmasq
systemctl enable   dnsmasq.service
#更改配置文件
cat > /etc/dnsmasq.conf  <<EOF
resolv-file=/etc/resolv.dnsmasq.conf
listen-address=127.0.0.1,$master_hosts_
conf-dir=/etc/dnsmasq.d,.rpmnew,.rpmsave,.rpmorig
addn-hosts=/etc/dnshosts/k8s
EOF

cat   > /etc/resolv.dnsmasq.conf  <<EOF
# Generated by NetworkManager
nameserver 223.5.5.5
EOF

#重启dnsmasq服务
systemctl restart dnsmasq
#更改本机dns  /etc/resolv.conf
echo  "nameserver  $master_hosts_"  >> /etc/resolv.conf
cat  >/etc/resolv.conf   <<  EOF
# Generated by NetworkManager
nameserver   $master_hosts_
EOF




################ansible环境配置结束#############################ansible环境配置结束###########################
################ansible环境配置结束#############################ansible环境配置结束###########################
################ansible环境配置结束#############################ansible环境配置结束###########################
################ansible环境配置结束#############################ansible环境配置结束###########################
#执行检测脚本(必须在master节点执行)
sh /root/K8s/Cluster_shell_yaml/Check.sh
sleep  3
if 
    test -s  /root/K8s/Cluster_shell_yaml/err_check.log 
      then 
           echo  "集群安装环境检测不通过，存在以下问题(更多记录请查看/root/K8s/Cluster_shell_yaml/err_check.log)"
           cat   /root/K8s/Cluster_shell_yaml/err_check.log
           exit 1
      else
          echo "集群安装环境检测通过,即将安装K8s集群环境"
fi


################33
#执行对应ansible剧本
_Cluster_install  () {
#集群系统初始化本地Yum  docker  jdk环境
ansible-playbook      /root/K8s/Cluster_shell_yaml/a01_k8s_init.sh_all.yaml     -vvv
[ $? -ne 0 ] && {
echo "集群初始化脚本执行失败,安装终止，脚本路径/root/K8s/Cluster_shell_yaml/"
exit 1
}
#集群 Etcd环境
ansible-playbook      /root/K8s/Cluster_shell_yaml/a02_etcd_all.yaml     -vvv
ansible  all  -m  shell  -a  "systemctl  is-active  etcd" || {
echo "集群 Etcd环境执行失败,安装终止，脚本路径/root/K8s/Cluster_shell_yaml/"
exit 1
}
#k8s master 环境
ansible-playbook      /root/K8s/Cluster_shell_yaml/a03_k8s_master.yaml    -vvv
[ $? -ne 0 ] && {
echo "集群k8s master 环境执行失败,安装终止，脚本路径/root/K8s/Cluster_shell_yaml/"
exit 1
}
#k8s slave环境
ansible-playbook      /root/K8s/Cluster_shell_yaml/a04_k8s_slave.yaml    -vvv
[ $? -ne 0 ] && {
echo "集群k8s slave环境执行失败,安装终止，脚本路径/root/K8s/Cluster_shell_yaml/"
exit 1
}

}
# #执行K8s集群安装
_Cluster_install 





 }



_menu_A (){
OPTION=$(whiptail --title "K8s,  Vision @ 2019" --menu "Choose your option" 20 65 13 \
"1" "Single K8s One-click" \
"2" "Cluste K8s One-click" \
"3" "Quit"  3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]
            then
                    case $OPTION in
                        1) 
                       sh +x     /root/K8s/Cluster_shell_yaml/k8s-init.sh
                       sh  +x      /root/K8s/single_shell/Single_init.sh
                       echo  "安装k8s,Wed界面dashboard,端口号42345"
                       sh  +x       /root/K8s/single_shell/dashboard.sh  
                       whiptail --title "kubernetes_v1.13.2单机版安装完毕" --msgbox "K8s单机版安装完毕,web控制界面dashboard地址为\n\nhttp://IP:42345" 12 80
                       clear
source   /root/.bash_profile
kubectl  get csr
 kubectl  get cs
 kubectl  get node
 
                       
                        ;;  
                        2) 
                            _yumrepo
                            _Cluste_K8s_One_click 
kubectl  get csr
 kubectl  get cs
 kubectl  get node
                        ;;
                        3) 
                          echo  待完善                  
                        ;;                        
                        3)  
                            clear 
                            exit 0
                        ;;
                        *) echo "操作错误"
                        ;;
                    esac
                
            else
                clear
fi
}
################################################################################
