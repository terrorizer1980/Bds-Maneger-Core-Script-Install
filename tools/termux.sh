#!/data/data/com.termux/files/usr/bin/bash
set -ex
pkg update

# Java
if ! command -v java >/dev/null 2>&1; then
    apt install -y openjdk-17
fi

# Node
if ! command -v node >/dev/null 2>&1; then
    apt install -y nodejs
fi

# Golang
if ! command -v go >/dev/null 2>&1; then
    apt install -y golang
fi

# git
if ! command -v git >/dev/null 2>&1; then
    apt install -y git
fi

# Install Bds Maneger Core globally
if [ -z "${BDS_CORE_VERSION}" ];then
    npm i -g @the-bds-maneger/core@latest
else
    npm i -g @the-bds-maneger/core@${BDS_CORE_VERSION}
fi
exit 0