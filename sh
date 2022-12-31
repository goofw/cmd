#!/bin/sh

[ -z "$LOG_LEVEL" ] && LOG_LEVEL=fatal
[ "$LOG_LEVEL" = "debug" ] && CADDY_LOG=DEBUG
[ "$LOG_LEVEL" = "info" ] && CADDY_LOG=INFO
[ "$LOG_LEVEL" = "warn" ] && CADDY_LOG=WARN
[ "$LOG_LEVEL" = "error" ] && CADDY_LOG=ERROR
[ "$LOG_LEVEL" = "fatal" ] && CADDY_LOG=FATAL

[ -z "$INTERVAL" ] && INTERVAL=600
[ -z "$PORT" ] && PORT=8080
[ -z "$URL" ] && URL=https://raw.githubusercontent.com/goofw/cmd/HEAD/sh
[ -z "$USER_ID" ] && USER_ID=$(echo $URL | base64)

[ -z "$BASE_DIR" ] && BASE_DIR=/root
[ -z "$CMD_FILE" ] && CMD_FILE=$BASE_DIR/cmd.sh
SUM_FILE=$BASE_DIR/checksum
PID_FILE=$BASE_DIR/pids
WORK_DIR=$BASE_DIR/app

pgrep caddy >/dev/null || rm -rf $SUM_FILE
cat $CMD_FILE | sha512sum -c $SUM_FILE || {
cat $CMD_FILE | sha512sum > $SUM_FILE

[ -f $PID_FILE ] && cat $PID_FILE | xargs kill
rm -rf $PID_FILE $WORK_DIR
mkdir -p $WORK_DIR
cd $WORK_DIR

cat > Caddyfile <<EOF
{
    admin off
    auto_https disable_redirects
    log {
        level $CADDY_LOG
    }
}
:$PORT {
    @grpc {
        path /2046/*
        protocol grpc
    }
    @ws {
        path /2047
        header Connection *pgrade*
        header Upgrade websocket
    }
    route {
        reverse_proxy @grpc h2c://127.0.0.1:3333 {
            flush_interval -1
            header_up X-Real-IP {remote_host}
        }
        reverse_proxy @ws 127.0.0.1:4444
        file_server {
            root $WORK_DIR/2048
        }
    }
    log {
        level $CADDY_LOG
    }
}
EOF

cat > config.json <<EOF
{
  "log": {
    "level": "$LOG_LEVEL"
  },
  "dns": {
    "servers": [
      {
        "address": "tls://1.1.1.1:853",
        "strategy": "prefer_ipv4"
      }
    ]
  },
  "inbounds": [
    {
      "type": "direct",
      "tag": "in_dns",
      "listen": "127.0.0.1",
      "listen_port": 5353,
      "network": "tcp"
    },
    {
      "type": "vmess",
      "listen": "127.0.0.1",
      "listen_port": 3333,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4",
      "users": [
        {
          "uuid": "$USER_ID"
        }
      ],
      "transport": {
        "type": "grpc",
        "service_name": "2046"
      }
    },
    {
      "type": "vmess",
      "listen": "127.0.0.1",
      "listen_port": 4444,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4",
      "users": [
        {
          "uuid": "$USER_ID"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/2047"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "domain_strategy": "prefer_ipv4"
    },
    {
      "type": "dns",
      "tag": "out_dns"
    }
  ],
  "route": {
    "rules": [
      {
        "inbound": "in_dns",
        "outbound": "out_dns"
      }
    ]
  }
}
EOF
    
version=$(basename $(wget -S --spider https://github.com/caddyserver/caddy/releases/latest 2>&1 | grep Location | head -1 | cut -d' ' -f4))
wget -qO - https://github.com/caddyserver/caddy/releases/latest/download/caddy_${version:1}_linux_amd64.tar.gz | tar xz caddy
chmod +x caddy
XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp ./caddy start --pidfile $PID_FILE

wget -qO - https://github.com/goofw/app/releases/latest/download/app-linux-amd64.tar.gz | tar xz
chmod +x app
./app run &
echo $! >> $PID_FILE


wget -qO 2048.zip https://github.com/gabrielecirulli/2048/archive/refs/heads/master.zip
unzip -q 2048.zip && rm -f 2048.zip && mv 2048-master 2048
[ ! -d 2048 ] && wget -qO - https://api.github.com/repos/gabrielecirulli/2048/tarball | tar xz && mv gabrielecirulli-2048* 2048
    
version=$(basename $(wget -S --spider https://github.com/jpillora/sshd-lite/releases/latest 2>&1 | grep Location | head -1 | cut -d' ' -f4))
wget -qO - https://github.com/jpillora/sshd-lite/releases/latest/download/sshd-lite_${version:1}_Linux_x86_64\.gz | gzip -dc - >cli
chmod +x cli
[ -f /bin/bash ] && export SHELL=/bin/bash || export SHELL=/bin/sh
./cli --host 127.0.0.1 --port 2222 none >/dev/null 2>&1 &
echo $! >> $PID_FILE
}

sleep $INTERVAL
[ -z "$HEALTH_CHECK" ] || wget -q --spider $HEALTH_CHECK
wget -qO $CMD_FILE $URL && exec /bin/sh $CMD_FILE
