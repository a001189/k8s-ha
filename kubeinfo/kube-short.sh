# kubectl 绠€鍐?

kb(){
kubectl $@;
}

# kba 鎵€鏈塶amespace
kall(){ kubectl $@ --all-namespaces; }

#ks 绯荤粺鍛藉悕绌洪棿
ksys() { kubectl $@ -n kube-system; }

# 鎵€鏈夌┖闂寸殑
# get

kgeta() { kall get $@ ;}

# apply
kappa() { kall apply $@ ;}

# describe 
kdesa() { kall describe $@ ;}

#delete
kdela() { kall delete $@ ;}

#edit
kedia() { kall edit $@ ;}

# 榛樿绌洪棿鐨?##############################################
namespace="default"
s="kube-client.$namespace() { kubectl \$@ ; }"
eval $s
# get

kget() { kube-client.default get $@ ;}

# apply
kapp() { kube-client.default apply $@ ;}

# describe 
kdes() { kube-client.default describe $@ ;}

#delete
kdel() { kube-client.default delete $@ ;}

#edit
kedi() { kube-client.default edit $@ ;}
###############################################

# kube-system 鍛藉悕绌洪棿

##############################################
namespace="kube-system"
s="kube-client.$namespace() { kubectl \$@ -n $namespace; }"
eval $s
# get

kgets() { kube-client.kube-system get $@ ;}

# apply
kapps() { kube-client.kube-system apply $@ ;}

# describe 
kdess() { kube-client.kube-system describe $@ ;}

#delete
kdels() { kube-client.kube-system delete $@ ;}

#edit
kedis() { kube-client.kube-system edit $@ ;}
###############################################


