#!/bin/bash
# Installs tlsrpt-collectd and tlsrpt-reportd as systemd services.
# Checks out the repo to /opt/tlsrpt-reporter and creates a venv inside.
# Run as root.
set -euo pipefail

REPO_URL=https://github.com/sys4/tlsrpt-reporter.git
INSTALL_DIR=/opt/tlsrpt-reporter
VENV_DIR=$INSTALL_DIR/venv
TLSRPT_USER=tlsrpt
TLSRPT_GROUP=tlsrpt
CONFIG_DIR=/etc/tlsrpt-reporter
SYSTEMD_DIR=/etc/systemd/system
SCRIPT_DIR=$(dirname "$(realpath "$0")")

if [[ $EUID -ne 0 ]]; then
    echo "error: must be run as root" >&2
    exit 1
fi

# Create system group and user
if ! getent group "$TLSRPT_GROUP" > /dev/null 2>&1; then
    groupadd --system "$TLSRPT_GROUP"
    echo "Created group $TLSRPT_GROUP"
fi
if ! getent passwd "$TLSRPT_USER" > /dev/null 2>&1; then
    useradd --system \
        --gid "$TLSRPT_GROUP" \
        --no-create-home \
        --home-dir /var/lib/tlsrpt-reporter \
        --shell /usr/sbin/nologin \
        "$TLSRPT_USER"
    echo "Created user $TLSRPT_USER"
fi

# Checkout or update the repository
if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    git clone "$REPO_URL" "$INSTALL_DIR"
    echo "Cloned repository to $INSTALL_DIR"
else
    git -C "$INSTALL_DIR" pull --ff-only
    echo "Updated repository in $INSTALL_DIR"
fi

# Create venv and install the package
if [[ ! -d "$VENV_DIR" ]]; then
    python3 -m venv "$VENV_DIR"
    echo "Created venv at $VENV_DIR"
fi
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet "$INSTALL_DIR"
echo "Installed tlsrpt-reporter into venv"

# Install config (only if not already present)
install -d -m 0755 "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/tlsrpt.cfg" ]]; then
    install -m 0640 -o root -g "$TLSRPT_GROUP" \
        "$SCRIPT_DIR/tlsrpt.cfg" "$CONFIG_DIR/tlsrpt.cfg"
    echo "Installed config to $CONFIG_DIR/tlsrpt.cfg"
    echo "  --> Review it before starting the services."
else
    echo "Config $CONFIG_DIR/tlsrpt.cfg already exists, skipping."
fi

# Install systemd unit files
install -m 0644 -o root -g root \
    "$SCRIPT_DIR/tlsrpt-collectd.service" "$SYSTEMD_DIR/"
install -m 0644 -o root -g root \
    "$SCRIPT_DIR/tlsrpt-reportd.service" "$SYSTEMD_DIR/"
echo "Installed unit files to $SYSTEMD_DIR/"

systemctl daemon-reload
systemctl enable tlsrpt-collectd.service tlsrpt-reportd.service
echo "Services enabled."
echo ""
echo "Start with:"
echo "  systemctl start tlsrpt-collectd tlsrpt-reportd"
echo ""
echo "Check status with:"
echo "  systemctl status tlsrpt-collectd tlsrpt-reportd"
echo "  journalctl -u tlsrpt-collectd -u tlsrpt-reportd -f"
