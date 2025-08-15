#!/bin/bash

# Milvus Backup Service Installer
# This script installs the Milvus backup systemd timer service

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/data/backup"
BACKUP_CONFIG="$BACKUP_DIR/config.yaml"
INSTALL_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
LOG_FILE="/var/log/milvus-backup.log"

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if systemd is available
    if ! command -v systemctl &> /dev/null; then
        print_error "systemctl not found. This system doesn't appear to use systemd."
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        echo "Installation guide: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_warning "Docker daemon is not running. Attempting to start..."
        systemctl start docker || {
            print_error "Failed to start Docker daemon"
            exit 1
        }
    fi
    
    print_success "Prerequisites check passed"
}

# Verify source files exist
check_source_files() {
    print_status "Checking source files..."
    
    local files_missing=0
    
    if [[ ! -f "$SCRIPT_DIR/bin/milvus-backup.sh" ]]; then
        print_error "Missing: bin/milvus-backup.sh"
        files_missing=1
    fi
    
    if [[ ! -f "$SCRIPT_DIR/systemd/milvus-backup.service" ]]; then
        print_error "Missing: systemd/milvus-backup.service"
        files_missing=1
    fi
    
    if [[ ! -f "$SCRIPT_DIR/systemd/milvus-backup.timer" ]]; then
        print_error "Missing: systemd/milvus-backup.timer"
        files_missing=1
    fi
    
    if [[ $files_missing -eq 1 ]]; then
        print_error "Required files are missing. Please ensure you're running this from the correct directory."
        exit 1
    fi
    
    print_success "Source files verified"
}

# Create directories
create_directories() {
    print_status "Creating directories..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    chown root:root "$BACKUP_DIR"
    chmod 755 "$BACKUP_DIR"
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    cp "config.yaml" "$BACKUP_CONFIG"
    
    print_success "Directories created"
}

# Install backup script
install_script() {
    print_status "Installing backup script..."
    
    cp "$SCRIPT_DIR/bin/milvus-backup.sh" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/milvus-backup.sh"
    chown root:root "$INSTALL_DIR/milvus-backup.sh"
    
    print_success "Backup script installed to $INSTALL_DIR/milvus-backup.sh"
}

# Install systemd files
install_systemd_files() {
    print_status "Installing systemd files..."
    
    # Copy service file
    cp "$SCRIPT_DIR/systemd/milvus-backup.service" "$SYSTEMD_DIR/"
    chmod 644 "$SYSTEMD_DIR/milvus-backup.service"
    chown root:root "$SYSTEMD_DIR/milvus-backup.service"
    
    # Copy timer file
    cp "$SCRIPT_DIR/systemd/milvus-backup.timer" "$SYSTEMD_DIR/"
    chmod 644 "$SYSTEMD_DIR/milvus-backup.timer"
    chown root:root "$SYSTEMD_DIR/milvus-backup.timer"
    
    print_success "Systemd files installed"
}

# Reload systemd and enable services
setup_systemd() {
    print_status "Configuring systemd..."
    
    # Reload systemd daemon
    systemctl daemon-reload
    
    # Enable timer (will start on boot)
    systemctl enable milvus-backup.timer
    
    # Start timer
    systemctl start milvus-backup.timer
    
    print_success "Systemd timer enabled and started"
}

# Pull Docker image
pull_docker_image() {
    print_status "Pulling Milvus backup Docker image..."
    
    if docker pull milvusdb/milvus-backup:latest; then
        print_success "Docker image pulled successfully"
    else
        print_warning "Failed to pull Docker image. It will be pulled automatically on first backup."
    fi
}

