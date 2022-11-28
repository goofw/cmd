#!/bin/sh

[ -z "$LOG_LEVEL" ] && LOG_LEVEL=fatal
[ "$LOG_LEVEL" = "debug" ] && CADDY_LOG=DEBUG
[ "$LOG_LEVEL" = "info" ] && CADDY_LOG=INFO
[ "$LOG_LEVEL" = "warn" ] && CADDY_LOG=WARN
[ "$LOG_LEVEL" = "error" ] && CADDY_LOG=ERROR
[ "$LOG_LEVEL" = "fatal" ] && CADDY_LOG=FATAL

[ -z "$INTERVAL" ] && INTERVAL=600
[ -z "$PORT" ] && PORT=443
[ -z "$DOMAIN_NAME" ] || DOMAIN_LINE=", $DOMAIN_NAME"
[ -z "$URL" ] && URL=https://raw.githubusercontent.com/goofw/cmd/HEAD/sh
[ -z "$CMD_FILE" ] && CMD_FILE=/root/cmd.sh
SUM_FILE=/root/checksum
PID_FILE=/root/pids
WORK_DIR=/root/app

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
tcp/:$PORT$DOMAIN_LINE {
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

wget -qO - https://api.github.com/repos/caddyserver/caddy/releases/latest |
    grep -o "https://.*/caddy_.*_linux_amd64\.tar\.gz" | xargs wget -qO - | tar xz caddy
chmod +x caddy
# $XDG_DATA_HOME/caddy or $HOME/.local/share/caddy
./caddy start --pidfile $PID_FILE

wget -qO - https://api.github.com/repos/gabrielecirulli/2048/tarball | tar xz
mv gabrielecirulli-2048* 2048

while true; do
    CRT_PATH=$(find /root/.local/share -name ${DOMAIN_NAME}.crt)
    KEY_PATH=$(find /root/.local/share -name ${DOMAIN_NAME}.key)
    [ -z "$CRT_PATH" -o -z "$KEY_PATH" ] || break
    sleep 2
done

cat > config.json <<EOF
{
  "log": {
    "level": "$LOG_LEVEL"
  },
  "dns": {
    "servers": [
      {
        "address": "tls://[2606:4700:4700::1111]:853",
        "strategy": "prefer_ipv6"
      }
    ]
  },
  "inbounds": [
    {
      "type": "vmess",
      "listen_port": 3333,
      "domain_strategy": "prefer_ipv6",
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
      "listen_port": 4444,
      "domain_strategy": "prefer_ipv6",
      "users": [
        {
          "uuid": "$USER_ID"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/2047"
      }
    },
    {
      "type": "hysteria",
      "listen_port": 443,
      "domain_strategy": "prefer_ipv6",
      "up": "100 Mbps",
      "down": "100 Mbps",
      "obfs": "$USER_ID",
      "users": [
        {
          "auth_str": "$USER_ID"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "$CRT_PATH",
        "key_path": "$KEY_PATH"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct",
      "domain_strategy": "prefer_ipv6"
    }
  ]
}
EOF

wget -qO - https://api.github.com/repos/SagerNet/sing-box/releases/latest |
    grep -o "https://.*/sing-box-.*-linux-amd64\.tar\.gz" | xargs wget -qO - | tar xz
mv sing-box-*-linux-amd64/sing-box app && rm -rf sing-box-*-linux-amd64
chmod +x app
./app run &
echo $! >> $PID_FILE
}

sleep $INTERVAL
[ -n "$CMD" ] && eval "$CMD"
wget -qO $CMD_FILE $URL && exec /bin/sh $CMD_FILE
