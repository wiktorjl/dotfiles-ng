#!/bin/bash

# Dotfiles Log Review Tool
# This script helps you review deployment logs and errors

LOG_DIR="/home/$USER/dotfiles-ng/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}+============================================================+${NC}"
    echo -e "${CYAN}|${BOLD}                    LOG REVIEW TOOL                        ${NC}${CYAN}|${NC}"
    echo -e "${CYAN}+============================================================+${NC}"
    echo
}

show_usage() {
    echo -e "${BOLD}Usage:${NC}"
    echo "  $0 [OPTION]"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo "  -e, --errors     Show only error logs"
    echo "  -l, --latest     Show latest deployment log"
    echo "  -a, --all        Show all logs"
    echo "  -s, --summary    Show summary of all deployments"
    echo "  -h, --help       Show this help message"
    echo
}

list_log_files() {
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${YELLOW}[WARN]${NC} No logs directory found at $LOG_DIR"
        return 1
    fi
    
    echo -e "${BOLD}Available log files:${NC}"
    echo -e "${CYAN}+=====================================+====================+${NC}"
    echo -e "${CYAN}|${NC} ${BOLD}File${NC}                               ${CYAN}|${NC} ${BOLD}Size${NC}               ${CYAN}|${NC}"
    echo -e "${CYAN}+=====================================+====================+${NC}"
    
    for logfile in "$LOG_DIR"/*.log; do
        if [ -f "$logfile" ]; then
            filename=$(basename "$logfile")
            size=$(du -h "$logfile" | cut -f1)
            printf "${CYAN}|${NC} %-35s ${CYAN}|${NC} %-18s ${CYAN}|${NC}\n" "$filename" "$size"
        fi
    done
    echo -e "${CYAN}+=====================================+====================+${NC}"
    echo
}

show_errors() {
    echo -e "${RED}[ERROR LOGS]${NC}"
    echo -e "${RED}============${NC}"
    
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${YELLOW}[WARN]${NC} No logs directory found"
        return 1
    fi
    
    error_count=0
    for error_file in "$LOG_DIR"/errors_*.log; do
        if [ -f "$error_file" ]; then
            echo -e "${BOLD}File: $(basename "$error_file")${NC}"
            echo -e "${RED}$(cat "$error_file")${NC}"
            echo
            error_count=$((error_count + 1))
        fi
    done
    
    if [ $error_count -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} No error logs found!"
    else
        echo -e "${YELLOW}Found $error_count error log files${NC}"
    fi
}

show_latest() {
    echo -e "${BLUE}[LATEST DEPLOYMENT LOG]${NC}"
    echo -e "${BLUE}=======================${NC}"
    
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${YELLOW}[WARN]${NC} No logs directory found"
        return 1
    fi
    
    latest_log=$(ls -t "$LOG_DIR"/deploy_*.log 2>/dev/null | head -n1)
    
    if [ -z "$latest_log" ]; then
        echo -e "${YELLOW}[WARN]${NC} No deployment logs found"
        return 1
    fi
    
    echo -e "${BOLD}File: $(basename "$latest_log")${NC}"
    echo -e "${BOLD}Date: $(stat -c %y "$latest_log")${NC}"
    echo
    cat "$latest_log"
}

show_summary() {
    echo -e "${BLUE}[DEPLOYMENT SUMMARY]${NC}"
    echo -e "${BLUE}===================${NC}"
    
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${YELLOW}[WARN]${NC} No logs directory found"
        return 1
    fi
    
    total_deployments=$(ls "$LOG_DIR"/deploy_*.log 2>/dev/null | wc -l)
    total_errors=$(ls "$LOG_DIR"/errors_*.log 2>/dev/null | wc -l)
    
    echo -e "${BOLD}Total deployments:${NC} $total_deployments"
    echo -e "${BOLD}Error logs:${NC} $total_errors"
    echo
    
    echo -e "${BOLD}Recent deployments:${NC}"
    ls -lt "$LOG_DIR"/deploy_*.log 2>/dev/null | head -5 | while read -r line; do
        filename=$(echo "$line" | awk '{print $9}')
        date=$(echo "$line" | awk '{print $6, $7, $8}')
        if [ -n "$filename" ]; then
            echo "  $(basename "$filename") - $date"
        fi
    done
}

show_all() {
    echo -e "${BLUE}[ALL LOGS]${NC}"
    echo -e "${BLUE}=========${NC}"
    
    list_log_files
    
    for logfile in "$LOG_DIR"/*.log; do
        if [ -f "$logfile" ]; then
            echo -e "${BOLD}=== $(basename "$logfile") ===${NC}"
            cat "$logfile"
            echo
        fi
    done
}

# Main script logic
print_header

case "${1:-}" in
    -e|--errors)
        show_errors
        ;;
    -l|--latest)
        show_latest
        ;;
    -a|--all)
        show_all
        ;;
    -s|--summary)
        show_summary
        ;;
    -h|--help|"")
        show_usage
        list_log_files
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Unknown option: $1"
        echo
        show_usage
        exit 1
        ;;
esac