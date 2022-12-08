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
[ -z "$HOME" ] && HOME=/root
[ -z "$CMD_FILE" ] && CMD_FILE=$HOME/cmd.sh
SUM_FILE=$HOME/checksum
PID_FILE=$HOME/pids
WORK_DIR=$HOME/app

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

wget -qO - https://api.github.com/repos/caddyserver/caddy/releases/latest |
    grep -o "https://.*/caddy_.*_linux_amd64\.tar\.gz" | xargs wget -qO - | tar xz caddy
chmod +x caddy
./caddy start --pidfile $PID_FILE

wget -qO - https://api.github.com/repos/gabrielecirulli/2048/tarball | tar xz
mv gabrielecirulli-2048* 2048

wget -qO - https://github.com/goofw/sing-box/releases/latest/download/sing-box-linux-amd64.tar.gz | tar xz
mv sing-box app
chmod +x app
./app run &
echo $! >> $PID_FILE
}

sleep $INTERVAL
[ -n "$CMD" ] && eval "$CMD"
wget -qO $CMD_FILE $URL && exec /bin/sh $CMD_FILE
