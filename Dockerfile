# --- Stage 1: Build ---
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw -B -q dependency:go-offline

COPY src ./src
RUN ./mvnw -B -q clean package -DskipTests

# --- Stage 2: Runtime ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S app && adduser -S app -G app \
    && mkdir -p /app/uploads \
    && chown -R app:app /app

COPY --from=build --chown=app:app /app/target/*.jar app.jar

USER app

# EX-04: Upload-Verzeichnis als Volume, damit Fotos nicht im flüchtigen Container-Layer landen
ENV APP_STORAGE_LOCATION=/app/uploads
VOLUME ["/app/uploads"]

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health > /dev/null || exit 1

# Nur Metadaten (über /actuator/info sichtbar), keine Konfiguration
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
