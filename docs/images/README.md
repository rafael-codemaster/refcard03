# Screenshots

Ablage der Nachweise für [docs/loesung](../loesung/README.md). Auf jedem Screenshot sollte die eigene Lösung erkennbar sein (GitHub-User `rafael-codemaster`, eigener Docker-Hub-User, eigene AWS-Account-ID/Ressourcen, Commit-SHA).

| Datei | Inhalt |
|---|---|
| `ex01-workflow-run.png` | Actions-Run mit grünen Jobs `test → build → deploy` |
| `ex01-secrets.png` | Environment `production` mit `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY` |
| `ex01-ec2-instance.png` | EC2-Konsole, Instanz `running` |
| `ex01-curl-health.png` | Browser/curl: `http://<EC2>:8080/actuator/health` und `/v1/trips` |
| `ex01-commits.png` | Commit-Historie des Repos |
| `ex02-docker-build-local.png` | `docker images` mit Tags `prod01`, `latest`, SHA |
| `ex02-container-local.png` | `docker run` + `curl localhost:8080/v1/trips` |
| `ex02-dockerhub-tags.png` | Docker Hub → `biztrips-backend` → Tags |
| `ex02-docker-job.png` | Job `Image -> Docker Hub` grün |
| `ex03-ecr.png` | ECR-Repository mit SHA- und `latest`-Tag |
| `ex03-rds.png` | RDS-Instanz `biztrips-backend-db` *Available* |
| `ex03-ecs-service.png` | ECS-Service, 2/2 Tasks running |
| `ex03-target-group.png` | Target Group, 2 Targets *healthy* |
| `ex03-workflow-ecs.png` | Job `deploy-ecs` grün inkl. Zusammenfassung |
| `ex03-change-before.png` / `ex03-change-after.png` | `http://<ALB>/actuator/info` vor/nach einer Änderung |
| `ex04-upload-curl.png` | `curl -F file=@…` Upload + Download |
| `ex04-browser-photo.png` | `http://<host>/v1/employees/1/photo` im Browser |
| `ex04-volume.png` | Container entfernt + neu gestartet, Foto noch abrufbar |
| `ex04-ec2-uploads.png` | `ls /var/lib/businesstrips/uploads` auf EC2 nach einem Redeploy |
