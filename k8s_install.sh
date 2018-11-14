cd kubeinfo
mkdir -p configs
source cluster_info.sh
source kube-short.sh

kubeadm reset -f
SERVER_NUM=3
K8S_DIR='/etc/kubernetes/'
HOSTS=(${CP0_HOSTNAME} ${CP1_HOSTNAME} ${CP2_HOSTNAME})
IPS=(${CP0_IP} ${CP1_IP} ${CP2_IP})

# 绿色输出函数
green_echo(){
    echo -e "\033[1;32m$@ \033[0m"
}
green_echo "#1: keepalived config "
index=0
while ((index<$SERVER_NUM));  
do 
    NodeIP=${IPS[${index}]};
    host=${HOSTS[${index}]};
    scp cluster_info.sh $host:/etc/profile.d/cluster_info.sh
    scp kube-short.sh $host:/etc/profile.d/kube-short.sh
    let priority=100-$index*10;
    ID=10;   
    sed  "s@#ID@$ID@;s@#priority@$priority@;s@#NodeIP@$NodeIP@;s@CP0_IP@$CP0_IP@;s@CP1_IP@$CP1_IP@;s@CP2_IP@$CP2_IP@;s@##$NodeIP@#$NodeIP@;s@##@@;s@LOAD_BALANCER_DNS@$LOAD_BALANCER_DNS@;s@#interface@$interface@;s/#.*//" keepalived.conf.sed > $host.keepalived.conf;
    scp $host.keepalived.conf $host:/etc/keepalived/keepalived.conf ; 
    checkScript='/etc/keepalived/keepalived-k8s.sh'
    echo '#!/bin/bash
    curl https://127.0.0.1:6443/healthz -k -s -m 2 &>/dev/null ||exit 1' >$checkScript &&chmod +x $checkScript
    scp $checkScript $host:$checkScript
    # 修改keepalived日志位置
    ssh $host "cp -n /etc/sysconfig/keepalived /etc/sysconfig/keepalived-bake"
    sed -i 's/KEEPALIVED_OPTIONS.*/KEEPALIVED_OPTIONS="-D -d -S 0"/' /etc/sysconfig/keepalived
    scp /etc/sysconfig/keepalived $host:/etc/sysconfig/keepalived
    ssh $host "test  `grep 'local0\.\*' /etc/rsyslog.conf |wc -l ` -gt 0 || (echo "添加keepalived日志路径：/var/log/keepalived.log" && echo 'local0.*       /var/log/keepalived.log' >> /etc/rsyslog.conf) "
    ssh $host "systemctl restart rsyslog && systemctl restart keepalived"; 
    ssh $host "kubeadm reset -f"
    let index=index+1;  
done
green_echo "#1 keepalived config is finished"


green_echo "#1 kubeadm config k8s cluster"
#source cluster_info
    
subinfo(){
  sed "s#LOAD_BALANCER_PORT#$LOAD_BALANCER_PORT#g;s#LOAD_BALANCER_DNS#$LOAD_BALANCER_DNS#g;s#CP0_HOSTNAME#$CP0_HOSTNAME#g;s#CP0_IP#$CP0_IP#g;s#CP1_HOSTNAME#$CP1_HOSTNAME#g;s#CP1_IP#$CP1_IP#g;s#CP2_HOSTNAME#$CP2_HOSTNAME#g;s#CP2_IP#$CP2_IP#g;s#ETCD_0_IP#$ETCD_0_IP#g;s#ETCD_1_IP#$ETCD_1_IP#g;s#ETCD_2_IP#$ETCD_2_IP#g;s#stable#v1.12.1#g;s#192.168.0.0/16#$CIDRs#g" $1>$2
  }

kubeadm reset -f
subinfo kubeadm-config.yaml configs/$CP0_HOSTNAME-kubeadm-config.yaml
scp configs/$CP0_HOSTNAME-kubeadm-config.yaml $K8S_DIR/kubeadm-config.yaml
kubeadm init --config $K8S_DIR/kubeadm-config.yaml
scp $K8S_DIR/admin.conf $HOME/.kube/config  



