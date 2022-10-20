FROM alpine
RUN apk add --no-cache tzdata iftop
COPY sh /root/cmd.sh
CMD exec /bin/sh /root/cmd.sh
