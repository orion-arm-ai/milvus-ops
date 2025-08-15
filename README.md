# Milvus Backup Service

A systemd-based automated backup solution for Milvus databases using Docker. This service creates daily backups with configurable retention policies.

## Features

- **Daily automated backups** using systemd timers
- **Docker-based** - no need to install backup binaries
- **Configurable retention** (default: 3 days)
- **Comprehensive logging** with rotation
- **Security hardened** systemd service
- **Easy installation** with automated script

## Prerequisites

- Linux system with systemd
- Docker installed and running
- Milvus database accessible
- Root or sudo access for installation

## Quick Installation

```bash
# Clone the repository
git clone <repository-url>
cd milvus-backup

# Run the installation script
sudo ./install.sh
```

## Manual Installation

### 1. Create Backup Directory
```bash
sudo mkdir -p /data/backup
sudo chown root:root /data/backup
```

### 2. Install Backup Script
```bash
sudo cp bin/milvus_backup_script.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/milvus_backup_script.sh
```

### 3. Install Systemd Files
```bash
sudo cp systemd/milvus_backup.service /etc/systemd/system/
sudo cp systemd/milvus_backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
```

### 4. Enable and Start Service
```bash
sudo systemctl enable milvus_backup.timer
sudo systemctl start milvus_backup.timer
```

## Configuration

### Backup Script Configuration

Edit `/usr/local/bin/milvus_backup_script.sh` to modify:

```bash
# Backup location
BACKUP_DIR="/data/backup"

# Milvus connection
MILVUS_HOST="localhost"     # Change if Milvus is remote
MILVUS_PORT="19530"         # Default Milvus port

# Backup retention
RETENTION_DAYS=3            # Keep backups for 3 days

# Docker image
DOCKER_IMAGE="milvusdb/milvus-backup:latest"
```

### Timer Schedule Configuration

Edit `/etc/systemd/system/milvus_backup.timer` to change backup schedule:

```ini
# Current: Daily at 2:00 AM
OnCalendar=daily

# Alternatives:
# OnCalendar=*-*-* 02:00:00        # Daily at 2:00 AM
# OnCalendar=Mon *-*-* 02:00:00    # Weekly on Monday
# OnCalendar=*-*-01 02:00:00       # Monthly on 1st day
```

After changes, reload systemd:
```bash
sudo systemctl daemon-reload
sudo systemctl restart milvus_backup.timer
```

## Usage

### Check Timer Status
```bash
# View timer status
sudo systemctl status milvus_backup.timer

# List all timers
sudo systemctl list-timers

# View next scheduled run
sudo systemctl list-timers milvus_backup.timer
```

### Manual Backup
```bash
# Run backup immediately
sudo systemctl start milvus_backup.service

# Monitor real-time logs
sudo journalctl -u milvus_backup.service -f
```

### View Logs
```bash
# View service logs
sudo journalctl -u milvus_backup.service

# View backup script logs
sudo tail -f /var/log/milvus-backup.log

# View recent backup logs
sudo journalctl -u milvus_backup.service --since "1 day ago"
```

### Backup Management
```bash
# List backups
ls -la /data/backup/

# Check backup sizes
du -sh /data/backup/backup-*

# Manual cleanup (if needed)
find /data/backup -name "backup-*" -type d -mtime +3 -exec rm -rf {} \;
```

## Restore Process

To restore from a backup:

```bash
# List available backups
ls /data/backup/

# Restore using Docker
docker run --rm \
  -v /data/backup:/backup \
  -e MILVUS_ADDRESS="localhost:19530" \
  milvusdb/milvus-backup:latest \
  restore \
  --backup-name "backup-20240815-020001" \
  --backup-dir "/backup"
```

## File Structure

```
/usr/local/bin/milvus_backup_script.sh    # Backup script
/etc/systemd/system/milvus_backup.service # Systemd service
/etc/systemd/system/milvus_backup.timer   # Systemd timer
/data/backup/                            # Backup storage
/var/log/milvus-backup.log                # Backup logs
```

## Troubleshooting

### Timer Not Running
```bash
# Check timer status
sudo systemctl status milvus_backup.timer

# Enable if disabled
sudo systemctl enable milvus_backup.timer
sudo systemctl start milvus_backup.timer
```

### Backup Failures
```bash
# Check service logs
sudo journalctl -u milvus_backup.service

# Common issues:
# 1. Docker not running
sudo systemctl status docker

# 2. Milvus not accessible
telnet localhost 19530

# 3. Insufficient disk space
df -h /data/backup

# 4. Permission issues
ls -la /data/backup
```

### Docker Issues
```bash
# Test Docker access
sudo docker info

# Pull backup image manually
sudo docker pull milvusdb/milvus-backup:latest

# Test backup container
sudo docker run --rm milvusdb/milvus-backup:latest --help
```

### Log Rotation
The systemd service uses journal logging. To prevent log growth:

```bash
# Configure journal limits in /etc/systemd/journald.conf
SystemMaxUse=500M
SystemMaxFileSize=50M
```

## Security Considerations

- Service runs as root (required for Docker access)
- Limited file system access via systemd security settings
- Private temporary directory
- No new privileges allowed
- Read-only system protection where possible

## Customization

### Custom Backup Configuration

Create a backup configuration file:

```yaml
# /etc/milvus-backup.yaml
milvus:
  address: localhost:19530
  username: ""
  password: ""

backup:
  storageType: "local"
  rootPath: "/backup"
```

Update script to use config:
```bash
CONFIG_FILE="/etc/milvus-backup.yaml"
```

### Email Notifications

Add email notifications on backup failure by modifying the service:

```ini
# In milvus_backup.service
OnFailure=backup-failure-notify@%n.service
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

[Add your license here]

## Support

For issues and questions:
- Check the troubleshooting section
- Review systemd and Docker logs
- Create an issue in the repository
