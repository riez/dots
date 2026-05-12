#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to print status
print_status() {
    echo -e "${GREEN}==> ${1}${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}==> WARNING: ${1}${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}==> ERROR: ${1}${NC}"
}

has_command() {
    command -v "$1" &> /dev/null
}

has_path() {
    [ -e "$1" ] || [ -L "$1" ]
}

has_dir() {
    [ -d "$1" ]
}

has_file() {
    [ -f "$1" ]
}

brew_package_installed() {
    local package="$1"

    if ! has_command brew; then
        return 1
    fi

    brew list --formula "$package" &> /dev/null || brew list --cask "$package" &> /dev/null
}

linux_package_installed() {
    local package="$1"
    local manager
    manager="$(linux_package_manager)"

    case "$manager" in
        apt)
            dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"
            ;;
        dnf|yum)
            rpm -q "$package" &> /dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

SETUP_INSTALL_MODE="${SETUP_INSTALL_MODE:-prompt}"
SETUP_OVERRIDE_INSTALLED=false
SETUP_SKIP_INSTALLED=false
DNF_MIRROR_PREPARED=false

load_setup_env() {
    local env_file="${SETUP_ENV_FILE:-}"
    local had_allexport=false
    local status=0

    if [ -z "$env_file" ]; then
        if [ -f "$SCRIPT_DIR/.env" ]; then
            env_file="$SCRIPT_DIR/.env"
        elif [ -f "$PWD/.env" ]; then
            env_file="$PWD/.env"
        fi
    fi

    if [ -z "$env_file" ]; then
        return 0
    fi

    if [ ! -f "$env_file" ]; then
        print_warning "SETUP_ENV_FILE points to missing file: $env_file"
        return 0
    fi

    print_status "Loading environment variables from $env_file"

    case "$-" in
        *a*) had_allexport=true ;;
    esac

    set -a
    # .env must be shell-compatible: KEY=value or export KEY=value.
    # shellcheck disable=SC1090
    . "$env_file"
    status=$?

    if [ "$had_allexport" != true ]; then
        set +a
    fi

    if [ "$status" -ne 0 ]; then
        print_error "Failed to load $env_file. Ensure it uses shell-compatible KEY=value syntax."
        exit 1
    fi
}

report_installation_item() {
    local label="$1"
    shift

    if "$@"; then
        print_status "$label: installed"
        return 0
    fi

    print_warning "$label: not installed"
    return 1
}

check_current_installation() {
    local detected=false

    print_status "Checking current installation..."

    report_installation_item "Homebrew" has_command brew && detected=true
    report_installation_item "Oh My Zsh" has_dir "$HOME/.oh-my-zsh" && detected=true
    report_installation_item "Antigen" has_file "$HOME/.config/zsh/antigen.zsh" && detected=true
    report_installation_item "Powerlevel10k" has_dir "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" && detected=true
    report_installation_item "mise" has_command mise && detected=true
    report_installation_item "Neovim" has_command nvim && detected=true
    report_installation_item "SDKMAN" has_dir "$HOME/.sdkman" && detected=true
    report_installation_item "gvm" has_dir "$HOME/.gvm" && detected=true
    report_installation_item "Rust" has_command rustc && detected=true
    report_installation_item "Flutter" has_path "$HOME/development/flutter" && detected=true
    report_installation_item "agent configuration" has_dir "$HOME/.config/agentic" && detected=true

    [ "$detected" = true ]
}

select_install_mode() {
    local detected_existing=false

    if check_current_installation; then
        detected_existing=true
    fi

    case "$SETUP_INSTALL_MODE" in
        override|Override|OVERRIDE|reinstall|Reinstall|REINSTALL)
            SETUP_OVERRIDE_INSTALLED=true
            print_status "Install mode: override already installed steps."
            return 0
            ;;
        skip|Skip|SKIP)
            SETUP_SKIP_INSTALLED=true
            print_status "Install mode: skip already installed steps."
            return 0
            ;;
        prompt|Prompt|PROMPT|"")
            ;;
        *)
            print_warning "Unknown SETUP_INSTALL_MODE=$SETUP_INSTALL_MODE; using prompt mode."
            ;;
    esac

    if [ "$detected_existing" = false ]; then
        SETUP_OVERRIDE_INSTALLED=true
        print_status "No existing installation detected; running all setup steps."
        return 0
    fi

    if [ ! -t 0 ]; then
        SETUP_SKIP_INSTALLED=true
        print_warning "Existing installation detected and setup is not interactive; skipping already installed steps."
        print_warning "Set SETUP_INSTALL_MODE=override to rerun installed steps non-interactively."
        return 0
    fi

    local answer
    while true; do
        printf "Existing setup found. Override/reinstall installed steps or skip them? [o]verride/[s]kip: "
        read -r answer
        case "$answer" in
            o|O|override|Override|OVERRIDE|reinstall|Reinstall|REINSTALL)
                SETUP_OVERRIDE_INSTALLED=true
                print_status "Install mode: override already installed steps."
                return 0
                ;;
            s|S|skip|Skip|SKIP|"")
                SETUP_SKIP_INSTALLED=true
                print_status "Install mode: skip already installed steps."
                return 0
                ;;
            *)
                print_warning "Please enter o to override or s to skip."
                ;;
        esac
    done
}

should_run_install_step() {
    local label="$1"
    shift

    if [ "$#" -eq 0 ]; then
        return 0
    fi

    if ! "$@"; then
        return 0
    fi

    if [ "$SETUP_OVERRIDE_INSTALLED" = true ]; then
        print_status "$label already installed; overriding because install mode is override."
        return 0
    fi

    print_status "$label already installed; skipping."
    return 1
}

brew_install_packages() {
    local package
    local packages_to_install=()

    if ! has_command brew; then
        print_warning "Homebrew is not available; skipping packages: $*"
        return 1
    fi

    for package in "$@"; do
        if [ "$SETUP_SKIP_INSTALLED" = true ] && brew_package_installed "$package"; then
            print_status "$package already installed with Homebrew; skipping."
            continue
        fi
        packages_to_install+=("$package")
    done

    if [ "${#packages_to_install[@]}" -eq 0 ]; then
        return 0
    fi

    brew install "${packages_to_install[@]}"
}

brew_install_casks() {
    local cask
    local casks_to_install=()

    if ! has_command brew; then
        print_warning "Homebrew is not available; skipping casks: $*"
        return 1
    fi

    for cask in "$@"; do
        if [ "$SETUP_SKIP_INSTALLED" = true ] && brew_package_installed "$cask"; then
            print_status "$cask already installed with Homebrew; skipping."
            continue
        fi
        casks_to_install+=("$cask")
    done

    if [ "${#casks_to_install[@]}" -eq 0 ]; then
        return 0
    fi

    brew install --cask "${casks_to_install[@]}"
}

npm_global_package_installed() {
    local package="$1"
    local package_name="$package"

    if ! has_command npm; then
        return 1
    fi

    if [[ "$package_name" != @* && "$package_name" == *@* ]]; then
        package_name="${package_name%@*}"
    fi

    npm list -g --depth=0 "$package_name" &> /dev/null
}

npm_install_global_packages() {
    local package
    local packages_to_install=()

    if ! has_command npm; then
        print_warning "npm is not available; skipping global packages: $*"
        return 1
    fi

    for package in "$@"; do
        if [ "$SETUP_SKIP_INSTALLED" = true ] && npm_global_package_installed "$package"; then
            print_status "$package already installed globally with npm; skipping."
            continue
        fi
        packages_to_install+=("$package")
    done

    if [ "${#packages_to_install[@]}" -eq 0 ]; then
        return 0
    fi

    npm install -g "${packages_to_install[@]}"
}

backup_path() {
    local path="$1"

    if [ -e "$path" ] || [ -L "$path" ]; then
        local backup
        backup="${path}.backup.$(date +%Y%m%d%H%M%S)"
        print_warning "Backing up existing $path to $backup"
        mv "$path" "$backup"
    fi
}

link_path() {
    local source="$1"
    local target="$2"

    if [ ! -e "$source" ] && [ ! -L "$source" ]; then
        print_warning "Skipping missing source: $source"
        return 0
    fi

    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ]; then
        local current_target
        current_target="$(readlink "$target")"
        if [ "$current_target" = "$source" ]; then
            return 0
        fi
        rm "$target"
    elif [ -e "$target" ]; then
        backup_path "$target"
    fi

    ln -s "$source" "$target"
}

