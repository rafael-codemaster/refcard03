# RefCard 03/04 – BusinessTrips Backend (Spring Boot + MariaDB)

[![CI/CD Backend](https://github.com/rafael-codemaster/refcard03/actions/workflows/deploy.yml/badge.svg)](https://github.com/rafael-codemaster/refcard03/actions/workflows/deploy.yml)

REST-Backend der BusinessTrips-App (Mitarbeitende, Business Trips, Flüge, Meetings, Mitarbeiterfotos) mit CI/CD über GitHub Actions nach **AWS EC2**, **Docker Hub** und **AWS ECS (Fargate) + RDS**.
Ausgangspunkt: [`bbwlc/RefCard-03-be-SpringBootBusinessTrips@v1-start`](https://github.com/bbwlc/RefCard-03-be-SpringBootBusinessTrips/tree/v1-start).

**➡ Dokumentation der Lösung: [docs/loesung/README.md](docs/loesung/README.md)**

| Übung | Ergebnis |
|---|---|
| [EX-01 – EC2](docs/loesung/EX-01-EC2.md) | Pipeline `test → build → deploy`, jar per rsync + systemd, Health-Check nach Deploy |
| [EX-02 – Docker Hub](docs/loesung/EX-02-DockerHub.md) | Multi-Stage-`Dockerfile`, Tags `prod01`/`latest`/SHA/SemVer, Push nur von `main` |
| [EX-03 – ECS](docs/loesung/EX-03-ECS.md) | ECR → ECS Fargate (2 Tasks) hinter ALB, MariaDB auf RDS, Rolling Deployment + Smoke-Test |
| [EX-04 – Storage](docs/loesung/EX-04-Storage.md) | Foto-Upload/-Download, sichere Ablage, Docker-Volume, persistente Uploads auf EC2 |

## Tech-Stack

Java 21, Spring Boot 4.1 (Web, Data JPA, Actuator), MariaDB / H2, Maven Wrapper, Docker, GitHub Actions, AWS (EC2, ECR, ECS Fargate, RDS, ALB, Secrets Manager).

## Schnellstart

```bash
./mvnw spring-boot:run                                    # H2 in-memory, Port 8080
./mvnw test                                               # Tests

docker compose -f docker/docker-compose.yml up -d         # nur MariaDB + phpMyAdmin (:8082)
./mvnw spring-boot:run -Dspring-boot.run.profiles=mariadb

docker compose -f docker/docker-compose.yml --profile app up -d --build   # DB + Backend als Container
```

## API (Basis `/v1`)

| Endpoint | Beschreibung |
|---|---|
| `GET/POST /v1/trips`, `GET/DELETE /v1/trips/{id}` | Business Trips |
| `GET/POST/DELETE /v1/employees`, `GET/PUT/DELETE /v1/employees/{id}` | Mitarbeitende |
| `POST/GET/DELETE /v1/employees/{id}/photo` | Mitarbeiterfoto (EX-04, PNG/JPEG/WebP, max. 5 MB) |
| `/v1/flights`, `/v1/meetings` | Flüge, Meetings (CRUD) |
| `POST /v1/signIn` | Login (Demo: `joe` / `1234`) |
| `GET /actuator/health`, `GET /actuator/info` | Health inkl. DB, laufende Version (Commit-SHA) |

## Projektstruktur

```
.github/workflows/deploy.yml   CI/CD: test → build → deploy (EC2) → docker (Hub) → deploy-ecs (ECR/ECS)
Dockerfile, .dockerignore      Multi-Stage-Image (JDK-Build → JRE-alpine, non-root, Healthcheck)
task-definition.json           ECS-Task-Definition mit Platzhaltern (werden in der Pipeline ersetzt)
scripts/                       ec2-setup.sh, aws-ecs-setup.sh, aws-ecs-teardown.sh
docker/docker-compose.yml      MariaDB + phpMyAdmin (+ Backend mit --profile app)
src/main/java/ch/bbw/trips/    Applikation, storage/ = EX-04
docs/loesung/                  Dokumentation der Übungen mit Screenshots
```
