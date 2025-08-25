# Quick Start Commands for OpenProject Management

## Current Status Commands

```bash
# Check status of all containers
docker-compose -f docker-compose.simple.yml ps

# View logs
docker-compose -f docker-compose.simple.yml logs -f web
docker-compose -f docker-compose.simple.yml logs --tail=100

# Health check
./health-check.sh
```

## Management Commands

```bash
# Start OpenProject (development)
docker-compose -f docker-compose.simple.yml up -d

# Stop OpenProject
docker-compose -f docker-compose.simple.yml down

# Restart specific service
docker-compose -f docker-compose.simple.yml restart web

# Update OpenProject (pull new images)
docker-compose -f docker-compose.simple.yml pull
docker-compose -f docker-compose.simple.yml up -d --build
```

## Backup and Restore

```bash
# Create backup
./backup.sh

# Manual backup commands
docker-compose -f docker-compose.simple.yml exec -T db pg_dump -U postgres openproject > backup_$(date +%Y%m%d).sql
```

## Production Deployment

```bash
# For production deployment, use:
docker-compose -f docker-compose.simple.yml -f docker-compose.prod.yml --env-file .env.prod up -d
```

## Troubleshooting

```bash
# Check specific container logs
docker logs openproject_web_1
docker logs openproject_db_1
docker logs openproject_proxy_1

# Access container shell
docker exec -it openproject_web_1 bash
docker exec -it openproject_db_1 bash

# Check volume data
docker volume ls
docker volume inspect openproject_opdata
docker volume inspect openproject_pgdata

# Database access
docker-compose -f docker-compose.simple.yml exec db psql -U postgres -d openproject
```

## Cleanup Commands (Use with caution!)

```bash
# Remove containers and networks (keeps volumes/data)
docker-compose -f docker-compose.simple.yml down

# Remove everything including volumes (DESTROYS DATA!)
docker-compose -f docker-compose.simple.yml down -v

# Remove unused images and containers
docker system prune
```