#!/bin/bash
# =============================================================================
# TypeORM/NestJS DB → Rails DB Migration Script
# =============================================================================
#
# Usage:
#   ./scripts/migrate_db_to_rails.sh dev    # dev 환경
#   ./scripts/migrate_db_to_rails.sh prd    # production 환경
#
# Prerequisites:
#   - PostgreSQL client (psql, pg_dump, pg_restore)
#   - Ruby/Rails environment
#
# =============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Configuration - Edit these values for your environment
# =============================================================================

# Source DB (TypeORM/NestJS - camelCase) - DO NOT MODIFY SOURCE DB
declare -A SOURCE_DB_DEV=(
    [host]="switchback.proxy.rlwy.net"
    [port]="46113"
    [user]="postgres"
    [password]="JbkuMuXarMzVeIBKFghwecutvIwKqQIQ"
    [database]="railway"
)

declare -A SOURCE_DB_PRD=(
    [host]="REPLACE_WITH_PRD_SOURCE_HOST"
    [port]="REPLACE_WITH_PRD_SOURCE_PORT"
    [user]="postgres"
    [password]="REPLACE_WITH_PRD_SOURCE_PASSWORD"
    [database]="railway"
)

# Target DB (Rails - snake_case)
declare -A TARGET_DB_DEV=(
    [host]="centerbeam.proxy.rlwy.net"
    [port]="58260"
    [user]="postgres"
    [password]="zHhOOZLFpfxLfFOLnRkAIgdYjaqaNyhu"
    [database]="railway"
)

declare -A TARGET_DB_PRD=(
    [host]="REPLACE_WITH_PRD_TARGET_HOST"
    [port]="REPLACE_WITH_PRD_TARGET_PORT"
    [user]="postgres"
    [password]="REPLACE_WITH_PRD_TARGET_PASSWORD"
    [database]="railway"
)

# =============================================================================
# Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
    read -p "$1 (y/N): " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# Main Script
# =============================================================================

ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/tmp/db_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_${ENV}_${TIMESTAMP}.sql"

# Validate environment
if [[ "$ENV" != "dev" && "$ENV" != "prd" ]]; then
    log_error "Invalid environment: $ENV. Use 'dev' or 'prd'"
    exit 1
fi

# Set DB configs based on environment
if [[ "$ENV" == "dev" ]]; then
    SOURCE_HOST="${SOURCE_DB_DEV[host]}"
    SOURCE_PORT="${SOURCE_DB_DEV[port]}"
    SOURCE_USER="${SOURCE_DB_DEV[user]}"
    SOURCE_PASSWORD="${SOURCE_DB_DEV[password]}"
    SOURCE_DATABASE="${SOURCE_DB_DEV[database]}"

    TARGET_HOST="${TARGET_DB_DEV[host]}"
    TARGET_PORT="${TARGET_DB_DEV[port]}"
    TARGET_USER="${TARGET_DB_DEV[user]}"
    TARGET_PASSWORD="${TARGET_DB_DEV[password]}"
    TARGET_DATABASE="${TARGET_DB_DEV[database]}"
else
    SOURCE_HOST="${SOURCE_DB_PRD[host]}"
    SOURCE_PORT="${SOURCE_DB_PRD[port]}"
    SOURCE_USER="${SOURCE_DB_PRD[user]}"
    SOURCE_PASSWORD="${SOURCE_DB_PRD[password]}"
    SOURCE_DATABASE="${SOURCE_DB_PRD[database]}"

    TARGET_HOST="${TARGET_DB_PRD[host]}"
    TARGET_PORT="${TARGET_DB_PRD[port]}"
    TARGET_USER="${TARGET_DB_PRD[user]}"
    TARGET_PASSWORD="${TARGET_DB_PRD[password]}"
    TARGET_DATABASE="${TARGET_DB_PRD[database]}"
fi

# Check for placeholder values
if [[ "$TARGET_HOST" == "REPLACE_WITH_PRD_TARGET_HOST" ]]; then
    log_error "PRD target DB not configured. Edit this script to add PRD credentials."
    exit 1
fi

echo ""
echo "=============================================="
echo "  TypeORM → Rails DB Migration"
echo "  Environment: $ENV"
echo "=============================================="
echo ""
log_info "Source DB: $SOURCE_HOST:$SOURCE_PORT/$SOURCE_DATABASE"
log_info "Target DB: $TARGET_HOST:$TARGET_PORT/$TARGET_DATABASE"
echo ""

