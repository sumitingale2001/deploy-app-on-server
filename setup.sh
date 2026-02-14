#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Universal Node App Auto Setup"
echo "================================"

source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/env-setup.sh"

# ----------------------------
# Select App Type
# ----------------------------
echo "👉 Select App Type"
select TYPE in "NestJS API" "Next.js App"; do
  case $REPLY in
    1) APP_TYPE="nest"; break ;;
    2) APP_TYPE="next"; break ;;
    *) echo "❌ Invalid choice";;
  esac
done

# ----------------------------
# CLONE REPO FIRST
# ----------------------------
clone_repo

# ----------------------------
# CREATE ENV FILES
# ----------------------------
create_env_files

# ----------------------------
# THEN NODE + PM
# ----------------------------
select_node
select_package_manager

# ----------------------------
# Run Setup
# ----------------------------
if [[ "$APP_TYPE" == "nest" ]]; then
  bash "$SCRIPT_DIR/nest-setup.sh"
else
  bash "$SCRIPT_DIR/next-setup.sh"
fi
