FROM alpine
COPY sh /root/cmd.sh
CMD exec /bin/sh /root/cmd.sh
