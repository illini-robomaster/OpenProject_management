# My OpenProject Deployment

Custom OpenProject deployment configuration with Docker Compose.

## Quick Start

1. Clone this repository
2. Copy `.env.prod.example` to `.env.prod` and customize
3. Run: `docker-compose -f docker-compose.simple.yml up -d`

## Files

- `docker-compose.simple.yml` - Main Docker Compose configuration
- `docker-compose.prod.yml` - Production overrides
- `.env.prod.example` - Environment template
- `backup.sh` - Backup script
- `health-check.sh` - Health monitoring
- `PRODUCTION_DEPLOYMENT.md` - Deployment guide

## Default Access

- URL: http://localhost:3000
- Username: admin
- Password: admin (change immediately!)

## Production Deployment

See `PRODUCTION_DEPLOYMENT.md` for complete production setup instructions.

## Security Notice

⚠️ Never commit actual passwords or sensitive configuration to git!
