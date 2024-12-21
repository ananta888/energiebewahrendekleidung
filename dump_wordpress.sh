#!/bin/bash

# Sicherstellen, dass das Skript mit root-Rechten ausgeführt wird
if [ "$(id -u)" -ne 0 ]; then
  echo "Bitte führen Sie das Skript mit root-Rechten aus."
  exit 1
fi

# Konfigurationsvariablen direkt aus docker-compose.yml 
BACKUP_DIR="/backup"  # Verzeichnis, in dem die Backups gespeichert werden
WEB_ROOT="./wordpress_data"  # Pfad zum Web-Verzeichnis der WordPress-Installation
DB_CONTAINER_NAME="wordpress_db"  # Name des Datenbank-Containers
DB_USER="wordpress"  # Direkt aus docker-compose.yml
DB_PASSWORD="wordpress"  # Direkt aus docker-compose.yml
DB_NAME="wordpress"  # Direkt aus docker-compose.yml

# Überprüfen, ob das Backup-Verzeichnis existiert, ansonsten erstellen
if [ ! -d "$BACKUP_DIR" ]; then
  mkdir -p "$BACKUP_DIR"
fi

# Temporäres Verzeichnis für das Backup erstellen
temp_backup_dir=$(mktemp -d)
echo "Temporäres Backup-Verzeichnis: $temp_backup_dir"

# 1. Datenbank-Dump erstellen
echo "Erstelle Datenbank-Dump aus dem Docker-Container '$DB_CONTAINER_NAME'..."
docker exec $DB_CONTAINER_NAME sh -c "exec mysqldump --databases $DB_NAME -u$DB_USER -p$DB_PASSWORD --no-tablespaces --skip-lock-tables --add-drop-database --routines --triggers" > "$temp_backup_dir/db.sql"
if [ $? -ne 0 ]; then
  echo "Fehler beim Erstellen des Datenbank-Dumps."
  exit 1
fi

# 2. Dateien der WordPress-Installation kopieren
echo "Kopiere Web-Dateien..."
rsync -a --exclude="$BACKUP_DIR" --exclude="*.mp4" --exclude="*.mkv" --exclude="*.avi" --exclude="*.mov" "$WEB_ROOT/" "$temp_backup_dir/web/"
if [ $? -ne 0 ]; then
  echo "Fehler beim Kopieren der Web-Dateien."
  exit 1
fi

# 3. Backup in ein tar.bz2-Archiv packen
BACKUP_FILE_NAME="wordpress_backup_$(date +%Y-%m-%d_%H-%M-%S).tar.bz2"
echo "Packe Backup-Dateien..."
tar --exclude="*.mp4" --exclude="*.mkv" --exclude="*.avi" --exclude="*.mov" -cjf "$BACKUP_DIR/$BACKUP_FILE_NAME" -C "$temp_backup_dir" .
if [ $? -ne 0 ]; then
  echo "Fehler beim Packen des Archivs."
  exit 1
fi

# 4. Temporäres Verzeichnis löschen
echo "Bereinige temporäres Verzeichnis..."
rm -rf "$temp_backup_dir"

# 5. Erfolgsmeldung
echo "Backup abgeschlossen! Gespeichert unter: $BACKUP_DIR/$BACKUP_FILE_NAME"

# Anweisungen für die Wiederherstellung anzeigen
echo "Um das Backup wiederherzustellen, führen Sie folgende Befehle aus:"
echo "cd / && tar -xjf $BACKUP_DIR/$BACKUP_FILE_NAME"
echo "Für die Datenbank-Wiederherstellung führen Sie folgendes aus:"
echo "docker exec -i $DB_CONTAINER_NAME mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME < /var/www/html/db.sql"

