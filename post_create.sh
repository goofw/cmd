mkdir -p /root/.ssh && echo $SSH_KEY >/root/.ssh/authorized_keys
curl -fsSL https://code-server.dev/install.sh | sh
version=$(basename $(curl -fsSL -o /dev/null -w %{url_effective} https://github.com/gitpod-io/openvscode-server/releases/latest))
curl -fsSL https://github.com/gitpod-io/openvscode-server/releases/latest/download/$version-linux-x64.tar.gz | tar xz
mv $version-linux-x64 /usr/local/openvscode-server
ln -fsnv /usr/local/openvscode-server/bin/openvscode-server /usr/local/bin/openvscode-server

apt-get update \
    && apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        tmux \
        vim \
        man \
        net-tools \
        dnsutils \
        iputils-ping \
        telnet
