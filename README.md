# nginx-proxy

A self-contained Docker Compose stack that acts as a reverse proxy for other containers on the same host. It automatically provisions and renews Let's Encrypt TLS certificates via Certbot and generates per-domain Nginx configs from a single environment variable.

## How it works

```
Internet → Nginx (80/443) → Docker containers (by name:port)
                ↑
           Certbot (webroot challenge + cron renewal)
```

1. **Certbot** starts first, issues certificates for every domain in `PROXY_DOMAINS` using the HTTP-01 webroot challenge, then schedules daily renewal via cron at 2am.
2. **Nginx** waits for Certbot to pass its healthcheck, then generates an `nginx/conf.d/<domain>.conf` file for each domain, sets up a nightly cron to reload itself at 2am (to pick up renewed certs), and starts serving traffic.

## Project structure

```
.
├── docker-compose.yml
├── .env
├── docker/
│   ├── nginx/
│   │   ├── Dockerfile
│   │   ├── conf/
│   │   │   ├── domain-template.conf   # Per-domain Nginx config template
│   │   │   └── healthcheck.conf       # /healthz stub_status endpoint
│   │   └── scripts/
│   │       ├── entrypoint.sh          # Copies healthcheck conf, generates domain configs, starts crond
│   │       └── create_proxy_domains.sh # Renders domain-template.conf for each PROXY_DOMAINS entry
│   └── certbot/
│       ├── Dockerfile
│       └── scripts/
│           ├── entrypoint.sh          # Issues certs on startup, schedules daily renewal
│           ├── create_certs.sh        # Runs certbot certonly per domain (skips existing certs)
│           └── healthcheck.sh         # Checks certbot binary + certificates dir
├── certbot/
│   ├── conf/                          # Let's Encrypt data (mounted into both containers)
│   └── www/                           # Webroot for ACME challenge (mounted into both containers)
└── nginx/
    └── conf.d/                        # Generated per-domain configs (mounted into Nginx)
```

> `certbot/` and `nginx/conf.d/` are created at runtime — do not commit them.

## Getting started

```bash
git clone https://github.com/NgatiaFrankline/nginx-proxy-docker-setup.git
cd nginx-proxy-docker-setup
```

Create your `.env` file (it is gitignored — never committed):

```bash
cp .env.example .env   # or create it from scratch — see Configuration below
```

## Configuration

Copy `.env` and fill in your values:

```dotenv
PROXY_NAME=proxy
CERTBOT_EMAIL=you@example.com
CERTBOT_STAGING=true
SKIP_CERTBOT=false
DEBUG_NGINX_TEMPLATE=false
PROXY_DOMAINS=example.com:app:3000,www.example.com:app:3000,api.example.com:api:8080
```

### Environment variables

| Variable               | Required | Description                                                                                         |
|------------------------|----------|-----------------------------------------------------------------------------------------------------|
| `PROXY_NAME`           | yes      | Suffix appended to container names (`nginx-<name>`, `certbot-<name>`).                              |
| `CERTBOT_EMAIL`        | yes      | Email address for Let's Encrypt account and expiry notices.                                         |
| `CERTBOT_STAGING`      | yes      | `true` to use the Let's Encrypt staging CA (for testing), `false` for production certificates.      |
| `SKIP_CERTBOT`         | yes      | `true` to skip certificate issuance entirely (useful when testing Nginx config without DNS set up). |
| `DEBUG_NGINX_TEMPLATE` | no       | `true` to print the rendered Nginx config to stdout for each domain after it is generated.          |
| `PROXY_DOMAINS`        | yes      | Comma-separated list of `domain:container_name:port` entries (see below).                           |

### `PROXY_DOMAINS` format

```
PROXY_DOMAINS=<domain>:<container>:<port>[,<domain>:<container>:<port>...]
```

