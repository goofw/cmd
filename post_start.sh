while :; do docker run -d --rm -e USER_ID -e CF_TOKEN goofw/2048 && break || sleep 1; done
gh cs ports visibility 3000:public 4000:private 8080:public -c $CODESPACE_NAME
code-server --auth none --disable-telemetry --bind-addr 172.17.0.1:4000 &
