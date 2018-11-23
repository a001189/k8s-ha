# k8s-ha
k8s HA v1.12.1
## metric
k8s 升级后 heapster 的替代产品 ，metrics-server
1.11.4版本测试成功
参考 kubernetes 附件下的 metrics-server ，及修改了2个工作不正常的bug
* 增加 nodes/stats 及对应资源的create 权限
* 修改 metrics-server的启动脚本， 
[附件地址addons-metrics-server](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/metrics-server)
```bash
url='https://github.com/kubernetes/kubernetes/raw/master/cluster/addons/metrics-server'
for i in auth-delegator.yaml auth-reader.yaml metrics-apiservice.yaml metrics-server-deployment.yaml  metrics-server-service.yaml resource-reader.yaml; do wget $url/$i -O $i; done
```
参考
[metrics-server 官方地址](https://github.com/kubernetes-incubator/metrics-server/)

## ca-generate.sh
利用ca根证书签署证书，供其他pod使用
