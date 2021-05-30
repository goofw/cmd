#!/bin/sh

SUM_FILE=/root/checksum
PID_FILE=/root/pids
WORK_DIR=/root/app

sha512sum -c $SUM_FILE || {
sha512sum /root/cmd.sh > $SUM_FILE

[ -f $PID_FILE ] && cat $PID_FILE | xargs kill
rm -rf $PID_FILE $WORK_DIR
mkdir -p $WORK_DIR
cd $WORK_DIR

cat > Caddyfile <<EOF
{
    admin off
}
:$PORT {
    @v {
        path /v$APP_ID
        header Connection *Upgrade*
        header Upgrade websocket
    }
    route {
        reverse_proxy @v 127.0.0.1:3080
        file_server $WORK_DIR/2048
    }
    log {
        level FATAL
    }
}
EOF

cat > config.json <<EOF
{
  "log": {
    "loglevel": "none"
  },
  "inbounds": [
    {
      "port": 3080,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$USER_ID"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/v$APP_ID"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

wget -qO - https://api.github.com/repos/caddyserver/caddy/releases/latest |
    grep -o "https://.*/caddy_.*_linux_amd64\.tar\.gz" | xargs wget -qO - | tar xz caddy
chmod +x caddy

wget -qO - https://api.github.com/repos/gabrielecirulli/2048/tarball | tar xz
mv gabrielecirulli-2048* 2048

./caddy start --pidfile $PID_FILE

wget -qO - https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip |
    unzip -q - v2ray geoip.dat geosite.dat
chmod +x v2ray
mv v2ray app

./app >/dev/null 2>&1 &
echo $! >> $PID_FILE
}

ps aux
sleep 600
wget -qO /root/cmd.sh https://raw.githubusercontent.com/goofw/cmd/HEAD/sh && exec /bin/sh /root/cmd.sh
