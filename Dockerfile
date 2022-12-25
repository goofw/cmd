FROM alpine
RUN apk add --no-cache neofetch
COPY sh /root/cmd.sh
CMD exec /bin/sh /root/cmd.sh
