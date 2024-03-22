mkdir -p /root/.ssh && echo $SSH_KEY >/root/.ssh/authorized_keys
curl -fsSL https://code-server.dev/install.sh | sh

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
