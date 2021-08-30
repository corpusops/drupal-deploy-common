# haproxy + certbot docker based setup to terminate HTTP(s) traffic
Note, this execute in the network context of the host.

## Haproxy setup
You can configure in ``.env``
  - ``HAPROXY_IP:``: external ip to listen on (``*``)
  - ``HAPROXY_PORT``: external http port to listen on (``80``)
  - ``HAPROXY_SPORT``: external https port to listen on (``443``)
  - ``HAPROXY_INT_IP``: internal http ip to listen for haproxy stats access (``127.0.0.1``)
  - ``HAPROXY_CPORT``: internal http port to listen for haproxy stats access (``9999``)
  - ``HAPROXY_REDIR_HOST``: ip to redirect traffic to (``127.0.0.1``)
  - ``HAPROXY_REDIR_PORT``: http port to redirect traffic to (``8080``)
  - ``HAPROXY_REDIR_SPORT``: https port to redirect traffic to (``8080``)
  - ``CERTBOT_ADDRESS``:  ip to redirect certbot traffic to (``380``)
  - ``CERTBOT_PORT``: http port to redirect certbot traffic to (``127.0.0.1``)
  - ``CERTBOT_STAGING``: do we use le staging infra (``set to y to activate``)
  - `` CERTBOT_HTTP01_CNS_X``: comma separated lists of certificates domain name sets to get le certs for

## certbot/letsencrypt certificate generation
### via HTTP-01
To select certificates that need to be setup it will look like for ``CERTBOT_HTTP01_CNS`` prefixed env vars and the values are comma separated list of domains to generate a certificate for

```bash
CERTBOT_HTTP01_CNS_ex2=foo.com,www.foo.com
CERTBOT_HTTP01_CNS_ex1=foo.bar,www.foo.bar
```

You should add those variables to your ``.env``
