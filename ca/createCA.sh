## 二进制存入/usr/local/bin/
cp /root/k8s-tools/ca/bin/cfssl* /usr/local/bin
# apt install net-tools
# apt install net-tools
export node_hostname=`hostname`
export node_ip=`ifconfig ens33 | grep -w inet | awk '{print $2}'`
export MASTER_IP=`ifconfig ens33 | grep -w inet | awk '{print $2}'`
export ETCD_NAME=$(hostname -s)
## 
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
## 
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "Kubernetes",
      "OU": "Shanghai",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
## 
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "system:masters",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

##
cat > ${node_ip}-csr.json <<EOF
{
  "CN": "system:node:${node_ip}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "system:nodes",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${node_hostname},${node_ip} \
  -profile=kubernetes \
  ${node_ip}-csr.json | cfssljson -bare ${node_ip}


##
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

##

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "system:node-proxier",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

## 
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler


##
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "Kubernetes",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.250.0.1,${MASTER_IP},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
##
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "Kubernetes",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

## 
kubectl config set-cluster kubernetes-training \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${MASTER_IP}:6443 \
  --kubeconfig=${node_ip}.kubeconfig

kubectl config set-credentials system:node:${node_ip} \
  --client-certificate=${node_ip}.pem \
  --client-key=${node_ip}-key.pem \
  --embed-certs=true \
  --kubeconfig=${node_ip}.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:node:${node_ip} \
  --kubeconfig=${node_ip}.kubeconfig

kubectl config use-context default --kubeconfig=${node_ip}.kubeconfig

##
kubectl config set-cluster kubernetes-training \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${MASTER_IP}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

##
kubectl config set-cluster kubernetes-training \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${MASTER_IP}:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

## 
kubectl config set-cluster kubernetes-training \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${MASTER_IP}:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.pem \
  --client-key=kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

## 
kubectl config set-cluster kubernetes-training \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

## secret
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF


cd /root/k8s-tools/service
## service文件
sed -i "s/192.168.149.140/${MASTER_IP}/g" etcd.service
sed -i "s/192.168.149.140/${MASTER_IP}/g" kube-apiserver.service
sed -i "s/192.168.149.140/${MASTER_IP}/g" kubelet.service
sed -i "s/192.168.149.140/${MASTER_IP}/g" kube-proxy.service
sed  -i "s/worker-1/${node_ip}/g" kubelet-config.yaml
## 启动

rm -rf  /data/kubernetes/logs
rm -rf /var/lib/kubernetes/
rm -rf  /var/lib/kubelet
rm -rf  /var/lib/kube-proxy
rm -rf /etc/etcd/
rm -rf /etc/systemd/system/
rm -rf /etc/kubernetes/
rm -rf /etc/kubernetes/config

mkdir -p /data/kubernetes/logs
mkdir -p /var/lib/kubernetes/
mkdir -p  /var/lib/kubelet
mkdir -p  /var/lib/kube-proxy
mkdir -p /etc/etcd/
mkdir -p /etc/systemd/system/
mkdir -p /etc/kubernetes/
mkdir -p  /etc/kubernetes/config
cp /root/k8s-tools/ca/* /var/lib/kubernetes/
cp /root/k8s-tools/ca/* /etc/etcd/
cp /root/k8s-tools/ca/* /var/lib/kubelet/
cp /root/k8s-tools/ca/${node_ip}.kubeconfig  /var/lib/kubelet/kubeconfig
cp /root/k8s-tools/ca/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
cp  /root/k8s-tools/service/kubelet-config.yaml /var/lib/kubelet/kubelet-config.yaml
cp /root/k8s-tools/service/kube-scheduler.yaml  /etc/kubernetes/config/kube-scheduler.yaml
cp /root/k8s-tools/service/scheduler-policy-config.json /etc/kubernetes/scheduler-policy-config.json
cp  *.service  /etc/systemd/system/

## 启动docker
mkdir -p /data/docker


mkdir -p \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes \
  /etc/cni/net.d
#systemctl stop firewalld
#systemctl disable firewalld
#禁用 SELinux：
#setenforce 0
#sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
# 关闭swap
swapoff -a


## cni安装
## 下载cni-plugins插件到/opt/cni/bin
$ cat >/etc/cni/net.d/10-mynet.conf <<EOF
{
	"cniVersion": "0.2.0",
	"name": "mynet",
	"type": "bridge",
	"bridge": "cni0",
	"isGateway": true,
	"ipMasq": true,
	"ipam": {
		"type": "host-local",
		"subnet": "10.22.0.0/16",
		"routes": [
			{ "dst": "0.0.0.0/0" }
		]
	}
}
EOF


echo "success"

systemctl daemon-reload
exit 0


systemctl start docker


systemctl start etcd

systemctl enable kube-apiserver kube-controller-manager kube-scheduler kubelet   etcd docker kube-proxy
systemctl start kube-apiserver kube-controller-manager kube-scheduler  kube-proxy

## rbac

cat <<EOF | kubectl apply --kubeconfig /root/k8s-tools/ca/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

## 
cat <<EOF | kubectl apply --kubeconfig /root/k8s-tools/ca/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

## 




## flannel和dns安装


## 报错
##1. apt-get install iptables
## 安装ifconfig apt install net-tools