link_markdown_agents() {
    local source_dir="$1"
    local target_dir="$2"

    if [ ! -d "$source_dir" ]; then
        print_warning "Skipping missing agent source directory: $source_dir"
        return 0
    fi

    mkdir -p "$target_dir"

    for agent_file in "$source_dir"/*.md; do
        [ -e "$agent_file" ] || continue
        [ "$(basename "$agent_file")" = "CLAUDE.md" ] && continue
        link_path "$agent_file" "$target_dir/$(basename "$agent_file")"
    done
}

link_directory_children() {
    local source_dir="$1"
    local target_dir="$2"

    if [ ! -d "$source_dir" ]; then
        print_warning "Skipping missing source directory: $source_dir"
        return 0
    fi

    mkdir -p "$target_dir"

    for source_path in "$source_dir"/*; do
        [ -e "$source_path" ] || [ -L "$source_path" ] || continue
        link_path "$source_path" "$target_dir/$(basename "$source_path")"
    done
}

ensure_zprofile_export() {
    local name="$1"
    local value="$2"

    touch "$HOME/.zprofile"

    if grep -q "^export ${name}=\"${value}\"$" "$HOME/.zprofile"; then
        return 0
    fi

    if grep -q "^export ${name}=" "$HOME/.zprofile"; then
        print_warning "$name already exists in ~/.zprofile; appending the setup value so future shells match this setup."
    fi

    printf 'export %s="%s"\n' "$name" "$value" >> "$HOME/.zprofile"
}

generate_secret_hex() {
    if command -v openssl &> /dev/null; then
        openssl rand -hex 32
    else
        LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c 64
    fi
}

confirm_continue_with_missing_secrets() {
    local context="$1"
    shift
    local missing=()
    local secret_name

    for secret_name in "$@"; do
        [ -n "$secret_name" ] || continue
        if [ -z "${!secret_name:-}" ]; then
            missing+=("$secret_name")
        fi
    done

    if [ "${#missing[@]}" -eq 0 ]; then
        return 0
    fi

    print_warning "Missing secrets for $context:"
    for secret_name in "${missing[@]}"; do
        print_warning "  - $secret_name"
    done

    if [ "${SETUP_CONTINUE_WITH_MISSING_SECRETS:-}" = "1" ]; then
        print_warning "Continuing because SETUP_CONTINUE_WITH_MISSING_SECRETS=1 is set."
        return 0
    fi

    if [ ! -t 0 ]; then
        print_error "Aborting because required secrets are missing and setup is not interactive."
        print_warning "Set the missing secrets, or rerun with SETUP_CONTINUE_WITH_MISSING_SECRETS=1."
        exit 1
    fi

    local answer
    while true; do
        printf "Continue without these secrets? [c]ontinue/[a]bort: "
        read -r answer
        case "$answer" in
            c|C|continue|Continue|CONTINUE)
                print_warning "Continuing with missing secrets. Some agent/MCP features may need manual setup later."
                return 0
                ;;
            a|A|abort|Abort|ABORT|"")
                print_error "Aborting setup. Set the missing secrets and rerun setup.sh."
                exit 1
                ;;
            *)
                print_warning "Please enter c to continue or a to abort."
                ;;
        esac
    done
}

linux_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    else
        echo ""
    fi
}

linux_install_hint() {
    local packages="$1"
    local manager
    manager="$(linux_package_manager)"

    case "$manager" in
        apt) echo "sudo apt update && sudo apt install -y $packages" ;;
        dnf) echo "sudo dnf --setopt=fastestmirror=True --setopt=max_parallel_downloads=${SETUP_DNF_MAX_PARALLEL_DOWNLOADS:-10} install -y $packages" ;;
        yum) echo "sudo yum install -y $packages" ;;
        *) echo "install package(s): $packages with your system package manager" ;;
    esac
}

dnf_install_options() {
    if [ "${SETUP_DNF_FASTESTMIRROR:-1}" != "0" ]; then
        printf '%s\n' "--setopt=fastestmirror=True"
    fi

    if [ -n "${SETUP_DNF_MAX_PARALLEL_DOWNLOADS:-10}" ]; then
        printf '%s\n' "--setopt=max_parallel_downloads=${SETUP_DNF_MAX_PARALLEL_DOWNLOADS:-10}"
    fi
}

prepare_dnf_mirrors() {
    local dnf_options=()

    if [ "${SETUP_DNF_PREPARE_FAST_MIRRORS:-1}" = "0" ]; then
        return 0
    fi

    if [ "$DNF_MIRROR_PREPARED" = true ]; then
        return 0
    fi

    mapfile -t dnf_options < <(dnf_install_options)

    print_status "Refreshing DNF metadata with fastest mirror selection..."
    if ! sudo dnf "${dnf_options[@]}" makecache --refresh; then
        print_warning "DNF mirror preparation failed; continuing with the normal DNF cache."
    fi

    DNF_MIRROR_PREPARED=true
}

dnf_install_packages() {
    local dnf_options=()

    prepare_dnf_mirrors
    mapfile -t dnf_options < <(dnf_install_options)

    print_status "Installing DNF packages: $*"
    if ! sudo dnf "${dnf_options[@]}" install -y "$@"; then
        print_warning "DNF optimized install failed; retrying without fastest mirror options."
        sudo dnf install -y "$@"
    fi
}

dnf_groupinstall() {
    local group_name="$1"
    local dnf_options=()

    prepare_dnf_mirrors
    mapfile -t dnf_options < <(dnf_install_options)

    print_status "Installing DNF group: $group_name"
    if ! sudo dnf "${dnf_options[@]}" groupinstall -y "$group_name"; then
        print_warning "DNF optimized groupinstall failed; retrying without fastest mirror options."
        sudo dnf groupinstall -y "$group_name"
    fi
}

linux_group_installed() {
    local group_name="$1"
    local manager
    manager="$(linux_package_manager)"

    case "$manager" in
        dnf)
            dnf -C -q group list --installed 2>/dev/null | sed 's/^[[:space:]]*//' | grep -Fxq "$group_name"
            ;;
        yum)
            yum -C -q group list installed 2>/dev/null | sed 's/^[[:space:]]*//' | grep -Fxq "$group_name"
            ;;
        *)
            return 1
            ;;
    esac
}

core_development_tools_installed() {
    has_command gcc &&
        has_command g++ &&
        has_command make &&
        has_command autoconf &&
        has_command automake &&
        has_command pkg-config
}

development_tools_installed() {
    if linux_group_installed "Development Tools"; then
        if core_development_tools_installed; then
            return 0
        fi

        print_warning "Development Tools group is marked installed, but core build tools are missing."
        return 1
    fi

    # Fallback for systems where group metadata is unavailable but the core
    # toolchain was installed by another route.
    core_development_tools_installed
}

install_linux_packages() {
    local apt_packages="$1"
    local dnf_packages="${2:-$apt_packages}"
    local yum_packages="${3:-$dnf_packages}"
    local manager
    manager="$(linux_package_manager)"

    case "$manager" in
        apt)
            local apt_array=()
            local apt_install_array=()
            local package
            read -r -a apt_array <<< "$apt_packages"
            for package in "${apt_array[@]}"; do
                if [ "$SETUP_SKIP_INSTALLED" = true ] && linux_package_installed "$package"; then
                    print_status "$package already installed with apt; skipping."
                    continue
                fi
                apt_install_array+=("$package")
            done
            if [ "${#apt_install_array[@]}" -eq 0 ]; then
                return 0
            fi
            sudo apt update
            sudo apt install -y "${apt_install_array[@]}"
            ;;
        dnf)
            local dnf_array=()
            local dnf_install_array=()
            local package
            read -r -a dnf_array <<< "$dnf_packages"
            for package in "${dnf_array[@]}"; do
                if [ "$SETUP_SKIP_INSTALLED" = true ] && linux_package_installed "$package"; then
                    print_status "$package already installed with dnf; skipping."
                    continue
                fi
                dnf_install_array+=("$package")
            done
            if [ "${#dnf_install_array[@]}" -eq 0 ]; then
                return 0
            fi
            dnf_install_packages "${dnf_install_array[@]}"
            ;;
        yum)
            local yum_array=()
            local yum_install_array=()
            local package
            read -r -a yum_array <<< "$yum_packages"
            for package in "${yum_array[@]}"; do
                if [ "$SETUP_SKIP_INSTALLED" = true ] && linux_package_installed "$package"; then
                    print_status "$package already installed with yum; skipping."
                    continue
                fi
                yum_install_array+=("$package")
            done
            if [ "${#yum_install_array[@]}" -eq 0 ]; then
                return 0
            fi
            sudo yum install -y "${yum_install_array[@]}"
            ;;
        *)
            print_warning "No supported Linux package manager found. Install manually: $apt_packages"
            return 1
            ;;
    esac
}

install_linux_development_tools() {
    local manager
    manager="$(linux_package_manager)"

    if [ "${SETUP_SKIP_BASE_PACKAGES:-0}" = "1" ]; then
        print_warning "Skipping base package installation because SETUP_SKIP_BASE_PACKAGES=1 is set."
        return 0
    fi

    case "$manager" in
        apt)
            install_linux_packages "build-essential curl file git tmux openssl procps"
            ;;
        dnf)
            print_status "Checking Development Tools group and core build tools..."
            if should_run_install_step "Development Tools group" development_tools_installed; then
                dnf_groupinstall "Development Tools" || true
            fi
            install_linux_packages \
                "build-essential curl file git tmux openssl procps" \
                "curl file git tmux openssl procps-ng"
            ;;
        yum)
            print_status "Checking Development Tools group and core build tools..."
            if should_run_install_step "Development Tools group" development_tools_installed; then
                sudo yum groupinstall -y "Development Tools" || true
            fi
            install_linux_packages \
                "build-essential curl file git tmux openssl procps" \
                "curl file git tmux openssl procps-ng"
            ;;
        *)
            print_error "No supported package manager found"
            exit 1
            ;;
    esac
}

install_with_brew_or_warn() {
    local package="$1"

    if has_command brew; then
        if [ "$SETUP_SKIP_INSTALLED" = true ] && brew_package_installed "$package"; then
            print_status "$package already installed with Homebrew; skipping."
            return 0
        fi
        brew install "$package" || print_warning "Failed to install $package with Homebrew"
    else
        print_warning "Homebrew is not available; skipping $package"
    fi
}

