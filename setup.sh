#!/usr/bin/env zsh

set -eo pipefail

# User account where the ansible-collection-mac repository is located.
GH_USER="maodevops"

: "${REPO_URL:="https://github.com/${GH_USER}/ansible-collection-mac.git"}"
: "${CLONE_DIR:="${HOME}/code/github.com/${GH_USER}/ansible-collection-mac"}"
: "${VENV_DIR:="${HOME}/.venvs/ansible-latest"}"
: "${SETUP_PLAYBOOK:=${GH_USER}.mac.setup_mac.yml}"

# BEGIN: Logging vars and functions
declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4 [OFF]=5)
declare -A LOG_COLORS=([DEBUG]=2 [INFO]=12 [WARN]=3 [ERROR]=1 [FATAL]=9 [OFF]=0 [OTHER]=15 [MESSAGE]=118)

export LOG_LEVEL="DEBUG"

log.msg() {
  local msg="$1"
  local lvl="${2:-${LOG_COLORS['MESSAGE']}}"
  [[ -t 1 ]] && tput setaf $lvl
  echo -e "${msg}" 1>&2
  [[ -t 1 ]] && tput sgr0
}

log.log() {
  local lvl=${1:-INFO}
  local msg="$2"
  if [[ ${LOG_LEVELS[$LOG_LEVEL]} -le ${LOG_LEVELS[$lvl]} ]]; then
    [[ -t 1 ]] && tput setaf ${LOG_COLORS[$lvl]}
    printf "[%-5s] " "${lvl}" 1>&2
    log.msg "${msg}" "${lvl}"
    [[ -t 1 ]] && tput sgr0
  fi
}

log.debug() { log.log "DEBUG" "${1:-}"; }
log.info()  { log.log "INFO"  "${1:-}"; }
log.warn()  { log.log "WARN"  "${1:-}"; }
log.error() { log.log "ERROR" "${1:-}"; }
log.fatal() { log.log "FATAL" "${1:-}"; }

log.line() {
  local char="${1:-"-"}"
  local length="${2:-$(tput cols)}"
  local color="${3:-15}"  # Default to white (15)
  local line=$(printf "%${length}s" | tr " " "$char")
  [[ -t 1 ]] && tput setaf "$color"
  echo "$line"
  [[ -t 1 ]] && tput sgr0
}

log.header() {
  local message="$1"
  local char="${2:-"-"}"
  local length="${3:-$(tput cols)}"
  local color="${4:-15}"  # Default to white (15)
  local line=$(printf "%${length}s" | tr " " "$char")
  log.line "$char" "$length" "$color"
  [[ -t 1 ]] && tput setaf "$color"
  echo -e "${message}"
  log.line "$char" "$length" "$color"
  [[ -t 1 ]] && tput sgr0
}

# END: Logging vars and functions

# Set script directory
if [[ -z "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="${CLONE_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

prompt_to_continue() {
  echo "This script will install Homebrew, uv, Python, Ansible, and run an Ansible playbook to set up your macOS system."
  while true; do
    read -r -p "Continue? (y/n): " answer < /dev/tty
    case "$answer" in
      [Yy] ) 
        echo "Continuing..."
        break
        ;;
      [Nn] ) 
        echo "Aborting."
        exit 1
        ;;
      * )
        echo "Please answer y or n."
        ;;
    esac
  done
} 

