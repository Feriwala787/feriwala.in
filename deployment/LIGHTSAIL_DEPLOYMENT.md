# AWS Lightsail Deployment Guide

This repo already includes deployment scripts that work with AWS Lightsail.

## Prerequisites

- AWS account with a running **Lightsail Linux instance** (Ubuntu/Bitnami)
- Instance has static IP attached (recommended)
- Local machine has:
  - `bash`
  - `aws` CLI configured (`aws configure`)
  - `ssh`, `scp`, `rsync`
  - Node.js + npm (for building `admin-portal`)
- Ports opened in Lightsail networking:
  - `22` (SSH)
  - `80` (HTTP)
  - `443` (HTTPS, optional but recommended)
  - `3000` (only if you want to expose backend directly; normally proxied via nginx)

## Option A: Deploy using AWS CLI temporary SSH access (recommended)

This is the easiest flow for Lightsail because `deployment/deploy.sh` can auto-fetch temporary SSH credentials.

1. Configure environment variables:

```bash
export AWS_REGION=ap-south-1
export AWS_LIGHTSAIL_INSTANCE_NAME=<your-instance-name>
```

2. Optional: create `deployment/.env` to override defaults:

```dotenv
SERVER_HOST=<instance-public-ip>     # optional when AWS_LIGHTSAIL_INSTANCE_NAME is set
SSH_USER=bitnami                     # default: bitnami
REMOTE_DIR=/home/bitnami/feriwala    # default path used by scripts
```

3. Run deployment from repo root:

```bash
bash deployment/deploy.sh
```

The script will:
- sync backend files
- build and sync admin portal
- copy nginx + PM2 configs
- run remote setup commands
- restart nginx and PM2

## Option B: Deploy using a local PEM key

If you already downloaded a Lightsail key pair:

```bash
export SERVER_HOST=<instance-public-ip>
export SSH_USER=bitnami
export KEY_PATH=/path/to/lightsail-key.pem
bash deployment/deploy.sh
```

## Post-deploy checks

Run these on the server:

```bash
pm2 status
sudo nginx -t
curl -I http://localhost:3000
curl -I http://localhost
```

## DNS + HTTPS (recommended)

1. Point your domain A record to the Lightsail static IP.
2. Install certbot and issue certificate:

```bash
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d <your-domain> -d www.<your-domain>
```

## Troubleshooting

- **`SSH access not available`**: provide `KEY_PATH` or configure AWS CLI + `AWS_LIGHTSAIL_INSTANCE_NAME`.
- **rsync missing on server**: `deploy.sh` auto-installs it.
- **nginx config test fails**: run `sudo nginx -t` and inspect `/etc/nginx/sites-available/feriwala`.
- **PM2 app not running**: check logs with `pm2 logs feriwala-api`.

## Security notes

- Do **not** commit production secrets in shell scripts or `.env` files.
- Restrict inbound network rules to required ports only.
- Use least-privilege IAM credentials for deployments.