# Test installation
test_installation() {
    print_status "Testing installation..."
    
    # Check if timer is active
    if systemctl is-active --quiet milvus-backup.timer; then
        print_success "Timer is active"
    else
        print_warning "Timer is not active"
        return 1
    fi
    
    # Check if timer is enabled
    if systemctl is-enabled --quiet milvus-backup.timer; then
        print_success "Timer is enabled for boot"
    else
        print_warning "Timer is not enabled for boot"
        return 1
    fi
    
    # Show next scheduled run
    local next_run
    next_run=$(systemctl list-timers milvus-backup.timer --no-pager --no-legend | awk '{print $1, $2}' | head -1)
    if [[ -n "$next_run" ]]; then
        print_success "Next backup scheduled: $next_run"
    fi
    
    return 0
}

# Show post-installation information
show_info() {
    echo
    echo "=================================="
    echo "  Milvus Backup Service Installed"
    echo "=================================="
    echo
    echo "📁 Backup Directory: $BACKUP_DIR"
    echo "📄 Log File: $LOG_FILE"
    echo "⏰ Schedule: Daily at 2:00 AM"
    echo "🗂️  Retention: 3 days"
    echo
    echo "Useful Commands:"
    echo "  • Check timer status:    systemctl status milvus-backup.timer"
    echo "  • View next run time:    systemctl list-timers milvus-backup.timer"
    echo "  • Run backup manually:   systemctl start milvus-backup.service"
    echo "  • View logs:             journalctl -u milvus-backup.service"
    echo "  • View backup logs:      tail -f $LOG_FILE"
    echo
    echo "Configuration:"
    echo "  • Edit backup script:    $INSTALL_DIR/milvus-backup.sh"
    echo "  • Edit timer schedule:   $SYSTEMD_DIR/milvus-backup.timer"
    echo
    echo "To test the backup service:"
    echo "  sudo systemctl start milvus-backup.service"
    echo "  sudo journalctl -u milvus-backup.service -f"
    echo
}

# Cleanup on error
cleanup_on_error() {
    print_error "Installation failed. Cleaning up..."
    
    # Stop and disable timer if it was started
    systemctl stop milvus-backup.timer 2>/dev/null || true
    systemctl disable milvus-backup.timer 2>/dev/null || true
    
    # Remove installed files
    rm -f "$SYSTEMD_DIR/milvus-backup.service"
    rm -f "$SYSTEMD_DIR/milvus-backup.timer"
    rm -f "$INSTALL_DIR/milvus-backup.sh"
    
    systemctl daemon-reload
    
    print_error "Cleanup completed"
}

# Main installation function
main() {
    echo "Milvus Backup Service Installer"
    echo "==============================="
    echo
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Run installation steps
    check_root
    check_prerequisites
    check_source_files
    create_directories
    install_script
    install_systemd_files
    setup_systemd
    pull_docker_image
    
    # Test installation
    if test_installation; then
        print_success "Installation completed successfully!"
        show_info
    else
        print_warning "Installation completed with warnings. Please check the status manually."
        show_info
    fi
}

# Show help
show_help() {
    echo "Milvus Backup Service Installer"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --uninstall    Uninstall the service"
    echo
    echo "This script installs a systemd timer that creates daily backups"
    echo "of your Milvus database using Docker."
    echo
    echo "Prerequisites:"
    echo "  • Linux system with systemd"
    echo "  • Docker installed and running"
    echo "  • Root or sudo access"
    echo "  • Milvus database accessible"
    echo
}

# Uninstall function
uninstall() {
    print_status "Uninstalling Milvus backup service..."
    
    # Stop and disable timer
    systemctl stop milvus-backup.timer 2>/dev/null || true
    systemctl disable milvus-backup.timer 2>/dev/null || true
    
    # Remove systemd files
    rm -f "$SYSTEMD_DIR/milvus-backup.service"
    rm -f "$SYSTEMD_DIR/milvus-backup.timer"
    
    # Remove script
    rm -f "$INSTALL_DIR/milvus-backup.sh"
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Service uninstalled successfully"
    print_warning "Backup directory $BACKUP_DIR was not removed"
    print_warning "Log file $LOG_FILE was not removed"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --uninstall)
        check_root
        uninstall
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
