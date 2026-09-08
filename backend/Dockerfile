# Multi-stage build for local Docker and Render.
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B -DskipTests package

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
RUN addgroup -S app && adduser -S -G app app
USER app
EXPOSE 10000
ENTRYPOINT ["java", "-jar", "app.jar"]
