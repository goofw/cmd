while :; do docker run -d --rm -e USER_ID -e CF_TOKEN --network host goofw/2048 && break || sleep 1; done
gh cs ports visibility 3000:public 4000:private 8080:public -c $CODESPACE_NAME
tmux new -d code-server --bind-addr 127.0.0.1:4000 --auth none --disable-telemetry --disable-workspace-trust --disable-getting-started-override
#tmux new -d openvscode-server --host 172.17.0.1 --port 4000 --without-connection-token --disable-telemetry
