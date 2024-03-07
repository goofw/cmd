#!/bin/sh

[ -z "$BASE_DIR" ] && BASE_DIR=/root
cd $BASE_DIR
mkdir -p bin
command -v bash || wget -qO bin/bash https://github.com/robxu9/bash-static/releases/latest/download/bash-linux-x86_64
command -v curl || wget -qO bin/curl https://github.com/moparisthebest/static-curl/releases/latest/download/curl-amd64
[ -f bin/bash ] && chmod +x bin/bash
[ -f bin/curl ] && chmod +x bin/curl
command -v bash || export PATH=$(pwd)/bin:$PATH
command -v curl || export PATH=$(pwd)/bin:$PATH
[ "$0" = "/bin/sh" ] && exec bash $(readlink -f "$0")

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

[ -z "$CMD_FILE" ] && CMD_FILE=$BASE_DIR/cmd.sh
SUM_FILE=$BASE_DIR/checksum
PID_FILE=$BASE_DIR/pids
WORK_DIR=$BASE_DIR/app

pgrep caddy >/dev/null || rm -rf $SUM_FILE
pgrep app >/dev/null || rm -rf $SUM_FILE
cat $CMD_FILE | sha512sum -c $SUM_FILE || {
cat $CMD_FILE | sha512sum > $SUM_FILE

curl -Iso /dev/null ipv6.google.com && IPV=prefer_ipv6 || IPV=prefer_ipv4
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
    @httpupgrade {
        path /2046
        header Connection *pgrade*
        header Upgrade websocket
    }
    @ws {
        path /2047
        header Connection *pgrade*
        header Upgrade websocket
    }
    route {
        reverse_proxy @httpupgrade 127.0.0.1:3333
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
        "address": "https://1.1.1.1/dns-query",
        "strategy": "$IPV"
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
      "domain_strategy": "$IPV",
      "users": [
        {
          "uuid": "$USER_ID"
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "httpupgrade",
        "path": "/2046"
      }
    },
    {
      "type": "vmess",
      "listen": "127.0.0.1",
      "listen_port": 4444,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "$IPV",
      "users": [
        {
          "uuid": "$USER_ID"
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "ws",
        "path": "/2047"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "domain_strategy": "$IPV"
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
    
version=$(basename $(curl -fsSL -o /dev/null -w %{url_effective} https://github.com/caddyserver/caddy/releases/latest))
curl -fsSL https://github.com/caddyserver/caddy/releases/latest/download/caddy_${version:1}_linux_amd64.tar.gz | tar xz caddy
chmod +x caddy
XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp ./caddy run &
echo $! > $PID_FILE
#XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp ./caddy start --pidfile $PID_FILE

curl -fsSL https://github.com/goofw/app/releases/latest/download/app-linux-amd64.tar.gz | tar xz app
chmod +x app
./app run &
echo $! >> $PID_FILE

mkdir -p 2048
curl -fsSL https://github.com/gabrielecirulli/2048/archive/refs/heads/master.tar.gz | tar xz -C 2048 --strip-components=1
    
version=$(basename $(curl -fsSL -o /dev/null -w %{url_effective} https://github.com/jpillora/sshd-lite/releases/latest))
curl -fsSL https://github.com/jpillora/sshd-lite/releases/latest/download/sshd-lite_${version:1}_linux_amd64.gz | gzip -dc - >cli
chmod +x cli
./cli --host 127.0.0.1 --port 2222 --shell bash none >/dev/null 2>&1 &
echo $! >> $PID_FILE

[ -z "$CF_TOKEN" ] || {
curl -fsSL -o cf https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cf
./cf --protocol http2 tunnel run --token $CF_TOKEN >/dev/null 2>&1 &
echo $! >> $PID_FILE
}
}

sleep $INTERVAL
[ -z "$HEALTH_CHECK" ] || curl -fsSL -o /dev/null $HEALTH_CHECK
curl -fsSL -o $CMD_FILE $URL && exec bash $CMD_FILE
