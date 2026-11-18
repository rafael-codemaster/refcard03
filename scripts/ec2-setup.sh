#!/usr/bin/env bash
# EX-01 + EX-04: Einmalige Vorbereitung der EC2-Instanz (Ubuntu oder Amazon Linux).
# Auf der Instanz ausführen (per SSH oder EC2 Instance Connect):  bash ec2-setup.sh
set -euo pipefail

APP_DIR=/opt/businesstrips
UPLOAD_DIR=/var/lib/businesstrips/uploads
ENV_FILE=/etc/businesstrips.env
RUN_USER=$(whoami)

echo "==> Pakete installieren (Java 21, rsync, MariaDB)"
if command -v apt-get > /dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y openjdk-21-jre-headless rsync mariadb-server curl
elif command -v dnf > /dev/null; then
  sudo dnf install -y java-21-amazon-corretto-headless rsync
  sudo dnf install -y mariadb1011-server 2> /dev/null || sudo dnf install -y mariadb105-server
else
  echo "Nicht unterstütztes Betriebssystem (weder apt noch dnf gefunden)." >&2
  exit 1
fi

sudo systemctl enable --now mariadb

echo "==> Datenbank und eigenen DB-User anlegen"
if [ ! -f "$ENV_FILE" ]; then
  DB_PASSWORD=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
  sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS db_biztrips;
CREATE USER IF NOT EXISTS 'biztrips'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER 'biztrips'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON db_biztrips.* TO 'biztrips'@'localhost';
FLUSH PRIVILEGES;
SQL
  # Zugangsdaten nur hier auf dem Server (root-only), nicht im Repository
  sudo tee "$ENV_FILE" > /dev/null <<EOF
SPRING_PROFILES_ACTIVE=mariadb
SPRING_DATASOURCE_URL=jdbc:mariadb://localhost:3306/db_biztrips
SPRING_DATASOURCE_USERNAME=biztrips
SPRING_DATASOURCE_PASSWORD=${DB_PASSWORD}
APP_STORAGE_LOCATION=${UPLOAD_DIR}
EOF
  sudo chmod 600 "$ENV_FILE"
else
  echo "    $ENV_FILE existiert bereits – DB-User bleibt unverändert."
fi

echo "==> Verzeichnisse anlegen"
sudo mkdir -p "$APP_DIR" "$UPLOAD_DIR"
sudo chown -R "$RUN_USER":"$RUN_USER" "$APP_DIR" "$(dirname "$UPLOAD_DIR")"

echo "==> systemd-Service anlegen"
sudo tee /etc/systemd/system/businesstrips.service > /dev/null <<EOF
[Unit]
Description=SpringBoot BusinessTrips Backend
After=network.target mariadb.service
Requires=mariadb.service

[Service]
User=${RUN_USER}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${ENV_FILE}
EnvironmentFile=-${APP_DIR}/version.env
ExecStart=$(command -v java) -XX:MaxRAMPercentage=50 -jar ${APP_DIR}/app.jar
SuccessExitStatus=143
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable businesstrips.service

echo
echo "Fertig. Werte für das GitHub-Environment 'production':"
echo "  EC2_USER = ${RUN_USER}"
echo "  EC2_HOST = $(curl -s -m 2 http://169.254.169.254/latest/meta-data/public-hostname 2> /dev/null || echo '<Public IPv4 DNS aus der EC2-Konsole>')"
echo "Uploads (EX-04) liegen in ${UPLOAD_DIR} – ausserhalb von ${APP_DIR}, das der Deploy überschreibt."
