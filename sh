#!/bin/sh

wget -qO - https://github.com/go-gost/gost/releases/download/v3.0.0-beta.1/gost-linux-amd64-3.0.0-beta.1.gz | gzip -d > appg
chmod +x appg
./appg -L ss+grpc://AEAD_CHACHA20_POLY1305:196f6fba-fefe-4f29-876e-9d10a82e28df@:50051?grpcInsecure=true
