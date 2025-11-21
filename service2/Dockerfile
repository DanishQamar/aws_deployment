# --- Build Stage ---
# Use Maven from ECR Public to avoid Docker Hub rate limits
FROM public.ecr.aws/docker/library/maven:3.9-amazoncorretto-17 AS build

WORKDIR /app

# Copy the build file and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy the source code and build the application
COPY src ./src
RUN mvn package -DskipTests

# --- Run Stage ---
# Use Amazon Corretto 17 from ECR Public (No rate limits on AWS)
FROM public.ecr.aws/amazoncorretto/amazoncorretto:17

WORKDIR /app

# Copy the built JAR file from the build stage
COPY --from=build /app/target/*.jar app.jar

# Run the Java application
# (No port is exposed since this is a background worker)
CMD ["java", "-jar", "app.jar"]