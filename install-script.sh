#!/bin/bash

LOG_FILE="/var/log/devops_install.log"
touch $LOG_FILE
exec > >(tee -a $LOG_FILE) 2>&1

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

check_command() {
    if ! command -v $1 &>/dev/null; then
        log "❌ ERROR: $1 installation failed!"
        exit 1
    else
        log "✅ $1 installed successfully!"
    fi
}

log "🔄 Running system update..."
sudo yum update -y || { log "❌ System update failed!"; exit 1; }

log "🔄 Installing prerequisites (wget, zip)..."
sudo yum install -y wget zip || { log "❌ Failed to install wget or zip!"; exit 1; }

install_git() {
    log "📦 Installing Git..."
    sudo yum install -y git || { log "❌ Git installation failed!"; exit 1; }
    check_command git
}

install_maven() {
    log "📦 Installing Maven..."
    sudo yum install -y maven || { log "❌ Maven installation failed!"; exit 1; }
    check_command mvn
}

install_ansible() {
    log "📦 Installing Ansible..."
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    sudo dnf repolist | grep epel || { log "❌ epel-release installation failed!"; exit 1; }
    sudo dnf install -y ansible || { log "❌ Ansible installation failed!"; exit 1; }
    check_command ansible
}

install_jenkins() {
    log "📦 Installing Jenkins..."
    sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    sudo yum install -y fontconfig java-17-openjdk jenkins || { log "❌ Jenkins installation failed!"; exit 1; }
    sudo systemctl daemon-reload
    sudo systemctl enable --now jenkins
    sudo systemctl status jenkins --no-pager || { log "❌ Jenkins failed to start!"; exit 1; }
    log "✅ Jenkins installed and running!"
}

install_sonarqube() {
    log "📦 Installing SonarQube..."
    sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.7.96285.zip
    unzip sonarqube-9.9.7.96285.zip
    ~/sonarqube-9.9.7.96285/bin/linux-x86-64/sonar.sh start || { log "❌ SonarQube failed to start!"; exit 1; }
    log "✅ SonarQube installed and running!"
}

install_nexus() {
    log "📦 Installing Nexus..."
    wget https://download.sonatype.com/nexus/3/nexus-unix-x86-64-3.78.2-04.tar.gz
    tar -xvf nexus-unix-x86-64-3.78.2-04.tar.gz
    cd nexus-3.78.2-04/bin
    log "⚠️ Ensure 'nexus' file ownership is changed to ec2-user or the intended user!"
    ~/nexus-3.78.2-04/bin/nexus start || { log "❌ Nexus failed to start!"; exit 1; }
    log "✅ Nexus installed and running!"
}

install_terraform() {
    log "📦 Installing Terraform..."
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    sudo yum -y install terraform || { log "❌ Terraform installation failed!"; exit 1; }
    check_command terraform
}

install_docker() {
    log "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh || { log "❌ Docker installation failed!"; exit 1; }
    check_command docker
    sudo systemctl enable --now docker
    sudo systemctl status docker --no-pager || { log "❌ Docker failed to start!"; exit 1; }
    log "✅ Docker installed and running!"
}

install_kubernetes() {
    log "📦 Installing Kubernetes..."
    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF
    sudo yum install -y kubectl || { log "❌ Kubectl installation failed!"; exit 1; }
    check_command kubectl
}

install_prometheus() {
    log "📦 Installing Prometheus..."
    wget https://github.com/prometheus/prometheus/releases/download/v3.2.1/prometheus-3.2.1.linux-amd64.tar.gz
    tar -xvf prometheus-3.2.1.linux-amd64.tar.gz
    cd prometheus-3.2.1.linux-amd64
    sudo groupadd --system prometheus
    sudo useradd -s /sbin/nologin --system -g prometheus prometheus
    sudo cp prometheus /usr/local/bin
    sudo cp promtool /usr/local/bin
    sudo chown prometheus:prometheus /usr/local/bin/prometheus
    sudo chown prometheus:prometheus /usr/local/bin/promtool
    sudo mkdir /etc/prometheus
    sudo mkdir /var/lib/prometheus
    sudo cp prometheus.yml /etc/prometheus/
    sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
    log "✅ Prometheus installed successfully!"
    
    log "🔧 Setting up Prometheus as a service..."
    cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now prometheus
    sudo systemctl status prometheus --no-pager || { log "❌ Prometheus failed to start!"; exit 1; }
    log "✅ Prometheus service is running!"
}

install_grafana() {
    log "📦 Installing Grafana..."
    sudo yum install -y https://dl.grafana.com/oss/release/grafana-11.5.2-1.x86_64.rpm
    sudo systemctl daemon-reload
    sudo systemctl enable --now grafana-server
    sudo systemctl status grafana-server --no-pager || { log "❌ Grafana failed to start!"; exit 1; }
    log "✅ Grafana installed and running!"
}

# Display Menu
while true; do
    echo -e "\n📌 Select an option:"
    echo "1) Install Git"
    echo "2) Install Maven"
    echo "3) Install Ansible"
    echo "4) Install Jenkins"
    echo "5) Install SonarQube"
    echo "6) Install Nexus"
    echo "7) Install Terraform"
    echo "8) Install Docker"
    echo "9) Install Kubernetes"
    echo "10) Install Prometheus"
    echo "11) Install Grafana"
    echo "12) Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1) install_git ;;
        2) install_maven ;;
        3) install_ansible ;;
        4) install_jenkins ;;
        5) install_sonarqube ;;
        6) install_nexus ;;
        7) install_terraform ;;
        8) install_docker ;;
        9) install_kubernetes ;;
        10) install_prometheus ;;
        11) install_grafana ;;
        12) echo "Exiting..."; exit 0 ;;
        *) log "❌ Invalid choice! Please select a valid option." ;;
    esac
done
