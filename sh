#!/bin/sh

#wget -qO - https://github.com/go-gost/gost/releases/download/v3.0.0-beta.1/gost-linux-amd64-3.0.0-beta.1.gz | gzip -d > appg
#chmod +x appg
#./appg -L ss+grpc://AEAD_CHACHA20_POLY1305:196f6fba-fefe-4f29-876e-9d10a82e28df@:50051?grpcInsecure=true

WORK_DIR=/root/app
mkdir -p $WORK_DIR
cd $WORK_DIR

cat > config.json <<EOF
{
  "log": {
    "loglevel": "none",
    "access": "",
    "error": ""
  },
  "inbounds": [
    {
      "port": 50051,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "196f6fba-fefe-4f29-876e-9d10a82e28df"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "2047"
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

wget -qO v.zip https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
unzip -qp v.zip v2ray > app && rm -f v.zip
chmod +x app
if [ "$LOG_LEVEL" = "none" ]; then
    ./app >/dev/null 2>&1 &
else
    ./app &
fi
