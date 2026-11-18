# Screenshots

Nachweise für [docs/loesung](../loesung/README.md).

| Datei | Inhalt | verwendet in |
|---|---|---|
| `ex01-ec2-instance.png` | EC2-Instanz `rafael-biztrips`, Status *Läuft* | EX-01 |
| `ex01-secrets.png` | Environment-Secrets `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY` | EX-01 |
| `ex01-workflow-run.png` | Workflow-Run grün, Zusammenfassung EC2-Deploy | EX-01 |
| `ex01-trips.png` | `GET /v1/trips` auf EC2 | EX-01 |
| `ex01-health.png` | `GET /actuator/health` auf EC2 (MariaDB `UP`) | EX-01 |
| `ex02-docker-job.png` | Job `Image -> Docker Hub` grün | EX-02 |
| `ex02-dockerhub.png` | Repository `schnebalius/biztrips-backend` auf Docker Hub | EX-02 |
| `ex03-ecr.png` | ECR-Repository mit SHA- und `latest`-Tags | EX-03 |
| `ex03-rds.png` | RDS `biztrips-backend-db` verfügbar | EX-03 |
| `ex03-ecs-cluster.png` | ECS-Cluster: 1 Service, 2 laufende Tasks | EX-03 |
| `ex03-target-group.png` | Target Group: 2 fehlerfreie Ziele | EX-03 |
| `ex03-change-before.png` / `ex03-change-after.png` | `/actuator/info` vor/nach einer Änderung | EX-03 |
| `ex04-validation.png` | Upload mit falschem Typ → `400` | EX-04 |