check_vars() {
  local required_vars=(
    "MY_GIT_USER_NAME"
    "MY_GIT_USER_EMAIL"
  )
  local missing_vars=()
  local var_name

  for var_name in "${required_vars[@]}"; do
    if [[ -z "${!var_name:-}" ]]; then
      missing_vars+=("${var_name}")
    fi
  done

  if (( ${#missing_vars[@]} > 0 )); then
    log.fatal "Required variables are not set: ${missing_vars[*]}. Please set them before running the script."
    exit 1
  fi
}

install_homebrew() {

  log.msg "\nInstalling Homebrew ...\n"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    BREW=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    BREW=/usr/local/bin/brew
  else
    BREW=""
  fi

  if [[ -n "${BREW}" ]]; then
    log.info "Homebrew already installed at ${BREW}"
  else
    log.info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    if [[ -x /opt/homebrew/bin/brew ]]; then
      BREW=/opt/homebrew/bin/brew
    else
      BREW=/usr/local/bin/brew
    fi
  fi

  # Add brew to PATH for this session
  eval "$("${BREW}" shellenv)"
  export BREW_PREFIX="$($BREW --prefix)"
}

install_git() {
  log.msg "\nChecking for git ...\n"
  if ! command -v git &>/dev/null; then
    log.info "Installing git via Homebrew..."
    brew install git
  else
    log.info "git already installed: $(git --version)"
  fi
}

install_uv() {
  log.msg "\nInstalling uv ...\n"

  if command -v uv &>/dev/null; then
    log.info "uv already installed: $(command -v uv)"
  else
    log.info "Installing uv via Homebrew..."
    brew install uv
  fi

  if ! command -v uv &>/dev/null; then
    log.fatal "uv not found after installation. Please check the installer output above."
    exit 1
  fi

  log.info "uv: $(uv --version)"
}


install_python() {
  log.msg "\nInstalling Python via uv ...\n"

  # RUST_LOG=trace uv python install -vvv
  uv python install
}


clone_repo() {
  log.msg "\nCloning repository ...\n"

  if [[ -d "${CLONE_DIR}/.git" ]]; then
    log.info "Repository already cloned at ${CLONE_DIR}"
    git -C "${CLONE_DIR}" pull --ff-only || true
  else
    log.info "Cloning repository from ${REPO_URL} to ${CLONE_DIR}..."
    git clone "${REPO_URL}" "${CLONE_DIR}"
  fi
}

activate_venv() {
  if [[ -d "${VENV_DIR}" ]]; then
    log.info "Virtualenv already exists at ${VENV_DIR}"
  else
    log.info "Creating virtualenv at ${VENV_DIR}..."
    mkdir -p "${VENV_DIR}"
    uv venv "${VENV_DIR}"
  fi  
  # shellcheck source=/dev/null
  source "${VENV_DIR}/bin/activate"  
}

install_ansible() {
  if python -c "import ansible" &>/dev/null; then
    log.info "Ansible already installed: $(ansible --version | head -1)"
  else
    log.info "Installing Ansible..."
    uv pip install ansible
  fi
} 

install_ansible_collections() {
  log.msg "\nInstalling Ansible collections ...\n"
  cd "${SCRIPT_DIR}"
  ansible-galaxy collection install -r requirements.yml
}

set_ansible_vars() {
  log.msg "\nSetting Ansible variables ...\n"
  cp "${SCRIPT_DIR}/vars/user.yml.example" "${SCRIPT_DIR}/vars/user.yml"
  sed -i '' "s/^git_user_name: .*/git_user_name: ${MY_GIT_USER_NAME}/g" "${SCRIPT_DIR}/vars/user.yml"
  sed -i '' "s/^git_user_email: .*/git_user_email: ${MY_GIT_USER_EMAIL}/g" "${SCRIPT_DIR}/vars/user.yml"
}

run_playbook() {
  log.msg "\nRunning '${SETUP_PLAYBOOK}' Ansible playbook ...\n"
  ansible-playbook -c local -i '127.0.0.1,' "${SETUP_PLAYBOOK}"
}

main() {
  prompt_to_continue
  check_vars

  echo ""
  log.header "MAC SETUP\nInstalling and configuring tools for a macOS dev system" "=" 118  
  echo ""  

  install_homebrew
  install_git
  install_uv
  install_python
  clone_repo
  activate_venv
  install_ansible
  install_ansible_collections
  set_ansible_vars
  run_playbook

}

main "$@"