- `<domain>` — the public hostname (must resolve to this host's IP)
- `<container>` — the name of the target Docker container on the `proxy-network`
- `<port>` — the port the target container listens on

Before creating a server configuration, Nginx checks that the target container
name resolves on `proxy-network`. If it does not resolve, that domain is skipped
with an error while the remaining entries continue to be processed. The
cert-watcher retries skipped entries every 30 seconds, so the configuration is
created automatically after the target container becomes resolvable.

Example:

```dotenv
PROXY_DOMAINS=example.com:frontend:3000,www.example.com:frontend:3000,api.example.com:backend:8080
```

This generates three Nginx server blocks and requests three Let's Encrypt certificates.

## Security hardening

This stack is hardened by default for a public-facing reverse proxy:

- Unknown HTTP hosts return `444` and unknown HTTPS handshakes are rejected.
- TLS is restricted to `TLSv1.2` and `TLSv1.3`.
- Nginx hides version headers (`server_tokens off`) and adds security headers such as HSTS, a WordPress-compatible CSP, and `Permissions-Policy`.
- Basic per-IP request throttling and connection limiting are enabled to reduce abuse.
- Both containers run with `no-new-privileges`, drop all Linux capabilities except `DAC_OVERRIDE` and `CHOWN` (needed for mounted volumes and Nginx runtime directories), and use a read-only root filesystem.
- The Nginx container reads the certificate directory as read-only while Certbot keeps write access.
- Application containers should not expose their own ports publicly; they should only be reachable through the proxy network.

If you want to tune the protection levels, edit the generated Nginx config templates and the rate-limit definitions in `docker/nginx/scripts/entrypoint.sh`.

## Usage

### First run (staging)

Start with `CERTBOT_STAGING=true` to verify everything works without hitting Let's Encrypt rate limits:

```bash
docker compose up -d
docker compose logs -f
```

Check that certificates were issued and Nginx is healthy:

```bash
docker compose ps
```

### Switch to production certificates

Once staging succeeds, set `CERTBOT_STAGING=false` and delete the staging certs so they are re-issued:

```bash
# Remove staging certs
sudo rm -rf ./certbot/conf

# Re-deploy
docker compose down
docker compose up -d
```

### Debug generated Nginx configs

Set `DEBUG_NGINX_TEMPLATE=true` to print each rendered `conf.d/<domain>.conf` to stdout as it is created. Useful for verifying domain, container name, and port substitutions are correct without exec-ing into the container.

```dotenv
DEBUG_NGINX_TEMPLATE=true
```

```bash
docker compose up nginx
# logs will include the full rendered config block for each domain
```

### Connect your application containers

Target containers must be on the same `proxy-network`. Add this to their `docker-compose.yml`:

```yaml
networks:
  proxy-network:
    external: true
    name: <PROXY_NAME>_proxy-network   # e.g. proxy_proxy-network
```

And assign the network to each service that the proxy should reach.

## Services

### `certbot`

- Image: `certbot/certbot:v5.6.0`
- Issues a certificate per domain on startup (skips domains that already have a valid cert).
- Schedules `certbot renew --webroot` daily at 2am via cron.
- Healthcheck: verifies the certbot binary works and can read the certificates directory.

### `nginx`

- Image: `nginx:1.31.2-alpine`
- Starts only after `certbot` is healthy (`depends_on: condition: service_healthy`).
- Generates one `conf.d/<domain>.conf` per entry in `PROXY_DOMAINS` from `domain-template.conf`.
- Each config: redirects HTTP → HTTPS, terminates TLS, proxies to the target container, and sets standard security headers (`HSTS`, `X-Frame-Options`, `X-Content-Type-Options`, CSP, and `Permissions-Policy`).

### Content Security Policy

The generated domain config includes a CSP that supports typical WordPress themes
and plugins: inline scripts/styles, Google Fonts, data-URI fonts, blob workers,
and HTTPS assets are allowed. The policy includes `'unsafe-inline'` and `'unsafe-eval'`
because many WordPress plugins depend on them. If the application defines its
own CSP, remove or replace the `Content-Security-Policy` header in
`docker/nginx/conf/domain-template.conf`; the proxy cannot infer which
third-party services a site needs.
- Schedules `nginx -s reload` daily at 2am to pick up renewed certificates.
- Healthcheck: `curl http://localhost/healthz` (nginx `stub_status`).

## Volumes

| Host path         | Container path            | Used by           |
|-------------------|---------------------------|-------------------|
| `./certbot/conf`  | `/etc/letsencrypt`        | nginx + certbot   |
| `./certbot/www`   | `/var/www/certbot`        | nginx + certbot   |
| `./nginx/conf.d`  | `/etc/nginx/conf.d`       | nginx             |

## Networking

Both containers share the `proxy-network` bridge network. Application containers that the proxy routes to must also be attached to this network.
