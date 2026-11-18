# EX-04 (RefCard 04) – Lokaler Datei-Storage für Mitarbeiterfotos

**Ziel:** Fotos zu Mitarbeitenden hoch- und herunterladen, sicher im Dateisystem ablegen und so konfigurieren, dass sie Container-Neustarts und EC2-Redeploys überleben.

**Dateien:**
[`FileStorageService`](../../src/main/java/ch/bbw/trips/storage/FileStorageService.java),
[`StorageExceptionAdvice`](../../src/main/java/ch/bbw/trips/storage/StorageExceptionAdvice.java),
[`EmployeeController`](../../src/main/java/ch/bbw/trips/repo/EmployeeController.java),
[`Employee`](../../src/main/java/ch/bbw/trips/repo/Employee.java) (`profilePictureFilename`),
[`application.properties`](../../src/main/resources/application.properties),
Tests: [`FileStorageServiceTest`](../../src/test/java/ch/bbw/trips/storage/FileStorageServiceTest.java), [`EmployeePhotoTest`](../../src/test/java/ch/bbw/trips/repo/EmployeePhotoTest.java)

## API

| Methode | Pfad | Antwort |
|---|---|---|
| `POST` | `/v1/employees/{id}/photo` (multipart, Feld `file`) | `200`; `400` bei leerer/ungültiger Datei, `413` über 5 MB, `404` unbekannte ID |
| `GET` | `/v1/employees/{id}/photo` | Bild mit passendem Content-Type (aus der Endung), `404` ohne Foto |
| `DELETE` | `/v1/employees/{id}/photo` | `204` |

## Sicherheit im `FileStorageService`

| Massnahme | Schützt vor |
|---|---|
| Whitelist `image/png`, `image/jpeg`, `image/webp` + Prüfung der **Magic Bytes** | Ablage beliebiger Dateien (z. B. `.jsp`, `.php`), gefälschter Content-Type |
| Dateiname = `UUID` + Endung **aus dem Content-Type** | Namenskollisionen, Original-Dateiname als Angriffsvektor (`../../etc/passwd`, `shell.jsp`) |
| `normalize()` + Prüfung „Parent == root“ bei store/load/delete | Path Traversal |
| `max-file-size=5MB` | Speicher-/DoS-Missbrauch |
| Alte Datei wird beim Ersetzen gelöscht | verwaiste Dateien |
| Pfad über `app.storage.location` / `APP_STORAGE_LOCATION` | hartcodierte Pfade |

In der DB steht nur der **Dateiname**, die Bilddaten liegen im Dateisystem (später: S3-Objektschlüssel).

## Vorgehen / Test

```bash
./mvnw spring-boot:run
curl -F "file=@foto.jpg;type=image/jpeg" http://localhost:8080/v1/employees/1/photo
curl -o download.jpg http://localhost:8080/v1/employees/1/photo
ls uploads/
```

**Docker-Volume (Persistenz):** Das `Dockerfile` deklariert `VOLUME ["/app/uploads"]`, Compose mountet das benannte Volume `biztrips-uploads`:

```bash
docker compose -f docker/docker-compose.yml --profile app up -d --build
curl -F "file=@foto.jpg;type=image/jpeg" http://localhost:8080/v1/employees/1/photo
docker compose -f docker/docker-compose.yml --profile app rm -sf biztrips-backend   # Container weg
docker compose -f docker/docker-compose.yml --profile app up -d                     # neuer Container
curl -o nachher.jpg http://localhost:8080/v1/employees/1/photo                       # Foto noch da
```

**EC2:** `ec2-setup.sh` setzt `APP_STORAGE_LOCATION=/var/lib/businesstrips/uploads`. Das liegt bewusst **ausserhalb** von `/opt/businesstrips`, wohin der Deploy die `.jar` schreibt. Ein Push auf `main` (Redeploy) lässt die Fotos unberührt.

## Nachweise

![Upload und Download per curl](../images/ex04-upload-curl.png)
![Foto im Browser](../images/ex04-browser-photo.png)
![Foto überlebt Container-Neustart (Volume)](../images/ex04-volume.png)
![Uploads auf EC2 nach Redeploy noch vorhanden](../images/ex04-ec2-uploads.png)

## Warum das nicht 1:1 nach ECS/Fargate passt

Auf ECS laufen **2 Tasks** mit je eigenem, flüchtigem Dateisystem. Task A speichert ein Foto, aber der ALB schickt den Download evtl. an Task B, der es nicht hat. Bei jedem Rolling Deployment und jedem Self-Healing startet ein Task leer. → Es braucht einen gemeinsamen, von Tasks unabhängigen Speicher: **S3 (RefCard 05)**. `store()`/`load()` bleiben als Schnittstelle gleich, nur die Implementierung wechselt auf `S3Client.putObject/getObject`.

## Reflexion

1. **Warum nur der Dateiname in der DB?** Grosse BLOBs blähen DB, Backups und Abfragen auf und belasten den Connection-Pool. Dateien lassen sich im Dateisystem bzw. S3 billiger speichern und direkt ausliefern.
2. **Was leistet `target.getParent().equals(root)`?** Die Typ-Prüfung schaut nur auf den Inhalt, nicht auf den Pfad. Die Parent-Prüfung verhindert, dass ein manipulierter Name wie `../../etc/passwd` beim Laden oder Löschen ausserhalb des Upload-Ordners landet (Path Traversal).
3. **Warum überlebt ein Volume `docker rm`, aber keinen Hostwechsel?** Das benannte Volume ist ein Verzeichnis, das Docker auf dem Host unabhängig vom Container verwaltet. Es existiert aber nur auf genau diesem Host. Ein anderer Host oder ein Fargate-Task hat es nicht.
4. **Was wäre, wenn `uploads` neben `app.jar` läge?** Solange nur `app.jar` per rsync überschrieben wird, ginge es knapp gut. Sobald der Deploy das Verzeichnis aber neu aufsetzt (z. B. `rsync --delete`, Neuinstallation, Rollback), wären alle Fotos weg. Code und Daten gehören getrennt.
5. **Löst `desired-count 1` das Problem?** Nur teilweise. Bei jedem Deploy und bei Self-Healing startet trotzdem ein neuer, leerer Task, und die Uploads sind weg. Zudem gehen Redundanz und Zero-Downtime-Deploy verloren, die EX-03 als Vorteil gegenüber EX-01 zeigt.
6. **Was ändert sich mit S3?** Der Konstruktor (Bucket/S3Client statt Pfad) sowie die Implementierung von `store`, `load` und `delete`. Die Signaturen `String store(MultipartFile)` und `Resource load(String)` können gleich bleiben, der Controller ändert sich nicht.
