#!/bin/bash

# OpenProject Health Check Script
# This script checks the health of your OpenProject deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "OpenProject Health Check"
echo "======================="
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker is running${NC}"
fi

# Check container status
echo ""
echo "Container Status:"
echo "-----------------"

CONTAINERS=("openproject_web_1" "openproject_worker_1" "openproject_cron_1" "openproject_db_1" "openproject_cache_1" "openproject_proxy_1")

for container in "${CONTAINERS[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "$container"; then
        status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
        if [ "$status" = "healthy" ]; then
            echo -e "${GREEN}✅ $container - healthy${NC}"
        elif [ "$status" = "no-healthcheck" ]; then
            if docker inspect --format='{{.State.Status}}' "$container" | grep -q "running"; then
                echo -e "${GREEN}✅ $container - running${NC}"
            else
                echo -e "${RED}❌ $container - not running${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  $container - $status${NC}"
        fi
    else
        echo -e "${RED}❌ $container - not found${NC}"
    fi
done

# Check OpenProject accessibility
echo ""
echo "Application Health:"
echo "------------------"

PORT=$(grep "^PORT=" .env 2>/dev/null | cut -d'=' -f2 || echo "3000")
URL="http://localhost:${PORT}"

if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q "302\|200"; then
    echo -e "${GREEN}✅ OpenProject is accessible at $URL${NC}"
else
    echo -e "${RED}❌ OpenProject is not accessible at $URL${NC}"
fi

# Check disk space
echo ""
echo "Disk Usage:"
echo "-----------"

# Check Docker volumes
echo "Docker volumes:"
docker system df -v | grep -E "(VOLUME|openproject)" || echo "No OpenProject volumes found"

# Check system disk space
echo ""
echo "System disk usage:"
df -h / | tail -n 1 | awk '{
    usage = $5
    gsub(/%/, "", usage)
    if (usage > 90) 
        print "\033[0;31m❌ Disk usage: " $5 " (critically high)\033[0m"
    else if (usage > 80)
        print "\033[1;33m⚠️  Disk usage: " $5 " (high)\033[0m"  
    else
        print "\033[0;32m✅ Disk usage: " $5 " (normal)\033[0m"
}'

# Check memory usage
echo ""
echo "Memory Usage:"
echo "-------------"
free -h | awk '
    NR==2 {
        total = $2
        used = $3
        usage_percent = (used/total)*100
        if (usage_percent > 90)
            print "\033[0;31m❌ Memory usage: " used "/" total " (" int(usage_percent) "%) - critically high\033[0m"
        else if (usage_percent > 80)
            print "\033[1;33m⚠️  Memory usage: " used "/" total " (" int(usage_percent) "%) - high\033[0m"
        else
            print "\033[0;32m✅ Memory usage: " used "/" total " (" int(usage_percent) "%)\033[0m"
    }'

# Check recent logs for errors
echo ""
echo "Recent Issues:"
echo "-------------"

ERROR_COUNT=$(docker-compose -f docker-compose.simple.yml logs --since="1h" 2>/dev/null | grep -i "error\|fatal\|exception" | wc -l)

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $ERROR_COUNT error(s) in the last hour${NC}"
    echo "Recent errors:"
    docker-compose -f docker-compose.simple.yml logs --since="1h" 2>/dev/null | grep -i "error\|fatal\|exception" | tail -n 5
else
    echo -e "${GREEN}✅ No errors found in the last hour${NC}"
fi

echo ""
echo "Health check completed at $(date)"
echo ""

# Provide recommendations
echo "Recommendations:"
echo "---------------"
echo "• Run this health check regularly"
echo "• Monitor disk space and clean up old logs if needed"
echo "• Create regular backups using ./backup.sh"
echo "• Check OpenProject logs with: docker-compose logs -f web"
