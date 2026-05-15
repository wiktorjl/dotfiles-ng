# shellcheck shell=bash
# Shared logging + TUI helpers for the dotfiles-ng deploy scripts.
#
# To use:
#   BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   LOG_NAME=deploy_all            # only if this script writes a log file
#   . "$BASE_DIR/lib/log.sh"
#
# LOG_NAME selects the log filename prefix: $LOG_DIR/${LOG_NAME}_<ts>.log.
# Scripts that only need the colors/print_* can source without setting LOG_NAME.
#
# Colors auto-disable when stdout is not a TTY (e.g. piped to grep, redirected
# to a file). Override with LOG_TTY=1 to force-on or LOG_TTY=0 to force-off.

if [ -n "${_LIB_LOG_SOURCED:-}" ]; then return 0; fi
_LIB_LOG_SOURCED=1

# Colors — TTY-aware, so logs and pipes don't get escape sequences.
case "${LOG_TTY:-auto}" in
    1) _log_use_color=1 ;;
    0) _log_use_color=0 ;;
    *) if [ -t 1 ]; then _log_use_color=1; else _log_use_color=0; fi ;;
esac

if [ "$_log_use_color" = 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE='' BOLD='' NC=''
fi
unset _log_use_color

# Log file setup. Only triggers when the caller has set LOG_NAME, so passive
# consumers (link_bin_scripts.sh, review_logs.sh) get colors only.
if [ -n "${LOG_NAME:-}" ]; then
    : "${LOG_DIR:=${BASE_DIR:-$PWD}/logs}"
    mkdir -p "$LOG_DIR"
    _log_ts="$(date +%Y%m%d_%H%M%S)"
    : "${LOG_FILE:=$LOG_DIR/${LOG_NAME}_${_log_ts}.log}"
    : "${ERROR_LOG:=$LOG_DIR/errors_${_log_ts}.log}"
    unset _log_ts
fi

log_message() {
    if [ -n "${LOG_FILE:-}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}

log_error() {
    local line="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
    if [ -n "${LOG_FILE:-}" ] && [ -n "${ERROR_LOG:-}" ]; then
        echo "$line" | tee -a "$LOG_FILE" >> "$ERROR_LOG"
    elif [ -n "${LOG_FILE:-}" ]; then
        echo "$line" | tee -a "$LOG_FILE"
    else
        echo "$line"
    fi
}

# log_command "<description>" cmd args...
# Tees command output to LOG_FILE and returns the command's exit code (via
# PIPESTATUS, so the tee doesn't mask a non-zero status).
log_command() {
    local desc="$1"
    shift
    log_message "COMMAND: $desc"
    log_message "EXECUTING: $(printf '%q ' "$@")"
    if [ -n "${LOG_FILE:-}" ]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
    else
        "$@"
    fi
    local exit_code=${PIPESTATUS[0]}
    if [ "$exit_code" -ne 0 ]; then
        log_error "Command failed with exit code $exit_code: $(printf '%q ' "$@")"
    fi
    return "$exit_code"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
    log_message "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_error "$1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log_message "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_message "INFO: $1"
}

print_progress() {
    echo -e "${MAGENTA}[PROG]${NC} $1"
    log_message "PROGRESS: $1"
}
