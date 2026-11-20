FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src src
RUN mvn -B -q -DskipTests package

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S -g 10001 radar && adduser -S -u 10001 -G radar radar
WORKDIR /app
COPY --from=build --chown=radar:radar /build/target/radar-api-1.1.1.jar app.jar
USER radar
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