setup_cliproxyapi() {
    local cliproxyapi_home="${CLIPROXYAPI_HOME:-$HOME/Code/github/router-for-me/CLIProxyAPI}"
    local cliproxyapi_state_dir="${CLIPROXYAPI_STATE_DIR:-$HOME/.cli-proxy-api}"
    local cliproxyapi_config_path="${CLIPROXYAPI_CONFIG_PATH:-$cliproxyapi_state_dir/config.yaml}"
    local cliproxyapi_binary="${CLIPROXYAPI_BINARY:-$cliproxyapi_home/.local/cliproxyapi}"
    local cliproxyapi_port="${CLIPROXYAPI_PORT:-8317}"
    local cliproxyapi_base_url="http://127.0.0.1:${cliproxyapi_port}"
    local cliproxyapi_key="${CLI_PROXY_API_KEY:-}"

    print_status "Setting up CLIProxyAPI local configuration..."

    mkdir -p "$cliproxyapi_state_dir" "$cliproxyapi_state_dir/logs" "$cliproxyapi_state_dir/certs"
    chmod 700 "$cliproxyapi_state_dir"

    if [ -z "$cliproxyapi_key" ]; then
        cliproxyapi_key="$(generate_secret_hex)"
        print_warning "CLI_PROXY_API_KEY was not set; generated a local key for this machine."
    fi

    ensure_zprofile_export "CLI_PROXY_API_KEY" "$cliproxyapi_key"
    ensure_zprofile_export "CLI_PROXY_BASE_URL" "$cliproxyapi_base_url"

    if [ ! -f "$cliproxyapi_config_path" ]; then
        print_status "Writing sanitized CLIProxyAPI config to $cliproxyapi_config_path"
        cat > "$cliproxyapi_config_path" << EOF
# Local CLIProxyAPI config generated by setup.sh.
# This file contains local secrets and must not be committed.
host: "127.0.0.1"
port: ${cliproxyapi_port}
tls:
  enable: false
  cert: "$cliproxyapi_state_dir/certs/cert.pem"
  key: "$cliproxyapi_state_dir/certs/key.pem"
remote-management:
  allow-remote: false
  secret-key: ""
  disable-control-panel: false
auth-dir: "$cliproxyapi_state_dir"
api-keys:
  - "$cliproxyapi_key"
debug: false
logging-to-file: true
usage-statistics-enabled: false
proxy-url: ""
request-retry: 3
quota-exceeded:
  switch-project: true
  switch-preview-model: true
  antigravity-credits: true
oauth-model-alias:
  codex:
    - name: "gpt-5.5"
      alias: "gpt-5.5-fast"
      fork: true
auth:
  providers: []
payload:
  override:
    - models:
        - name: "gpt-5.5-fast"
      params:
        "service_tier": "priority"
  default:
    - models:
        - name: "claude-opus-4-7*"
          protocol: "claude"
      params:
        "thinking.type": "adaptive"
        "max_tokens": 128000
    - models:
        - name: "claude-sonnet-4-6*"
          protocol: "claude"
      params:
        "thinking.type": "adaptive"
        "max_tokens": 64000
EOF
        chmod 600 "$cliproxyapi_config_path"
    else
        print_status "CLIProxyAPI config already exists at $cliproxyapi_config_path"
    fi

    print_warning "Add upstream provider credentials locally through CLIProxyAPI OAuth/login commands, the management UI, or $cliproxyapi_config_path."
    print_warning "Do not commit $cliproxyapi_config_path, auth files, certificates, or logs."

    if [ ! -x "$cliproxyapi_binary" ]; then
        if [ -d "$cliproxyapi_home" ] && command -v go &> /dev/null; then
            print_status "Building CLIProxyAPI binary..."
            mkdir -p "$cliproxyapi_home/.local"
            (cd "$cliproxyapi_home" && go build -o "$cliproxyapi_binary" ./cmd/server)
        else
            print_warning "CLIProxyAPI binary not found at $cliproxyapi_binary. Set CLIPROXYAPI_HOME or CLIPROXYAPI_BINARY, then rerun setup."
        fi
    fi

    if [[ "$(uname)" == "Darwin" ]]; then
        local launch_agent_dir="$HOME/Library/LaunchAgents"
        local launch_agent_path="$launch_agent_dir/com.rz.cliproxyapi-local.plist"
        mkdir -p "$launch_agent_dir" "$HOME/logs"

        cat > "$launch_agent_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.rz.cliproxyapi-local</string>
  <key>ProgramArguments</key>
  <array>
    <string>$cliproxyapi_binary</string>
    <string>-config</string>
    <string>$cliproxyapi_config_path</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$cliproxyapi_home</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$cliproxyapi_state_dir/logs/launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>$cliproxyapi_state_dir/logs/launchd.err.log</string>
</dict>
</plist>
EOF

        if [ -x "$cliproxyapi_binary" ]; then
            launchctl bootout "gui/$(id -u)" "$launch_agent_path" &> /dev/null || true
            launchctl bootstrap "gui/$(id -u)" "$launch_agent_path" &> /dev/null || \
                print_warning "Could not load launchd service. Load manually with: launchctl bootstrap gui/\$(id -u) $launch_agent_path"
        fi
    elif command -v systemctl &> /dev/null; then
        local systemd_user_dir="$HOME/.config/systemd/user"
        local service_path="$systemd_user_dir/cliproxyapi-local.service"
        mkdir -p "$systemd_user_dir"

        cat > "$service_path" << EOF
[Unit]
Description=CLIProxyAPI local proxy
After=network-online.target

[Service]
Type=simple
WorkingDirectory=$cliproxyapi_home
ExecStart=$cliproxyapi_binary -config $cliproxyapi_config_path
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

        if [ -x "$cliproxyapi_binary" ]; then
            systemctl --user daemon-reload || true
            systemctl --user enable --now cliproxyapi-local.service || \
                print_warning "Could not enable user service. Start manually with: systemctl --user start cliproxyapi-local.service"
        fi
    fi
}

setup_claude_code_agents() {
    local agentic_home="$HOME/.config/agentic"

    print_status "Setting up Claude Code agent links..."
    mkdir -p "$HOME/.claude/agents" "$HOME/.claude/commands" "$HOME/.claude/hooks" "$HOME/.claude/skills"

    link_markdown_agents "$agentic_home/droids" "$HOME/.claude/agents"
    link_path "$agentic_home/teams" "$HOME/.claude/teams"
    link_directory_children "$agentic_home/skills" "$HOME/.claude/skills"

    if [ -f "$agentic_home/superpowers/commands/orchestrator.md" ]; then
        link_path "$agentic_home/superpowers/commands/orchestrator.md" "$HOME/.claude/commands/orchestrator.md"
    fi

    for hook_file in \
        post-tool-use.py \
        pre-compact.py \
        require-exploration.py \
        require-planning.py \
        require-root-cause.py \
        require-skill.py \
        session-start.py \
        stop.py; do
        link_path "$agentic_home/hooks/$hook_file" "$HOME/.claude/hooks/$hook_file"
    done

    link_path "$agentic_home/hooks/CLAUDE.md" "$HOME/.claude/hooks/CLAUDE.md"
    link_path "$agentic_home/claude/statusline.sh" "$HOME/.claude/statusline.sh"

    configure_claude_code_settings
}

