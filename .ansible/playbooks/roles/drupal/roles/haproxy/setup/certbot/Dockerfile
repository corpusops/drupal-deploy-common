FROM certbot/certbot
# Install socat
RUN apk update && apk add socat
# Copy scripts
COPY ./scripts/ /etc/scripts/
# Expose port 380
EXPOSE 380
