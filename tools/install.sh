#!/bin/bash
#

TMP_PATH=/tmp
SUDO=""
_USER=""

# Check is root
if [ "$(id -u)" != "0" ]; then
    if command -v sudo &> /dev/null; then
        echo "This script must be run as root" 1>&2
        SUDO="sudo"
    else
        echo "This script must be run as root" 1>&2
        exit 1
    fi
fi

# Get sudo user
if [ -z "${SUDO_USER}" ]; then
    read -rp "Enter sudo user: " _USER
else
    if [ -z "${SUDO_USER}" ]; then
        read -rp "Enter sudo user: " _USER
    else
        _USER="${SUDO_USER}"
    fi
fi

# Docker engine install
docker_install() {
    curl -fsSL https://get.docker.com -o ${TMP_PATH}/get-docker.sh
    ${SUDO} sh ${TMP_PATH}/get-docker.sh
    ${SUDO} usermod -aG docker ${_USER}
}

# Compose installer
docker_compose_install() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is already installed"
    else
        echo "Docker is not installed"
        docker_install
    fi
    if [ "$(uname -m)" = "x86_64" ]; then
        COMPOSE_RELEASE="$(curl -sSL https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')"
        ${SUDO} wget https://github.com/docker/compose/releases/download/${COMPOSE_RELEASE}/docker-compose-Linux-x86_64 -O /usr/local/bin/docker-compose
        ${SUDO} chmod +x /usr/local/bin/docker-compose
    elif [ "$(uname -m)" = "aarch64" ]; then
        COMPOSE_RELEASE="$(curl -sSL https://api.github.com/repos/wojiushixiaobai/docker-compose-aarch64/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')"
        ${SUDO} wget https://github.com/wojiushixiaobai/docker-compose-aarch64/releases/download/${COMPOSE_RELEASE}/docker-compose-Linux-aarch64 -O /usr/local/bin/docker-compose
        ${SUDO} chmod +x /usr/local/bin/docker-compose
    else
        echo "Unsupported architecture"
        exit 1
    fi
}

# Install software to Bds Core
bds_core_software_install() {
    set -ex
    # NodeJS
    if command -v node &> /dev/null; then
        echo "Node is already installed"
    else
        echo "Node is not installed"
        if [ -f "/etc/os-release" ]; then
            curl -sL https://deb.nodesource.com/setup_current.x | ${SUDO} bash -
            ${SUDO} apt-get install -y nodejs
        elif [ -f "/etc/redhat-release" ]; then
            curl -sL https://rpm.nodesource.com/setup_8.x | ${SUDO} bash -
            ${SUDO} yum install -y nodejs
        else
            echo "We do not support this system"
            echo "Install nodejs (16+), openjdk (16+), golang (*), git (*)"
            exit 1
        fi
    fi

    # GoLang
    if command -v go &> /dev/null; then
        echo "Go is already installed"
    else
        echo "Go is not installed"
        if [ -f "/etc/os-release" ]; then
            ${SUDO} apt-get install -y golang
        elif [ -f "/etc/redhat-release" ]; then
            ${SUDO} yum install -y golang
        else
            echo "We do not support this system"
            echo "Install nodejs (16+), openjdk (16+), golang (*), git (*)"
            exit 1
        fi
    fi

    # Git
    if command -v git &> /dev/null; then
        echo "Git is already installed"
    else
        echo "Git is not installed"
        if [ -f "/etc/os-release" ]; then
            ${SUDO} apt-get install -y git
        elif [ -f "/etc/redhat-release" ]; then
            ${SUDO} yum install -y git
        else
            echo "We do not support this system"
            echo "Install nodejs (16+), openjdk (16+), golang (*), git (*)"
            exit 1
        fi
    fi

    # Openjdk
    if command -v java &> /dev/null; then
        echo "Openjdk is already installed"
    else
        echo "Openjdk is not installed"
        if [ -f "/etc/os-release" ]; then
            case "$(apt list *openjdk*)" in
                *openjdk*18*)
                    apt-get install -y openjdk-18*
                    ;;
                *openjdk*17*)
                    apt-get install -y openjdk-17*
                    ;;
                *openjdk*16*)
                    apt-get install -y openjdk-16*
                    ;;
                *)
                    echo "We do not support this system"
                    echo "Install nodejs (16+), openjdk (16+), golang (*), git (*)"
                    exit 1
                    ;;
            esac
        elif [ -f "/etc/redhat-release" ]; then
            case "$(yum list *openjdk*)" in
                *openjdk*18*)
                    yum install -y java-1.8.0-openjdk-devel
                    ;;
                *openjdk*17*)
                    yum install -y java-1.7.0-openjdk-devel
                    ;;
                *openjdk*16*)
                    yum install -y java-1.6.0-openjdk-devel
                    ;;
                *)
                    echo "We do not support this system"
                    echo "Install nodejs (16+), openjdk (16+), golang (*), git (*)"
                    exit 1
                    ;;
            esac
        else
            echo "We do not support this system"
            echo "Install nodejs (16+), openjdk (16+), golang (*), git (*)"
            exit 1
        fi
    fi

    # Setup Bds Core
    mkdir -p /opt/BdsManeger/
    # Clone Bds Core
    git clone https://github.com/The-Bds-Maneger/Bds-Maneger-Core.git /opt/BdsManeger/Core
    cd /opt/BdsManeger/Core
    
    # Install Bds Core node dependencies
    npm install --no-save

    # create systemd service
    (
        echo "[Unit]"
        echo "Description=Bds Core"
        echo "After=network.target"
        echo ""
        echo "[Service]"
        echo "User=root"
        echo "WorkingDirectory=/opt/BdsManeger/Core"
        echo "ExecStart=/usr/bin/node /opt/BdsManeger/Core/bin/Docker.js -skd"
        echo "Restart=always"
        echo "RestartSec=10"
        echo ""
        echo "[Install]"
        echo "WantedBy=multi-user.target"
    ) | tee /etc/systemd/system/bds-core.service

    # Enable systemd service
    ${SUDO} systemctl daemon-reload
    ${SUDO} systemctl enable bds-core.service
    ${SUDO} systemctl start bds-core.service
}

echo "Checking installed software"
if [ "${INSTALL_TYPE}" == "docker" ]; then
    if ! command -v docker &> /dev/null; then
        echo "Docker is already installed"
    else
        echo "Docker is not installed"
        docker_install
    fi
elif [ "${INSTALL_TYPE}" == "docker-compose" ]; then
    if ! command -v docker-compose &> /dev/null; then
        echo "Docker-compose is already installed"
    else
        echo "Docker-compose is not installed"
        docker_compose_install
    fi
elif [ "${INSTALL_TYPE}" == "local" ]; then
    if command -v apt &> /dev/null || command -v yum &> /dev/null; then
        bds_core_software_install
    else
        echo "We do not support this system"
        echo "Install nodejs (16+), openjdk (16+), golang (*), git (*)"
        exit 1
    fi
else
    echo "Select valid Install"
    exit 1
fi