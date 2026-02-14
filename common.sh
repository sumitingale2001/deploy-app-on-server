#!/usr/bin/env bash
set -e

###################################
# Load NVM (if exists)
###################################
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
elif [ -s "/usr/local/bin/nvm" ]; then
    . "/usr/local/bin/nvm"
fi

# Ensure NVM is available in the current shell session
if command -v nvm >/dev/null 2>&1; then
    nvm use --lts >/dev/null 2>&1 || true
fi

###################################
# Helper: Ask with Default
# Usage: ask_with_default "Prompt" "default_val" VAR_NAME
###################################
ask_with_default() {
    local prompt=$1
    local default=$2
    local var_name=$3
    local input

    read -p "❓ $prompt [$default]: " input
    if [[ -z "$input" ]]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

###################################
# Node Selection (nvm + system)
###################################
select_node() {
  NODE_OPTIONS=()
  NODE_SOURCE=()

  if command -v nvm >/dev/null 2>&1; then
    mapfile -t NVM_VERSIONS < <(
      nvm ls --bare 2>/dev/null | sed 's/^v//' | sort -V
    )
    for v in "${NVM_VERSIONS[@]}"; do
      NODE_OPTIONS+=("$v")
      NODE_SOURCE+=("nvm")
    done
  fi

  if command -v node >/dev/null 2>&1; then
    SYS_NODE_VERSION=$(node -v | sed 's/^v//')
    NODE_OPTIONS+=("system ($SYS_NODE_VERSION)")
    NODE_SOURCE+=("system")
  fi

  NODE_OPTIONS+=("Other")
  NODE_SOURCE+=("other")

  echo "👉 Select Node Version"
  select NODE_CHOICE in "${NODE_OPTIONS[@]}"; do
    [[ -n "$NODE_CHOICE" ]] && break
    echo "❌ Invalid choice"
  done

  INDEX=$((REPLY - 1))
  SOURCE="${NODE_SOURCE[$INDEX]}"

  if [[ "$SOURCE" == "nvm" ]]; then
    nvm use "$NODE_CHOICE"
  elif [[ "$SOURCE" == "system" ]]; then
    echo "⚠️ Using system Node $(node -v)"
  else
    read -p "Enter Node version to install via nvm: " VERSION
    nvm install "$VERSION"
    nvm use "$VERSION"
  fi

  echo "✅ Active Node: $(node -v)"
}

###################################
# Package Manager Selection
###################################
select_package_manager() {
  echo ""
  echo "📦 Detecting Package Manager..."

  if [[ -f "package-lock.json" ]]; then
    PACKAGE_MANAGER="npm"
    echo "✅ Found package-lock.json. Using npm."
  elif [[ -f "yarn.lock" ]]; then
    PACKAGE_MANAGER="yarn"
    echo "✅ Found yarn.lock. Using yarn."
  elif [[ -f "pnpm-lock.yaml" ]]; then
    PACKAGE_MANAGER="pnpm"
    echo "✅ Found pnpm-lock.yaml. Using pnpm."
  else
    echo "👉 Select Package Manager"
    PM_OPTIONS=("npm")
    command -v yarn >/dev/null && PM_OPTIONS+=("yarn")
    command -v pnpm >/dev/null && PM_OPTIONS+=("pnpm")
    PM_OPTIONS+=("Install yarn" "Install pnpm")

    select PM in "${PM_OPTIONS[@]}"; do
      case "$PM" in
        npm) PACKAGE_MANAGER="npm"; break ;;
        yarn) PACKAGE_MANAGER="yarn"; break ;;
        pnpm) PACKAGE_MANAGER="pnpm"; break ;;
        "Install yarn") npm install -g yarn; PACKAGE_MANAGER="yarn"; break ;;
        "Install pnpm") npm install -g pnpm; PACKAGE_MANAGER="pnpm"; break ;;
        *) echo "❌ Invalid choice" ;;
      esac
    done
  fi

  export PACKAGE_MANAGER
}

###################################
# Find Next Available Port
# Usage: get_next_port 3000
###################################
get_next_port() {
  local START_PORT=$1
  local PORT=$START_PORT

  while true; do
    if ! ss -tuln | awk '{print $5}' | grep -q ":$PORT$"; then
      echo "$PORT"
      return
    fi
    PORT=$((PORT + 1))
  done
}

###################################
# Ask & Setup SSL via Certbot
# Usage: ask_and_setup_ssl example.com
###################################
ask_and_setup_ssl() {
  local DOMAIN=$1

  echo ""
  read -p "🔐 Enable SSL for $DOMAIN? (y/n): " ENABLE_SSL

  if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
    echo "🔐 Setting up SSL for $DOMAIN..."

    if ! command -v certbot >/dev/null; then
      echo "📦 Installing certbot..."
      sudo apt update
      sudo apt install -y certbot python3-certbot-nginx
    fi

    sudo certbot --nginx -d "$DOMAIN"

    echo "✅ SSL enabled for $DOMAIN"
  else
    echo "⏭️ Skipping SSL setup"
  fi
}


###################################
# Clone Repository into current dir
###################################
clone_repo() {

  read -p "🔗 Enter Git repository URL: " REPO

  if [ -z "$REPO" ]; then
    echo "❌ Repo URL required"
    exit 1
  fi

  if [ -f "package.json" ]; then
    echo "⚠️ package.json already exists, assuming project already present."
    return
  fi

  echo "📥 Cloning repository..."
  git clone "$REPO" . || { echo "❌ Clone failed"; exit 1; }

  echo "✅ Repo cloned"
}


