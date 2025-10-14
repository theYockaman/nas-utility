#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo "Creating service directory..."

sudo mkdir -p "/opt/cron_service"
sudo mkdir -p "/srv/programming/config"

sudo tee "/opt/cron_service/cron_manager.py" > /dev/null << 'EOF'
#!/bin/bash



echo "Creating service directory..."

sudo mkdir -p "/opt/cron_service"

sudo mkdir -p "/srv/programming/config"

sudo tee "/opt/cron_service/cron_manager.py" > /dev/null << 'EOF'

#!/usr/bin/env python3
import time
import subprocess
import logging
import json
from datetime import datetime
from pathlib import Path

JOBS_FILE = "/srv/programming/config/cron-manager.json"
last_run_times = {}

logging.basicConfig(filename='/var/log/cron_service.log', level=logging.INFO)

def load_jobs():
    try:
        with open(JOBS_FILE, "r") as f:
            return json.load(f)
    except Exception as e:
        logging.error(f"Failed to load jobs: {e}")
        return []

def should_run(job, now):
    interval = job.get("interval")
    name = job.get("name")
    if interval is None or name is None:
        return False
    last_run = last_run_times.get(name)
    if last_run is None or (now - last_run).total_seconds() >= interval * 60:
        return True
    return False

def run_job(job):
    name = job.get("name", "unknown")
    script = job.get("script")
    if not script or not Path(script).is_file():
        logging.warning(f"Script not found for {name}")
        return
    logging.info(f"Running {name} at {datetime.now()}")
    try:
        subprocess.run(["/usr/bin/python3", script], check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Error running {name}: {e}")

def main():
    while True:
        now = datetime.now()
        jobs = load_jobs()
        for job in jobs:
            if should_run(job, now):
                run_job(job)
                last_run_times[job["name"]] = now
        time.sleep(30)

if __name__ == "__main__":
    main()

EOF

sudo chmod +x "/opt/cron_service/cron_manager.py"



fi




echo "Creating systemd service file..."
sudo chmod +x "/opt/cron_service/cron_manager.py"

echo "Creating systemd service file..."
sudo tee "/etc/systemd/system/cron-manager.service" > /dev/null <<EOF
[Unit]
Description=Dynamic Cron Manager
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/cron_service/cron_manager.py
Restart=on-failure
KillMode=control-group
register "/srv/programming/config/cron-manager.json"

echo "Reloading systemd daemon..."

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "Enabling and starting the service..."
sudo systemctl enable cron-manager.service
sudo systemctl start cron-manager.service

echo "Service installed and running."

# --- Register important cron-manager paths for backup ---
BACKUP_LIST="/etc/backup_dirs.list"
register() {
    local path="$1"
    sudo mkdir -p "$(dirname "$BACKUP_LIST")"
    sudo touch "$BACKUP_LIST"
    if ! sudo grep -Fxq "$path" "$BACKUP_LIST"; then
        echo "$path" | sudo tee -a "$BACKUP_LIST" >/dev/null
    fi
}

# Paths to register
register "/opt/cron_service"
register "/etc/systemd/system/cron-manager.service"
register "/var/log/cron_service.log"
# Jobs file referenced by the script
register "/srv/programming/variables/pythonCronJobs.json"