# Confirmation for production
if [[ "$ENV" == "prd" ]]; then
    log_warning "You are about to migrate PRODUCTION database!"
    if ! confirm "Are you absolutely sure?"; then
        log_info "Aborted."
        exit 0
    fi
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# =============================================================================
# Step 1: Dump source database
# =============================================================================
echo ""
log_info "Step 1/4: Dumping source database..."

PGPASSWORD="$SOURCE_PASSWORD" pg_dump \
    -h "$SOURCE_HOST" \
    -p "$SOURCE_PORT" \
    -U "$SOURCE_USER" \
    -d "$SOURCE_DATABASE" \
    --no-owner \
    --no-acl \
    --clean \
    --if-exists \
    -f "$BACKUP_FILE"

log_success "Database dumped to: $BACKUP_FILE"
log_info "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

# =============================================================================
# Step 2: Restore to target database
# =============================================================================
echo ""
log_info "Step 2/4: Restoring to target database..."

# Drop existing tables (clean restore)
PGPASSWORD="$TARGET_PASSWORD" psql \
    -h "$TARGET_HOST" \
    -p "$TARGET_PORT" \
    -U "$TARGET_USER" \
    -d "$TARGET_DATABASE" \
    -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" \
    2>/dev/null || true

# Restore from backup
PGPASSWORD="$TARGET_PASSWORD" psql \
    -h "$TARGET_HOST" \
    -p "$TARGET_PORT" \
    -U "$TARGET_USER" \
    -d "$TARGET_DATABASE" \
    -f "$BACKUP_FILE" \
    -q

log_success "Database restored to target"

# =============================================================================
# Step 3: Update Rails .env
# =============================================================================
echo ""
log_info "Step 3/4: Updating Rails .env..."

ENV_FILE="$PROJECT_DIR/.env"
DATABASE_URL="postgres://${TARGET_USER}:${TARGET_PASSWORD}@${TARGET_HOST}:${TARGET_PORT}/${TARGET_DATABASE}"

# Backup existing .env
if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "$ENV_FILE.backup_${TIMESTAMP}"
    log_info "Backed up existing .env"
fi

# Update or create DATABASE_URL
if [[ -f "$ENV_FILE" ]] && grep -q "^DATABASE_URL=" "$ENV_FILE"; then
    # Update existing
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^DATABASE_URL=.*|DATABASE_URL=$DATABASE_URL|" "$ENV_FILE"
    else
        sed -i "s|^DATABASE_URL=.*|DATABASE_URL=$DATABASE_URL|" "$ENV_FILE"
    fi
else
    # Add new
    echo "DATABASE_URL=$DATABASE_URL" >> "$ENV_FILE"
fi

log_success "Updated DATABASE_URL in .env"

# =============================================================================
# Step 4: Run Rails migrations (camelCase → snake_case)
# =============================================================================
echo ""
log_info "Step 4/4: Running Rails migrations..."

cd "$PROJECT_DIR"

# Check if Rails is available
if ! command -v bundle &> /dev/null; then
    log_error "Bundle not found. Please run migrations manually:"
    echo "  cd $PROJECT_DIR"
    echo "  bin/rails db:migrate"
    exit 1
fi

# Run migrations
RAILS_ENV=${ENV/prd/production} bundle exec rails db:migrate

log_success "Rails migrations completed"

# =============================================================================
# Verification
# =============================================================================
echo ""
log_info "Verifying migration..."

# Check a few columns to verify snake_case conversion
PGPASSWORD="$TARGET_PASSWORD" psql \
    -h "$TARGET_HOST" \
    -p "$TARGET_PORT" \
    -U "$TARGET_USER" \
    -d "$TARGET_DATABASE" \
    -c "\d profiles" | head -20

echo ""
echo "=============================================="
log_success "Migration completed successfully!"
echo "=============================================="
echo ""
log_info "Summary:"
echo "  - Source: $SOURCE_HOST:$SOURCE_PORT/$SOURCE_DATABASE (unchanged)"
echo "  - Target: $TARGET_HOST:$TARGET_PORT/$TARGET_DATABASE (Rails format)"
echo "  - Backup: $BACKUP_FILE"
echo "  - .env updated with new DATABASE_URL"
echo ""
log_info "Next steps:"
echo "  1. Restart Rails server: bin/rails server"
echo "  2. Test API endpoints"
echo "  3. Verify data integrity"
echo ""