ETCD=`kubectl get pods -n kube-system 2>&1|grep etcd|awk '{print $3}'`
green_echo "Waiting for etcd bootup..."
while [ "${ETCD}" != "Running" ]; do
  sleep 1
  ETCD=`kubectl get pods -n kube-system 2>&1|grep etcd|awk '{print $3}'`
done
green_echo 'etcd bootup finished !!!'
kubectl apply -f ../calicos/
# 复制配置
index=1
USER=root
HOSTS=(${CP0_HOSTNAME} ${CP1_HOSTNAME} ${CP2_HOSTNAME})
IPS=(${CP0_IP} ${CP1_IP} ${CP2_IP})
while ((index<$SERVER_NUM));  
do 
    NodeIP=${IPS[${index}]};   
    host=${HOSTS[${index}]}; 
    # 重置k8s 并复制主节点证书
    ssh "${USER}"@$NodeIP "kubeadm reset -f && rm -rf $K8S_DIR/* && mkdir -p $K8S_DIR/pki/etcd/ && mkdir -p $HOME/.kube/"
    scp $K8S_DIR/pki/ca.crt "${USER}"@$NodeIP:$K8S_DIR/pki/
    scp $K8S_DIR/pki/ca.key "${USER}"@$NodeIP:$K8S_DIR/pki/
    scp $K8S_DIR/pki/sa.key "${USER}"@$NodeIP:$K8S_DIR/pki/
    scp $K8S_DIR/pki/sa.pub "${USER}"@$NodeIP:$K8S_DIR/pki/
    scp $K8S_DIR/pki/front-proxy-ca.crt "${USER}"@$NodeIP:$K8S_DIR/pki/
    scp $K8S_DIR/pki/front-proxy-ca.key "${USER}"@$NodeIP:$K8S_DIR/pki/
    scp $K8S_DIR/pki/etcd/ca.crt "${USER}"@$NodeIP:$K8S_DIR/pki/etcd/
    scp $K8S_DIR/pki/etcd/ca.key "${USER}"@$NodeIP:$K8S_DIR/pki/etcd/
    scp $K8S_DIR/admin.conf "${USER}"@$NodeIP:$K8S_DIR/
    scp $K8S_DIR/admin.conf "${USER}"@$NodeIP:$HOME/.kube/config
    # 生成config基础配置
    subinfo kubeadm-config$index.yaml configs/$host-kubeadm-config.yaml
    scp configs/$host-kubeadm-config.yaml ${USER}@$NodeIP:$K8S_DIR/kubeadm-config.yaml
    ssh "${USER}"@$NodeIP "
    kubeadm alpha phase certs all --config $K8S_DIR/kubeadm-config.yaml
    kubeadm alpha phase kubelet config write-to-disk --config $K8S_DIR/kubeadm-config.yaml
    kubeadm alpha phase kubelet write-env-file --config $K8S_DIR/kubeadm-config.yaml
    kubeadm alpha phase kubeconfig kubelet --config $K8S_DIR/kubeadm-config.yaml
    systemctl start kubelet
    #etcd 集群加入
    kubectl exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file $K8S_DIR/pki/etcd/ca.crt --cert-file $K8S_DIR/pki/etcd/peer.crt --key-file $K8S_DIR/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add $host https://${NodeIP}:2380
    kubeadm alpha phase etcd local --config $K8S_DIR/kubeadm-config.yaml

    kubeadm alpha phase kubeconfig all --config $K8S_DIR/kubeadm-config.yaml
    kubeadm alpha phase controlplane all --config $K8S_DIR/kubeadm-config.yaml
    kubeadm alpha phase kubelet config annotate-cri --config $K8S_DIR/kubeadm-config.yaml
    #kubeadm alpha phase mark-master --config $K8S_DIR/kubeadm-config.yaml
    "
    let index=index+1; 
done    


