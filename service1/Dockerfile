# --- Build Stage ---
# Use an OpenJDK 17 image with Maven for building
FROM maven:3.9.6-eclipse-temurin-17-focal AS build

WORKDIR /app

# Copy the build file and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy the source code
COPY src ./src

# --- REMOVE THE BROKEN LINE ---
# (The "COPY ../index.html ..." line that was here is GONE)

# Build the application
RUN mvn package -DskipTests

# --- Run Stage ---
# Use a slim OpenJDK 17 runtime image
FROM eclipse-temurin:17-jre-focal

WORKDIR /app

# Copy the built JAR file from the build stage
COPY --from=build /app/target/*.jar app.jar

# Expose port 8080, which Spring Boot uses by default
EXPOSE 8080

# Run the Java application
CMD ["java", "-jar", "app.jar"]