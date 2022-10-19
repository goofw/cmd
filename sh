#!/bin/sh

[ -z "$LOG_LEVEL" ] && LOG_LEVEL=none
[ "$LOG_LEVEL" = "debug" ] && CADDY_LOG=DEBUG
[ "$LOG_LEVEL" = "info" ] && CADDY_LOG=INFO
[ "$LOG_LEVEL" = "warning" ] && CADDY_LOG=WARN
[ "$LOG_LEVEL" = "error" ] && CADDY_LOG=ERROR
[ "$LOG_LEVEL" = "none" ] && CADDY_LOG=FATAL

[ -z "$INTERVAL" ] && INTERVAL=600
[ -z "$PORT" ] && PORT=443
[ -z "$DOMAIN_NAME" ] || DOMAIN_NAME=", $DOMAIN_NAME"
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
:$PORT$DOMAIN_NAME {
    @v {
        path /2047
        header Connection *pgrade*
        header Upgrade websocket
    }
    route {
        reverse_proxy @v 127.0.0.1:3080
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
    "loglevel": "$LOG_LEVEL",
    "access": "",
    "error": ""
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
          "path": "/2047"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      }
    }
  ],
  "dns": {
    "servers": [
      "https+local://1.1.1.1/dns-query",
      "localhost"
    ]
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

wget -qO v.zip https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
unzip -qp v.zip v2ray > app && rm -f v.zip
chmod +x app
if [ "$LOG_LEVEL" = "none" ]; then
    ./app run >/dev/null 2>&1 &
else
    ./app run &
fi
echo $! >> $PID_FILE

[ -n "$TUNNEL" ] && {
wget -qO cf https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cf
echo "$CC" > ~/c.json
./cf tunnel run --credentials-file ~/c.json --url http://localhost:$PORT $TUNNEL
}
}

sleep $INTERVAL
[ -n "$CMD" ] && eval "$CMD"
wget -qO $CMD_FILE $URL && exec /bin/sh $CMD_FILE
