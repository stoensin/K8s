#!/bin/bash
 net=$(ls  -l /etc/sysconfig/network-scripts/ifcfg-*|awk   -F  "-" '{print  $NF}'|grep -v lo)
 IP=$(for var in $net;do ifconfig $var 2>/dev/null;done|grep inet|grep -v  inet6|awk  '{print $2}')
 alias kubectl="/usr/local/bin/kubectl -s http://${IP}:19090"

cat >dashboard-rabc.yaml<<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
    addonmanager.kubernetes.io/mode: Reconcile
  name: kubernetes-dashboard
  namespace: kube-system
---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: kubernetes-dashboard-minimal
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: kubernetes-dashboard
    namespace: kube-system
EOF




cat  > dashboard-controller.yaml  <<  'EOF'
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: kubernetes-dashboard
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      serviceAccountName: kubernetes-dashboard
      containers:
      - name: kubernetes-dashboard
        image: registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.0
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 9090
          protocol: TCP
        #args:
        #- --apiserver-host=http://10.0.0.101:8080
        livenessProbe:
          httpGet:
            scheme: HTTP
            path: /
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
      tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Exists"
EOF


cat > dashboard-service.yaml  << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-dashboard
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  type: NodePort
  selector:
    k8s-app: kubernetes-dashboard
  ports:
  - port: 80
    targetPort: 9090
    nodePort: 42345
EOF



kubectl create -f dashboard-rabc.yaml
kubectl create -f dashboard-controller.yaml
kubectl create -f dashboard-service.yaml

kubectl cluster-info
kubectl get pod -o wide -n kube-system
kubectl get svc -o wide -n kube-system 