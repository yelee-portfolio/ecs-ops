FROM eclipse-temurin:21-jdk AS build

WORKDIR /app
COPY . .

RUN chmod +x mvnw
RUN ./mvnw clean package -DskipTests

FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=build /app/target/app-0.0.1-SNAPSHOT.jar app.jar

USER 1001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]