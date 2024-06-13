#!/bin/bash

set -e

# 欢迎信息和输入配置
echo "欢迎使用 Kubernetes 安装脚本"
echo "这个脚本将帮助您在 Debian 系统上安装 Kubernetes 主节点和工作节点，并安装 Kubernetes Dashboard 进行集群管理"
echo ""

# 确认操作
read -p "当前节点是主节点还是工作节点？（master/worker）: " NODE_ROLE

if [ "$NODE_ROLE" != "master" ] && [ "$NODE_ROLE" != "worker" ]; then
    echo "错误：角色输入无效"
    exit 1
fi

# 设置用户名和密码（仅适用于主节点）
if [ "$NODE_ROLE" == "master" ]; then
    read -p "请输入您想要创建的 Dashboard 用户名: " USERNAME
    read -s -p "请输入密码: " PASSWORD
fi

# 安装 Docker
echo "开始安装 Docker..."
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 启动 Docker 服务
sudo systemctl enable docker
sudo systemctl start docker

# 添加 Kubernetes 源并安装 kubeadm, kubelet 和 kubectl
echo "添加 Kubernetes APT 源..."
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

sudo apt update
sudo apt install -y kubelet kubeadm kubectl

# 配置 cgroup 驱动程序为 systemd
echo "配置 cgroup 驱动程序为 systemd..."
sudo sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
sudo update-grub
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 初始化 Kubernetes 主节点（仅适用于主节点）
if [ "$NODE_ROLE" == "master" ]; then
    echo "初始化 Kubernetes 主节点..."
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all

    # 设置 kubeconfig 文件
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # 安装网络插件 Calico
    echo "安装网络插件 Calico..."
    kubectl apply -f https://docs.projectcalico.org/v3.20/manifests/calico.yaml

    # 安装 Kubernetes Dashboard
    read -p "是否安装 Kubernetes Dashboard？（y/n）: " INSTALL_DASHBOARD
    if [ "$INSTALL_DASHBOARD" == "y" ]; then
        echo "安装 Kubernetes Dashboard..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.5.0/aio/deploy/recommended.yaml
        
        # 创建 Dashboard 用户
        echo "创建 Dashboard 用户..."
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $USERNAME
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $USERNAME
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: $USERNAME
  namespace: kubernetes-dashboard
EOF
        # 获取 Dashboard 登录 token
        echo "获取 Dashboard 登录 token..."
        DASHBOARD_TOKEN=$(kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep $USERNAME | awk '{print $1}') | grep -E '^token' | awk '{print $2}')
        echo ""
        echo "以下是您的 Dashboard 登录 token，请妥善保存："
        echo $DASHBOARD_TOKEN
        echo ""
        echo "您可以通过 http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/ 登录 Dashboard"
    fi

    # 显示加入节点命令
    echo ""
    echo "Kubernetes 主节点初始化完成，请将以下命令复制到工作节点上以加入集群："
    sudo kubeadm token create --print-join-command > join-command.sh
    chmod +x join-command.sh
fi

# 加入 Kubernetes 工作节点（仅适用于工作节点）
if [ "$NODE_ROLE" == "worker" ]; then
    read -p "请输入主节点初始化后生成的加入命令: " JOIN_COMMAND
    sudo $JOIN_COMMAND
fi

echo ""
echo "Kubernetes 安装完成！"