configure_claude_code_settings() {
    print_status "Configuring Claude Code hooks..."
    mkdir -p "$HOME/.claude"

    if ! command -v python3 >/dev/null 2>&1; then
        print_warning "python3 is required to configure Claude Code settings; hook files were linked but settings.json was not updated."
        return 0
    fi

    CLAUDE_SETTINGS_PATH="$HOME/.claude/settings.json" python3 <<'PY'
import json
import os
from pathlib import Path

settings_path = Path(os.environ["CLAUDE_SETTINGS_PATH"])
try:
    data = json.loads(settings_path.read_text()) if settings_path.exists() else {}
except Exception:
    backup = settings_path.with_suffix(settings_path.suffix + ".invalid")
    settings_path.rename(backup)
    data = {}

if not isinstance(data, dict):
    data = {}

env = data.setdefault("env", {})
env.setdefault("DISABLE_AUTOUPDATER", "1")
env.setdefault("MAX_THINKING_TOKENS", "63999")
env.setdefault("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS", "1")

hooks = data.setdefault("hooks", {})

def command_exists(event_name, command):
    for entry in hooks.get(event_name, []):
        for hook in entry.get("hooks", []):
            if hook.get("command") == command:
                return True
    return False

def add_hook(event_name, matcher, command, timeout=None):
    if command_exists(event_name, command):
        return
    hook = {"type": "command", "command": command}
    if timeout is not None:
        hook["timeout"] = timeout
    entry = {"hooks": [hook]}
    if matcher is not None:
        entry["matcher"] = matcher
    hooks.setdefault(event_name, []).append(entry)

for command in [
    "~/.claude/hooks/require-exploration.py",
    "~/.claude/hooks/require-planning.py",
    "~/.claude/hooks/require-root-cause.py",
    "~/.claude/hooks/require-skill.py",
]:
    add_hook("PreToolUse", "Edit|Write|MultiEdit", command, 5000)

add_hook(
    "PreToolUse",
    "Bash",
    "python3 ~/.config/agentic/hooks/coderabbit-review.py pre-commit",
    10000,
)
add_hook(
    "PostToolUse",
    "Edit|Write|MultiEdit",
    "python3 ~/.config/agentic/hooks/coderabbit-review.py post-edit",
    10000,
)
add_hook(
    "PostToolUse",
    "Bash",
    "python3 ~/.config/agentic/hooks/coderabbit-review.py mark-done",
    10000,
)
add_hook("PostToolUse", "*", "~/.claude/hooks/post-tool-use.py", 5000)
add_hook("SessionStart", None, "~/.claude/hooks/session-start.py", 5000)
add_hook("PreCompact", None, "~/.claude/hooks/pre-compact.py", 5000)
add_hook("Stop", None, "~/.claude/hooks/stop.py", 5000)

data.setdefault("statusLine", {
    "type": "command",
    "command": "~/.claude/statusline.sh",
})

settings_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

setup_codex_agents() {
    local agentic_home="$HOME/.config/agentic"

    print_status "Setting up Codex agent links..."
    mkdir -p "$HOME/.codex/skills"

    link_path "$agentic_home/conventions" "$HOME/.codex/conventions"
    link_directory_children "$agentic_home/skills" "$HOME/.codex/skills"
}

setup_droid_agents() {
    local agentic_home="$HOME/.config/agentic"

    print_status "Setting up Droid agent links..."
    mkdir -p "$HOME/.factory/commands" "$HOME/.factory/hooks"

    link_path "$agentic_home/droids" "$HOME/.factory/droids"
    link_path "$agentic_home/skills" "$HOME/.factory/skills"
    link_path "$agentic_home/superpowers" "$HOME/.factory/superpowers"
    link_path "$agentic_home/conventions" "$HOME/.factory/conventions"
    link_path "$agentic_home/teams" "$HOME/.factory/teams"

    for command_file in brainstorm.md execute-plan.md write-plan.md; do
        link_path "$HOME/.factory/superpowers/commands/$command_file" "$HOME/.factory/commands/$command_file"
    done

    for hook_file in \
        coderabbit-review.py \
        post-execute-coderabbit.sh \
        post-tool-use-coderabbit.sh \
        pre-execute-coderabbit.sh \
        post-tool-use.py \
        pre-compact.py \
        require-exploration.py \
        require-planning.py \
        require-root-cause.py \
        require-skill.py \
        session-start.py \
        sonarqube-analysis.py \
        stop.py \
        sync-hooks.sh; do
        link_path "$agentic_home/hooks/$hook_file" "$HOME/.factory/hooks/$hook_file"
    done

    if [ -x "$HOME/.factory/hooks/sync-hooks.sh" ]; then
        "$HOME/.factory/hooks/sync-hooks.sh" || print_warning "Factory hook sync reported warnings; review ~/.factory/settings.json if hooks are not active."
    fi

    configure_droid_settings
}

configure_droid_settings() {
    print_status "Configuring Droid hooks..."
    mkdir -p "$HOME/.factory"

    if ! command -v python3 >/dev/null 2>&1; then
        print_warning "python3 is required to configure Droid settings; hook files were linked but settings.json was not updated."
        return 0
    fi

    DROID_SETTINGS_PATH="$HOME/.factory/settings.json" python3 <<'PY'
import json
import os
from pathlib import Path

settings_path = Path(os.environ["DROID_SETTINGS_PATH"])
try:
    data = json.loads(settings_path.read_text()) if settings_path.exists() else {}
except Exception:
    backup = settings_path.with_suffix(settings_path.suffix + ".invalid")
    settings_path.rename(backup)
    data = {}

if not isinstance(data, dict):
    data = {}

data.setdefault("enableCustomDroids", True)
hooks = data.setdefault("hooks", {})

def command_exists(event_name, command):
    for entry in hooks.get(event_name, []):
        for hook in entry.get("hooks", []):
            if hook.get("command") == command:
                return True
    return False

def add_hook(event_name, matcher, command, timeout=None):
    if command_exists(event_name, command):
        return
    hook = {"type": "command", "command": command}
    if timeout is not None:
        hook["timeout"] = timeout
    entry = {"hooks": [hook]}
    if matcher is not None:
        entry["matcher"] = matcher
    hooks.setdefault(event_name, []).append(entry)

add_hook("SessionStart", "*", "sh ~/.factory/superpowers/hooks/session-start.sh", 5)
add_hook("SessionStart", "*", "python3 ~/.factory/hooks/session-start.py", 5)

for command in [
    "sh ~/.factory/hooks/require-exploration.sh",
    "sh ~/.factory/hooks/require-planning.sh",
    "sh ~/.factory/hooks/require-root-cause.sh",
    "sh ~/.factory/hooks/require-skill.sh",
]:
    add_hook("PreToolUse", "Write|Edit|MultiEdit", command, 5)

add_hook("PreToolUse", "Bash", "sh ~/.factory/hooks/pre-execute-coderabbit.sh", 10)
add_hook("PostToolUse", "Write|Edit|MultiEdit", "sh ~/.factory/hooks/post-tool-use-coderabbit.sh", 10)
add_hook("PostToolUse", "Bash", "sh ~/.factory/hooks/post-execute-coderabbit.sh", 10)
add_hook("PostToolUse", "*", "python3 ~/.factory/hooks/post-tool-use.py", 5)
add_hook("PreCompact", "*", "python3 ~/.factory/hooks/pre-compact.py", 5)
add_hook("Stop", None, "python3 ~/.factory/hooks/stop.py", 5)

settings_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

ensure_agentic_superpowers() {
    local agentic_home="$1"
    local superpowers_dir="$agentic_home/superpowers"
    local superpowers_repo="${SUPERPOWERS_REPO_URL:-https://github.com/obra/superpowers.git}"

    if [ -e "$superpowers_dir" ] || [ -L "$superpowers_dir" ]; then
        return 0
    fi

    if ! command -v git >/dev/null 2>&1; then
        print_warning "git is required to clone Superpowers into $superpowers_dir"
        return 0
    fi

    print_status "Cloning Superpowers agent support into $superpowers_dir"
    if ! git clone "$superpowers_repo" "$superpowers_dir"; then
        print_warning "Unable to clone $superpowers_repo; Superpowers links will be skipped until it exists locally."
    fi
}

setup_opencode_local_config() {
    local agentic_home="$1"
    local local_config="$agentic_home/opencode/opencode.json"
    local sample_config="$agentic_home/opencode/opencode.sample.json"

    if [ -f "$local_config" ]; then
        chmod 600 "$local_config" 2>/dev/null || true
        return 0
    fi

    if [ ! -f "$sample_config" ]; then
        print_warning "Skipping OpenCode config generation; missing $sample_config"
        return 0
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        print_warning "python3 is required to generate $local_config from $sample_config"
        return 0
    fi

    OPENCODE_SAMPLE_CONFIG="$sample_config" \
    OPENCODE_LOCAL_CONFIG="$local_config" \
    OPENCODE_HOME="$HOME" \
    python3 <<'PY'
import json
import os
from pathlib import Path

sample = Path(os.environ["OPENCODE_SAMPLE_CONFIG"])
target = Path(os.environ["OPENCODE_LOCAL_CONFIG"])
home = os.environ["OPENCODE_HOME"]

data = json.loads(sample.read_text())
mcp = data.setdefault("mcp", {})

figma_key = os.environ.get("FIGMA_API_KEY", "")
if "figma" in mcp:
    mcp["figma"].setdefault("environment", {})["FIGMA_API_KEY"] = figma_key
    if not figma_key:
        mcp["figma"]["enabled"] = False

greptile_key = os.environ.get("GREPTILE_API_KEY", "")
if "greptile" in mcp:
    mcp["greptile"].setdefault("headers", {})["Authorization"] = (
        f"Bearer {greptile_key}" if greptile_key else "Bearer "
    )
    if not greptile_key:
        mcp["greptile"]["enabled"] = False

sonarqube_token = os.environ.get("SONARQUBE_TOKEN", "")
sonarqube_url = os.environ.get(
    "SONARQUBE_URL",
    "https://sonarqube-local.taila7050b.ts.net",
)
if "sonarqube" in mcp:
    env = mcp["sonarqube"].setdefault("environment", {})
    env["SONARQUBE_URL"] = sonarqube_url
    env["SONARQUBE_TOKEN"] = sonarqube_token
    if not sonarqube_token:
        mcp["sonarqube"]["enabled"] = False

if "pal" in mcp:
    command = mcp["pal"].get("command", [])
    mcp["pal"]["command"] = [
        part.replace("__HOME__", home) if isinstance(part, str) else part
        for part in command
    ]

target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(data, indent=2) + "\n")
PY

    chmod 600 "$local_config" 2>/dev/null || true
    print_status "Generated local OpenCode config at $local_config"
}

setup_opencode_agents() {
    local agentic_home="$HOME/.config/agentic"

    print_status "Setting up OpenCode agent links..."
    mkdir -p "$HOME/.config/opencode/plugin"

    setup_opencode_local_config "$agentic_home"

    link_path "$agentic_home/opencode/bin" "$HOME/.config/opencode/bin"
    link_path "$agentic_home/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
    link_path "$agentic_home/opencode/package.json" "$HOME/.config/opencode/package.json"
    link_path "$agentic_home/conventions" "$HOME/.config/opencode/conventions"
    link_path "$agentic_home/skills" "$HOME/.config/opencode/skills"
    link_path "$agentic_home/superpowers" "$HOME/.config/opencode/superpowers"

    link_path "$agentic_home/hooks/coderabbit-review-opencode.js" "$HOME/.config/opencode/plugin/coderabbit-review.js"
    link_path "$agentic_home/hooks/require-skill-opencode.js" "$HOME/.config/opencode/plugin/require-skill.js"
    link_path "$agentic_home/hooks/sonarqube-opencode.js" "$HOME/.config/opencode/plugin/sonarqube-analysis.js"

    if [ -f "$agentic_home/superpowers/.opencode/plugin/superpowers.js" ]; then
        link_path "$agentic_home/superpowers/.opencode/plugin/superpowers.js" "$HOME/.config/opencode/plugin/superpowers.js"
    fi
}

setup_agent_configs() {
    print_status "Setting up shared agent configuration..."

    mkdir -p "$HOME/.config/agentic"

    # Override with SETUP_REQUIRED_SECRETS="NAME_ONE NAME_TWO" when a machine
    # needs additional MCP/provider secrets before agent setup should proceed.
    local required_secrets_string="${SETUP_REQUIRED_SECRETS:-CLI_PROXY_API_KEY FIGMA_API_KEY GREPTILE_API_KEY SONARQUBE_TOKEN}"
    local required_secrets=()
    read -r -a required_secrets <<< "$required_secrets_string"
    confirm_continue_with_missing_secrets \
        "agent and MCP setup" \
        "${required_secrets[@]}"

    ensure_agentic_superpowers "$HOME/.config/agentic"

    setup_cliproxyapi
    setup_claude_code_agents
    setup_codex_agents
    setup_droid_agents
    setup_opencode_agents

    print_warning "Agent MCP servers may require local secrets that are not committed."
    print_warning "Set the needed environment variables before first use, for example: CLI_PROXY_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY, FIGMA_API_KEY, GREPTILE_API_KEY, CONTEXT7_API_KEY, REF_API_KEY, SONARQUBE_URL, and SONARQUBE_TOKEN."
}

load_setup_env

# Check for required dependencies
print_status "Checking for required dependencies..."
MISSING_DEPS=false

# Check for sudo
if ! command -v sudo &> /dev/null; then
    print_error "sudo is required but not installed"
    print_warning "Install with: $(linux_install_hint sudo)"
    MISSING_DEPS=true
fi

# Check for curl
if ! command -v curl &> /dev/null; then
    print_error "curl is required but not installed"
    print_warning "Install with: $(linux_install_hint curl)"
    MISSING_DEPS=true
fi

# Check for git
if ! command -v git &> /dev/null; then
    print_error "git is required but not installed"
    print_warning "Install with: $(linux_install_hint git)"
    MISSING_DEPS=true
fi

# Check for zsh
if ! command -v zsh &> /dev/null; then
    print_error "zsh is required but not installed"
    print_warning "Install with: $(linux_install_hint zsh)"
    MISSING_DEPS=true
fi

# If on WSL, check for Windows integration tools
if [[ "$(uname)" == "Linux" && -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
    if ! command -v wslvar &> /dev/null || ! command -v wslpath &> /dev/null; then
        print_error "WSL integration tools (wslu) are required but not installed"
        print_warning "Install with: $(linux_install_hint wslu)"
        MISSING_DEPS=true
    fi
fi

# Exit if any dependencies are missing
if [ "$MISSING_DEPS" = true ]; then
    print_error "Please install the missing dependencies and run the script again"
    exit 1
fi

select_install_mode

# Function to check and install packages based on OS
install_packages() {
    if [[ "$(uname)" == "Linux" ]]; then
        install_linux_development_tools
    elif [[ "$(uname)" == "Darwin" ]]; then
        if ! command -v xcode-select &> /dev/null; then
            print_status "Installing Command Line Tools for Xcode..."
            xcode-select --install
        fi
    fi
}

# Create necessary directories
print_status "Creating directories..."
mkdir -p "$HOME/.config/zsh"
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.kube"
mkdir -p "$HOME/.config/agentic"

# Install base packages
print_status "Installing base packages..."
install_packages

# Install Homebrew if not installed
if should_run_install_step "Homebrew" has_command brew; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH based on OS
    if [[ "$(uname)" == "Linux" ]]; then
        BREW_PATH="/home/linuxbrew/.linuxbrew/bin/brew"
        if ! grep -q "eval \\\"\\$(\\$BREW_PATH shellenv)\\\"" "$HOME/.zprofile"; then
            echo 'eval "$('$BREW_PATH' shellenv)"' >> "$HOME/.zprofile"
        fi
        eval "$($BREW_PATH shellenv)"
    elif [[ "$(uname)" == "Darwin" ]]; then
        BREW_PATH="/opt/homebrew/bin/brew"
        if ! grep -q "eval \\\"\\$(\\$BREW_PATH shellenv)\\\"" "$HOME/.zprofile"; then
            echo 'eval "$('$BREW_PATH' shellenv)"' >> "$HOME/.zprofile"
        fi
        eval "$($BREW_PATH shellenv)"
    fi
fi

# Install Oh My Zsh if not installed
if should_run_install_step "Oh My Zsh" has_dir "$HOME/.oh-my-zsh"; then
    if [ "$SETUP_OVERRIDE_INSTALLED" = true ] && [ -d "$HOME/.oh-my-zsh" ]; then
        backup_path "$HOME/.oh-my-zsh"
    fi
    print_status "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Antigen
if should_run_install_step "Antigen" has_file "$HOME/.config/zsh/antigen.zsh"; then
    print_status "Installing Antigen..."
    curl -L git.io/antigen > "$HOME/.config/zsh/antigen.zsh"
fi

# Install Powerlevel10k theme
POWERLEVEL10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if should_run_install_step "Powerlevel10k theme" has_dir "$POWERLEVEL10K_DIR"; then
    if [ "$SETUP_OVERRIDE_INSTALLED" = true ] && [ -d "$POWERLEVEL10K_DIR" ]; then
        backup_path "$POWERLEVEL10K_DIR"
    fi
    print_status "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$POWERLEVEL10K_DIR"
fi

# Install core tools with Homebrew
print_status "Installing core tools..."
brew_install_packages \
    tmux \
    git

# Install mise directly
print_status "Installing mise directly..."
if should_run_install_step "mise" has_command mise; then
    curl -fsSL https://mise.run | sh
    # Ensure mise is available in the current session's PATH
    export PATH="$HOME/.local/bin:$PATH"
fi

# Install Neovim with multiple fallback methods
print_status "Installing Neovim..."
NEOVIM_INSTALLED=false

if should_run_install_step "Neovim" has_command nvim; then

# Method 1: Try with Homebrew
if ! $NEOVIM_INSTALLED; then
    print_status "Attempting to install Neovim with Homebrew..."
    brew_install_packages neovim
    if command -v nvim &> /dev/null; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully with Homebrew!"
    fi
fi

# Method 2: Try with system package manager
if ! $NEOVIM_INSTALLED && [[ "$(uname)" == "Linux" ]]; then
    print_status "Attempting to install Neovim with system package manager..."
    install_linux_packages "neovim"

    if command -v nvim &> /dev/null; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully with system package manager!"
    fi
fi

# Method 3: Try with snap (for Ubuntu)
if ! $NEOVIM_INSTALLED && [[ "$(uname)" == "Linux" ]] && command -v snap &> /dev/null; then
    print_status "Attempting to install Neovim with snap..."
    sudo snap install --classic nvim

    if command -v nvim &> /dev/null; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully with snap!"
    fi
fi

# Method 4: Install from AppImage (Linux only)
if ! $NEOVIM_INSTALLED && [[ "$(uname)" == "Linux" ]]; then
    print_status "Attempting to install Neovim using AppImage..."
    mkdir -p "$HOME/bin"
    cd "$HOME/bin"
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod u+x nvim.appimage

    # Try to extract AppImage if fuse is not available
    if ! ./nvim.appimage --version &> /dev/null; then
        print_status "Extracting AppImage (fuse may not be available)..."
        ./nvim.appimage --appimage-extract
        # Create wrapper script
        echo '#!/bin/bash' > nvim
        echo "$(pwd)/squashfs-root/usr/bin/nvim \"\$@\"" >> nvim
        chmod +x nvim
    else
        # Create symlink
        ln -sf "$(pwd)/nvim.appimage" "$(pwd)/nvim"
    fi

    # Add to PATH if not already there
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zprofile"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zprofile"
    fi

    # Source immediately for the current session
    export PATH="$HOME/bin:$PATH"

    if command -v nvim &> /dev/null || [ -f "$HOME/bin/nvim" ]; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully using AppImage!"
    fi
fi

# Method 5: Install from source as a last resort
if ! $NEOVIM_INSTALLED && [[ "$(uname)" == "Linux" ]]; then
    print_status "Attempting to install Neovim from source (this may take a while)..."

    # Install build dependencies
    install_linux_packages \
        "ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip curl" \
        "ninja-build gettext libtool autoconf automake cmake gcc gcc-c++ make pkgconf-pkg-config unzip patch curl" \
        "ninja-build gettext libtool autoconf automake cmake gcc gcc-c++ make pkgconfig unzip patch curl"

    # Clone and build neovim
    cd /tmp
    rm -rf neovim
    git clone https://github.com/neovim/neovim
    cd neovim
    git checkout stable
    make CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo make install

    if command -v nvim &> /dev/null; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully from source!"
    fi
fi

fi

# Verify Neovim installation and display version
if command -v nvim &> /dev/null; then
    NVIM_VERSION=$(nvim --version | head -n 1)
    print_status "Neovim is installed: $NVIM_VERSION"

    # Create Neovim configuration directory
    print_status "Setting up Neovim configuration directory..."
    mkdir -p "$HOME/.config/nvim"
else
    print_error "Failed to install Neovim through multiple methods."
    print_warning "Please install Neovim manually after the script completes."
    print_warning "You can visit https://github.com/neovim/neovim/wiki/Installing-Neovim for installation instructions."
fi

# Set up mise as the unified version manager
print_status "Setting up mise as the unified runtime version manager..."
if command -v mise &> /dev/null; then
    # Configure mise in shell if not already configured
    if ! grep -q 'eval "$($HOME/.local/bin/mise activate zsh)"' "$HOME/.zprofile"; then
        echo 'eval "$($HOME/.local/bin/mise activate zsh)"' >> "$HOME/.zprofile"
    fi

    # Create mise config directory with proper permissions
    mkdir -p "$HOME/.config" || sudo mkdir -p "$HOME/.config"
    sudo chown -R $(whoami):$(whoami) "$HOME/.config"
    mkdir -p "$HOME/.config/mise"

    # Create base config file if it doesn't exist
    if [ ! -f "$HOME/.config/mise/config.toml" ]; then
        cat > "$HOME/.config/mise/config.toml" << EOF
[settings]
always_keep_download = true
jobs = 4
legacy_version_file = true

[tools]
# Node.js versions
node = ['lts']

# Python versions
python = ['3.12']

# Go versions - use the specific version that's being requested
go = ['1.24.2']

# Rust versions
rust = ['stable']
EOF
    else
        # If config already exists, update Go version in it
        print_status "Updating Go version in mise config..."
        sed -i 's/go = \[.*\]/go = \["1.24.2"\]/' "$HOME/.config/mise/config.toml"
    fi

    # Install runtimes with mise
    if should_run_install_step "Node.js through mise" mise which node; then
        print_status "Installing Node.js with mise..."
        mise install node@lts
        mise use --global node@lts
    fi

    # Explicitly install the specific Go version with mise
    if should_run_install_step "Go through mise" mise which go; then
        print_status "Installing Go 1.24.2 with mise..."
        mise install go@1.24.2
        mise use --global go@1.24.2
    fi

    # Install global Node.js tools
    if mise which node &> /dev/null; then
        eval "$(mise activate bash)"

        print_status "Installing global Node.js development tools..."
        if command -v npm &> /dev/null; then
            npm_install_global_packages \
                npm@latest \
                yarn \
                pnpm \
                typescript \
                electron \
                electron-packager \
                expo-cli \
                create-react-app \
                create-react-native-app
        else
            print_error "npm not found after Node.js installation. Skipping global tools."
        fi
    else
        print_error "Node.js installation with mise failed. Skipping global tools."
    fi
fi

# Add cloud tools paths to .zprofile for persistence across sessions
print_status "Configuring cloud development environment paths..."

# Create or append to .zprofile
touch "$HOME/.zprofile"

# AWS paths
if [ -d "$HOME/.aws" ]; then
    if ! grep -q "AWS_CONFIG_FILE" "$HOME/.zprofile"; then
        echo '# AWS configuration' >> "$HOME/.zprofile"
        echo 'export AWS_CONFIG_FILE="$HOME/.aws/config"' >> "$HOME/.zprofile"
        echo 'export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/credentials"' >> "$HOME/.zprofile"
    fi
fi

# Google Cloud SDK paths
if [[ "$(uname)" == "Linux" ]]; then
    # For Linux
    if [ -d "/usr/lib/google-cloud-sdk" ] && ! grep -q "google-cloud-sdk" "$HOME/.zprofile"; then
        echo '# Google Cloud SDK configuration' >> "$HOME/.zprofile"
        echo 'export CLOUDSDK_ROOT_DIR="/usr/lib/google-cloud-sdk"' >> "$HOME/.zprofile"
        echo 'export PATH="$PATH:/usr/lib/google-cloud-sdk/bin"' >> "$HOME/.zprofile"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    # For macOS
    if [ -d "/usr/local/Caskroom/google-cloud-sdk" ] && ! grep -q "google-cloud-sdk" "$HOME/.zprofile"; then
        echo '# Google Cloud SDK configuration' >> "$HOME/.zprofile"
        echo 'export CLOUDSDK_ROOT_DIR="/usr/local/Caskroom/google-cloud-sdk"' >> "$HOME/.zprofile"
        echo 'source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"' >> "$HOME/.zprofile"
        echo 'source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"' >> "$HOME/.zprofile"
    fi
fi

# Azure paths and environment variables
if ! grep -q "AZURE_CONFIG_DIR" "$HOME/.zprofile"; then
    echo '# Azure CLI configuration' >> "$HOME/.zprofile"
    echo 'export AZURE_CONFIG_DIR="$HOME/.azure"' >> "$HOME/.zprofile"
fi

# Firebase config
if command -v firebase &> /dev/null && ! grep -q "FIREBASE_CONFIG" "$HOME/.zprofile"; then
    echo '# Firebase configuration' >> "$HOME/.zprofile"
    echo 'export FIREBASE_CONFIG="$HOME/.config/firebase"' >> "$HOME/.zprofile"
fi

# Install Python tools
print_status "Installing Python tools..."
brew_install_packages pyenv pipx

# Install Go tools
print_status "Installing Go tools..."
brew_install_packages go

# Install required packages for SDKMAN
print_status "Installing required packages for SDKMAN..."
if [[ "$(uname)" == "Linux" ]]; then
    install_linux_packages "zip unzip"
elif [[ "$(uname)" == "Darwin" ]]; then
    brew_install_packages zip unzip
fi

# Install SDKMAN if not installed
if should_run_install_step "SDKMAN" has_dir "$HOME/.sdkman"; then
    if [ "$SETUP_OVERRIDE_INSTALLED" = true ] && [ -d "$HOME/.sdkman" ]; then
        backup_path "$HOME/.sdkman"
    fi
    print_status "Installing SDKMAN..."
    curl -s "https://get.sdkman.io" | bash
fi

# Install gvm for managing Go versions
print_status "Installing gvm for managing multiple Go versions..."
if should_run_install_step "gvm" has_dir "$HOME/.gvm"; then
    if [ "$SETUP_OVERRIDE_INSTALLED" = true ] && [ -d "$HOME/.gvm" ]; then
        backup_path "$HOME/.gvm"
    fi
    # Install gvm dependencies
    if [[ "$(uname)" == "Linux" ]]; then
        install_linux_packages "bison"
    elif [[ "$(uname)" == "Darwin" ]]; then
        brew_install_packages bison
    fi

    # Install gvm
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)

    # Source gvm
    [[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"

    # Install latest stable Go version
    print_status "Installing stable Go version with gvm..."
    # First install Go 1.4 (bootstrap version)
    gvm install go1.4 -B
    gvm use go1.4
    # Then install latest stable Go
    gvm install go1.20
    gvm use go1.20 --default
fi

# Install Rust
print_status "Installing Rust..."
if should_run_install_step "Rust" has_command rustc; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Install Rust development tools
print_status "Installing Rust development tools..."
if command -v rustup &> /dev/null; then
    source "$HOME/.cargo/env"
    rustup component add rustfmt clippy rust-analyzer
    cargo install cargo-edit cargo-watch cargo-expand

    # Install additional libraries for Rust development
    if [[ "$(uname)" == "Linux" ]]; then
        install_linux_packages \
            "pkg-config libssl-dev libsqlite3-dev libpq-dev" \
            "pkgconf-pkg-config openssl-devel sqlite-devel libpq-devel" \
            "pkgconfig openssl-devel sqlite-devel postgresql-devel"
    elif [[ "$(uname)" == "Darwin" ]]; then
        brew_install_packages openssl@3 sqlite postgresql
    fi
fi

# Install Electron development requirements
print_status "Installing Electron development dependencies..."
if [[ "$(uname)" == "Linux" ]]; then
    install_linux_packages \
        "libgtk-3-dev libwebkit2gtk-4.1-dev libxss-dev libnss3-dev libasound2-dev libxtst-dev" \
        "gtk3-devel webkit2gtk4.1-devel libXScrnSaver-devel nss-devel alsa-lib-devel libXtst-devel" \
        "gtk3-devel webkit2gtk3-devel libXScrnSaver-devel nss-devel alsa-lib-devel libXtst-devel"

    # Install Wine for Windows builds (optional)
    install_linux_packages "wine64" "wine" "wine" || true
elif [[ "$(uname)" == "Darwin" ]]; then
    brew_install_packages wine
fi

# Install React Native development requirements
print_status "Installing React Native development dependencies..."
if [[ "$(uname)" == "Linux" ]]; then
    install_linux_packages \
        "lib32z1 lib32stdc++6 adb" \
        "zlib.i686 libstdc++.i686 android-tools" \
        "zlib.i686 libstdc++.i686 android-tools"

    # Install JDK for Android development
    if ! command -v java &> /dev/null; then
        install_linux_packages \
            "openjdk-17-jdk" \
            "java-17-openjdk-devel" \
            "java-17-openjdk-devel"
    fi

    # Setup Android SDK path
    mkdir -p "$HOME/Android/Sdk"
    if ! grep -q 'export ANDROID_HOME="$HOME/Android/Sdk"' "$HOME/.zprofile"; then
        echo 'export ANDROID_HOME="$HOME/Android/Sdk"' >> "$HOME/.zprofile"
        echo 'export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"' >> "$HOME/.zprofile"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    brew_install_casks android-studio android-platform-tools adoptopenjdk/openjdk/adoptopenjdk11
    if ! grep -q 'export ANDROID_HOME="$HOME/Library/Android/sdk"' "$HOME/.zprofile"; then
        echo 'export ANDROID_HOME="$HOME/Library/Android/sdk"' >> "$HOME/.zprofile"
        echo 'export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"' >> "$HOME/.zprofile"
    fi
fi

# Install React Native CLI
print_status "Installing React Native CLI..."
if command -v npm &> /dev/null; then
    npm_install_global_packages react-native-cli
else
    print_warning "npm not found. Skipping React Native CLI installation."
fi

# Install Ruby tools
print_status "Installing Ruby tools..."
brew_install_packages rbenv

# Install Kubernetes tools
print_status "Installing Kubernetes tools..."
brew_install_packages \
    minikube \
    kubectx \
    kubectl \
    derailed/k9s/k9s

# Install Flutter with OS-specific method
print_status "Installing Flutter..."
if [[ "$(uname)" == "Linux" ]]; then
    # First check and install Flutter dependencies
    install_linux_packages \
        "clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev" \
        "clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel libstdc++-devel" \
        "clang cmake ninja-build pkgconfig gtk3-devel xz-devel libstdc++-devel"

    # For Linux/WSL2, use the recommended approach
    if should_run_install_step "Flutter SDK" has_dir "$HOME/development/flutter"; then
        if [ "$SETUP_OVERRIDE_INSTALLED" = true ] && [ -d "$HOME/development/flutter" ]; then
            backup_path "$HOME/development/flutter"
        fi
        print_status "Downloading Flutter SDK for Linux..."
        mkdir -p "$HOME/development"
        cd "$HOME/development"
        curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.4-stable.tar.xz
        tar xf flutter_linux_*.tar.xz
        rm flutter_linux_*.tar.xz
        FLUTTER_PATH="$HOME/development/flutter/bin"
        if ! grep -q "export PATH=\\\".*${FLUTTER_PATH}.*\\\"" "$HOME/.zprofile"; then
             echo "export PATH=\\"\\$PATH:${FLUTTER_PATH}\\"" >> "$HOME/.zprofile"
        fi

        # Configure Flutter to use proper display
        if [[ -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
            print_status "Configuring Flutter for WSL environment..."
            cd flutter
            bin/flutter config --no-analytics
            bin/flutter config --enable-web
        fi

        cd "$HOME"
        print_status "Flutter SDK installed to $HOME/development/flutter"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    # For macOS, use Homebrew cask
    brew_install_casks flutter
fi

# Install database development tools
print_status "Installing database development tools..."
if [[ "$(uname)" == "Linux" ]]; then
    LINUX_PM="$(linux_package_manager)"

    # PostgreSQL
    if should_run_install_step "PostgreSQL" has_command psql; then
        print_status "Installing PostgreSQL..."
        install_linux_packages \
            "postgresql postgresql-contrib" \
            "postgresql-server postgresql-contrib" \
            "postgresql-server postgresql-contrib"
    fi

    # MySQL
    if should_run_install_step "MySQL" has_command mysql; then
        print_status "Installing MySQL..."
        install_linux_packages "mysql-server"
    fi

    # Redis
    if should_run_install_step "Redis" has_command redis-server; then
        print_status "Installing Redis..."
        install_linux_packages "redis-server" "redis" "redis"
    fi

    if [ "$LINUX_PM" = "apt" ] && should_run_install_step "MongoDB" has_command mongod; then
        # MongoDB installation for Ubuntu (completely rewritten to fix repository issues)
        print_status "Setting up MongoDB..."

        # First, remove any existing MongoDB repository files
        print_status "Removing any existing MongoDB repository configurations..."
        sudo rm -f /etc/apt/sources.list.d/mongodb*.list

        # Also check and remove any references in the main sources.list
        if [ -f /etc/apt/sources.list ] && grep -q "mongodb" /etc/apt/sources.list; then
            print_status "Removing MongoDB references from main sources.list..."
            sudo sed -i '/mongodb/d' /etc/apt/sources.list
        fi

        # Update package lists after removing old repositories
        sudo apt update

        # Create a fresh temporary directory for MongoDB setup
        MONGO_TEMP_DIR=$(mktemp -d)
        cd "$MONGO_TEMP_DIR"

        # Install MongoDB 6.0 using the jammy repository
        print_status "Adding MongoDB 6.0 GPG key..."
        curl -fsSL https://pgp.mongodb.com/server-6.0.asc | \
            sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg \
            --dearmor

        print_status "Adding MongoDB 6.0 repository for jammy..."
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | \
            sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

        # Ensure package lists are updated from the new repository
        print_status "Updating package lists with new MongoDB repository..."
        sudo apt update

        # Install MongoDB packages
        print_status "Installing MongoDB 6.0..."
        sudo apt install -y mongodb-org

        # Clean up
        cd "$HOME"
        rm -rf "$MONGO_TEMP_DIR"
    else
        print_warning "Skipping MongoDB server package setup on $LINUX_PM. Install MongoDB manually or use a container if needed."
    fi

    # Don't try to start services in WSL as they may not work with systemd
    if [[ -f /proc/version && ! $(grep -i microsoft /proc/version) ]]; then
        if [ "$LINUX_PM" = "apt" ]; then
            POSTGRES_SERVICE="postgresql"
            MYSQL_SERVICE="mysql"
            REDIS_SERVICE="redis-server"
        else
            POSTGRES_SERVICE="postgresql"
            MYSQL_SERVICE="mysqld"
            REDIS_SERVICE="redis"
            if command -v postgresql-setup &> /dev/null; then
                sudo postgresql-setup --initdb || true
            fi
        fi

        sudo systemctl enable "$POSTGRES_SERVICE" || true
        sudo systemctl start "$POSTGRES_SERVICE" || true
        sudo systemctl enable "$MYSQL_SERVICE" || true
        sudo systemctl start "$MYSQL_SERVICE" || true
        sudo systemctl enable "$REDIS_SERVICE" || true
        sudo systemctl start "$REDIS_SERVICE" || true
        if [ "$LINUX_PM" = "apt" ]; then
            sudo systemctl enable mongod || true
            sudo systemctl start mongod || true
        fi
    else
        print_warning "Running in WSL environment. Database services will need to be started manually:"
        print_warning "  PostgreSQL: sudo service postgresql start"
        print_warning "  MySQL: sudo service mysql start"
        print_warning "  Redis: sudo service redis-server start"
        print_warning "  MongoDB: sudo service mongod start"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    brew_install_packages postgresql mysql redis mongodb-community
    brew services start postgresql
    brew services start mysql
    brew services start redis
    brew services start mongodb-community
fi

# Install database management tools
print_status "Installing database management tools..."
if command -v npm &> /dev/null; then
    npm_install_global_packages prisma sequelize-cli typeorm
fi

# Install Firebase tools
print_status "Installing Firebase tools and development environment..."
if command -v npm &> /dev/null; then
    npm_install_global_packages firebase-tools @firebase/cli

    # Initialize Firebase
    print_status "Setting up Firebase configuration directory..."
    mkdir -p "$HOME/.config/firebase"
fi

# Install AWS CLI and development tools
print_status "Installing AWS CLI and development tools..."
if [[ "$(uname)" == "Linux" ]]; then
    # Install AWS CLI v2
    if should_run_install_step "AWS CLI" has_command aws; then
        print_status "Installing AWS CLI v2..."
        cd /tmp
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
    fi

    # Install AWS SAM CLI
    if should_run_install_step "AWS SAM CLI" has_command sam; then
        print_status "Installing AWS SAM CLI..."
        # Install prerequisites
        install_linux_packages "python3-pip"
        pip3 install aws-sam-cli
    fi

    # Install AWS CDK
    if should_run_install_step "AWS CDK" has_command cdk; then
        print_status "Installing AWS CDK..."
        if command -v npm &> /dev/null; then
            npm_install_global_packages aws-cdk
        fi
    fi

    # Install AWS Amplify CLI
    if should_run_install_step "AWS Amplify CLI" has_command amplify; then
        print_status "Installing AWS Amplify CLI..."
        if command -v npm &> /dev/null; then
            npm_install_global_packages @aws-amplify/cli
        fi
    fi

    # Install additional AWS tools
    print_status "Installing additional AWS development tools..."
    pip3 install boto3 awscli-local

elif [[ "$(uname)" == "Darwin" ]]; then
    # Install AWS tools via Homebrew
    brew_install_packages awscli aws-sam-cli

    # Install AWS CDK and Amplify via npm
    if command -v npm &> /dev/null; then
        npm_install_global_packages aws-cdk @aws-amplify/cli
    fi

    # Install additional AWS tools
    pip3 install boto3 awscli-local
fi

# Create AWS config directory
mkdir -p "$HOME/.aws"

# Install Google Cloud SDK
print_status "Installing Google Cloud SDK..."
if should_run_install_step "Google Cloud SDK" has_command gcloud; then
if [[ "$(uname)" == "Linux" ]]; then
    if [ "$(linux_package_manager)" = "apt" ]; then
        # Install dependencies
        install_linux_packages "apt-transport-https ca-certificates gnupg curl"

        # Add Google Cloud SDK distribution URI as a package source
        print_status "Adding Google Cloud SDK repository..."
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

        # Import Google Cloud public key
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

        # Update and install the SDK
        sudo apt update
        sudo apt install -y google-cloud-sdk google-cloud-sdk-app-engine-python google-cloud-sdk-app-engine-python-extras google-cloud-sdk-datastore-emulator google-cloud-sdk-pubsub-emulator

        # Install Firebase emulator dependencies
        install_linux_packages "openjdk-17-jdk"
    else
        print_warning "Google Cloud apt repositories are Debian/Ubuntu-specific; using Homebrew fallback."
        install_with_brew_or_warn google-cloud-sdk
        install_linux_packages \
            "openjdk-17-jdk" \
            "java-17-openjdk-devel" \
            "java-17-openjdk-devel"
    fi

elif [[ "$(uname)" == "Darwin" ]]; then
    # Install Google Cloud SDK via Homebrew
    brew_install_casks google-cloud-sdk
fi
else
    print_status "Google Cloud SDK already installed; skipping Google Cloud SDK installer."
fi

# Initialize gcloud directory
mkdir -p "$HOME/.config/gcloud"

# Install Firebase emulators if npm is available
if command -v npm &> /dev/null && command -v firebase &> /dev/null; then
    print_status "Setting up Firebase emulators..."
    firebase setup:emulators:firestore
    firebase setup:emulators:database
    firebase setup:emulators:pubsub
    firebase setup:emulators:storage
    firebase setup:emulators:ui
fi

# Install Azure CLI and development tools
print_status "Installing Azure CLI and development tools..."
if [[ "$(uname)" == "Linux" ]]; then
    if should_run_install_step "Azure CLI" has_command az; then
        if [ "$(linux_package_manager)" = "apt" ]; then
            # Install dependencies
            install_linux_packages "ca-certificates curl apt-transport-https lsb-release gnupg"

            # Download and install the Microsoft signing key
            print_status "Adding Microsoft repository..."
            curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null

            # Add the Azure CLI software repository
            AZ_REPO=$(lsb_release -cs)
            if [[ "$AZ_REPO" == "noble" ]]; then
                # Use jammy repo for noble (24.04) until dedicated repo is available
                AZ_REPO="jammy"
            fi
            echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list

            # Update repository and install Azure CLI
            sudo apt update
            sudo apt install -y azure-cli
        else
            print_warning "Azure apt repositories are Debian/Ubuntu-specific; using Homebrew fallback."
            install_with_brew_or_warn azure-cli
        fi
    fi

    if should_run_install_step "Azure Functions Core Tools" has_command func; then
        if [ "$(linux_package_manager)" = "apt" ]; then
            # Install Azure Functions Core Tools
            print_status "Installing Azure Functions Core Tools..."
            curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
            sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
            sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
            sudo apt update
            sudo apt install -y azure-functions-core-tools-4
        else
            if command -v brew &> /dev/null; then
                brew tap azure/functions || true
                brew_install_packages azure-functions-core-tools@4 || brew_install_packages azure-functions-core-tools || print_warning "Failed to install Azure Functions Core Tools with Homebrew"
            else
                print_warning "Homebrew is not available; skipping Azure Functions Core Tools"
            fi
        fi
    fi

    # Install Azure Dev CLI
    if should_run_install_step "Azure Dev CLI" has_command azd; then
        print_status "Installing Azure Dev CLI..."
        if [ "$(linux_package_manager)" = "apt" ]; then
            curl -fsSL https://aka.ms/install-azd.sh | bash
        else
            install_with_brew_or_warn azure/azd/azd
        fi
    fi

    # Install Azure Static Web Apps CLI
    if command -v npm &> /dev/null; then
        npm_install_global_packages @azure/static-web-apps-cli
    fi

elif [[ "$(uname)" == "Darwin" ]]; then
    # Install Azure CLI via Homebrew
    if should_run_install_step "Azure CLI" has_command az; then
        brew_install_packages azure-cli
    fi

    # Install Azure Functions Core Tools
    if should_run_install_step "Azure Functions Core Tools" has_command func; then
        brew tap azure/functions
        brew_install_packages azure-functions-core-tools@4
    fi

    # Install Azure Dev CLI
    if should_run_install_step "Azure Dev CLI" has_command azd; then
        brew_install_packages azure/azd/azd
    fi

    # Install Azure Static Web Apps CLI
    if command -v npm &> /dev/null; then
        npm_install_global_packages @azure/static-web-apps-cli
    fi
fi

# Create Azure config directory
mkdir -p "$HOME/.azure"

# Create aliases for cloud development
if should_run_install_step "cloud development aliases" has_file "$HOME/.config/zsh/cloud_aliases.zsh"; then
    print_status "Creating cloud development aliases..."
    cat > "$HOME/.config/zsh/cloud_aliases.zsh" << EOF
# Firebase aliases
alias fb='firebase'
alias fbdeploy='firebase deploy'
alias fbserve='firebase serve'
alias fbemu='firebase emulators:start'

# AWS aliases
alias awsp='aws --profile'
alias cdks='cdk synth'
alias cdkd='cdk deploy'
alias cdkdiff='cdk diff'
alias samd='sam deploy'
alias samb='sam build'
alias saml='sam local'

# Google Cloud aliases
alias gcl='gcloud'
alias gcauth='gcloud auth login'
alias gcconf='gcloud config'
alias gcproj='gcloud config set project'

# Azure aliases
alias azl='az login'
alias azacct='az account show'
alias azgroup='az group'
alias azfunc='func'
alias azdeploy='az deployment'
EOF
fi

# Add cloud aliases to zshrc if not already included
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "source \$HOME/.config/zsh/cloud_aliases.zsh" "$HOME/.zshrc"; then
        echo '# Load cloud development aliases' >> "$HOME/.zshrc"
        echo 'if [ -f "$HOME/.config/zsh/cloud_aliases.zsh" ]; then' >> "$HOME/.zshrc"
        echo '  source $HOME/.config/zsh/cloud_aliases.zsh' >> "$HOME/.zshrc"
        echo 'fi' >> "$HOME/.zshrc"
    fi
fi

# Link shared agent configuration into each supported agent CLI.
setup_agent_configs

# Final setup
print_status "Performing final setup..."

# Copy our zshrc if it exists in the same directory
if [ -f "./zshrc" ]; then
    if should_run_install_step "zshrc" has_file "$HOME/.zshrc"; then
        cp ./zshrc "$HOME/.zshrc"
    fi
fi

# WSL2-specific optimizations
if [[ "$(uname)" == "Linux" && -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
    print_status "Applying WSL2-specific optimizations..."

    # Check if Windows integration is working properly
    if ! WINDOWS_HOME=$(wslpath "$(wslvar USERPROFILE)" 2>/dev/null); then
        print_warning "Cannot access Windows home directory. WSL integration might not be properly set up."
        print_warning "Some features may not work correctly."
        # Try alternative method to find Windows home
        if [ -d "/mnt/c/Users" ]; then
            # Find the most likely Windows username by listing directories in /mnt/c/Users
            WIN_USER=$(ls -la /mnt/c/Users/ | grep -v "Public\|Default\|All Users\|Default User\|desktop.ini" | tail -1 | awk '{print $9}')
            if [ -n "$WIN_USER" ]; then
                WINDOWS_HOME="/mnt/c/Users/$WIN_USER"
                print_status "Using alternative Windows home path: $WINDOWS_HOME"
            else
                WINDOWS_HOME="/mnt/c/Users"
                print_warning "Could not determine Windows username, using $WINDOWS_HOME"
            fi
        else
            print_error "Windows C: drive not accessible. Your WSL setup might have issues."
            WINDOWS_HOME="$HOME"
        fi
    fi

    # Create .wslconfig in Windows home if it doesn't exist
    if [ ! -f "$WINDOWS_HOME/.wslconfig" ]; then
        print_status "Creating .wslconfig for better WSL2 performance..."
        cat > "$WINDOWS_HOME/.wslconfig" << EOF
[wsl2]
memory=8GB
processors=4
localhostForwarding=true
kernelCommandLine=net.ifnames=0
EOF
    fi

    # Add WSL-specific settings to .zprofile if not already present
    if ! grep -q "# WSL2-specific settings" "$HOME/.zprofile"; then
        cat >> "$HOME/.zprofile" << EOF

# WSL2-specific settings
export BROWSER=wslview
export DISPLAY=:0
# Improve Docker performance on WSL2
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
EOF
    fi

    # Check for common WSL2 issues
    print_status "Checking for common WSL2 issues..."

    # Check if Windows Firewall might be blocking connections
    if ! curl -s https://api.github.com > /dev/null; then
        print_warning "Network connectivity issues detected. Windows Firewall might be blocking WSL2 connections."
        print_warning "You may need to add a Windows Firewall rule to allow WSL2 traffic."
    fi

    # Check for Windows path in PATH variable
    if echo $PATH | grep -q "/mnt/c/Windows"; then
        print_warning "Windows paths detected in your PATH. This can cause slowdowns and compatibility issues."
        print_warning "Consider removing Windows paths from your PATH variable in Linux environment."
    fi

    # Check disk space on WSL2 virtual disk
    DISK_SPACE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_SPACE" -gt 80 ]; then
        print_warning "WSL2 virtual disk usage is high (${DISK_SPACE}%). Consider cleaning up or expanding the virtual disk."
    fi
fi

# Verify installation
print_status "Verifying installation..."

# Check critical tools
INSTALLATION_ISSUES=false

verify_tool() {
    if command -v $1 &> /dev/null; then
        print_status "$1 is successfully installed"
        return 0
    else
        print_error "$1 installation failed or not in PATH"
        print_warning "You may need to restart your terminal or run 'source ~/.zprofile' to update PATH"
        INSTALLATION_ISSUES=true
        return 1
    fi
}

# Check shell tools
verify_tool zsh
verify_tool git
verify_tool nvim
verify_tool tmux

# Check runtime managers
verify_tool mise

# Check if node is available through mise
if command -v mise &> /dev/null; then
    if mise which node &> /dev/null; then
        print_status "Node.js is available through mise"
        NODE_VERSION=$(node -v)
        print_status "Node.js version: $NODE_VERSION"
    else
        print_warning "Node.js not available through mise. Try running: mise install nodejs@lts"
        INSTALLATION_ISSUES=true
    fi
fi

# Check cloud development tools
print_status "Verifying cloud development tools..."

# Check Firebase tools
if verify_tool firebase; then
    FIREBASE_VERSION=$(firebase --version)
    print_status "Firebase CLI version: $FIREBASE_VERSION"
else
    print_warning "Firebase CLI not found. You may need to restart your terminal or run 'npm install -g firebase-tools'"
fi

# Check AWS CLI
if verify_tool aws; then
    AWS_VERSION=$(aws --version)
    print_status "AWS CLI version: $AWS_VERSION"

    # Check AWS CDK
    if verify_tool cdk; then
        CDK_VERSION=$(cdk --version)
        print_status "AWS CDK version: $CDK_VERSION"
    fi

    # Check AWS SAM CLI
    if verify_tool sam; then
        SAM_VERSION=$(sam --version)
        print_status "AWS SAM CLI version: $SAM_VERSION"
    fi

    # Check AWS Amplify CLI
    if verify_tool amplify; then
        AMPLIFY_VERSION=$(amplify --version)
        print_status "AWS Amplify CLI version: $AMPLIFY_VERSION"
    fi
else
    print_warning "AWS CLI not found. You may need to restart your terminal or check the AWS installation"
fi

# Check Google Cloud SDK
if verify_tool gcloud; then
    GCLOUD_VERSION=$(gcloud --version | head -n 1)
    print_status "Google Cloud SDK: $GCLOUD_VERSION"
else
    print_warning "Google Cloud SDK not found. You may need to restart your terminal or check the gcloud installation"
fi

# Check Azure CLI
if verify_tool az; then
    AZ_VERSION=$(az --version | grep "azure-cli" | head -n 1)
    print_status "Azure CLI: $AZ_VERSION"

    # Check Azure Functions Core Tools
    if verify_tool func; then
        FUNC_VERSION=$(func --version)
        print_status "Azure Functions Core Tools version: $FUNC_VERSION"
    fi

    # Check Azure Developer CLI
    if verify_tool azd; then
        AZD_VERSION=$(azd version)
        print_status "Azure Developer CLI version: $AZD_VERSION"
    fi
else
    print_warning "Azure CLI not found. You may need to restart your terminal or check the Azure CLI installation"
fi

# Final message
if [ "$INSTALLATION_ISSUES" = true ]; then
    print_warning "Some issues were detected with your installation. Please review the warnings above."
    print_status "You may need to restart your terminal or run 'source ~/.zprofile' to apply all changes."
else
    print_status "Installation verification complete! All critical components are installed."
fi

print_status "Setup complete! Please restart your terminal and run 'p10k configure' to set up your prompt."
