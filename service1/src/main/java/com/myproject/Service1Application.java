package com.myproject;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import org.springframework.stereotype.Controller;
import org.springframework.http.ResponseEntity;
import io.awspring.cloud.sqs.operations.SqsTemplate;
import org.springframework.beans.factory.annotation.Value;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import java.util.Map;
import java.util.List; // <-- ADDED

// --- ADDED IMPORTS FOR JPA/DATABASE ---
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Enumerated;
import jakarta.persistence.EnumType;
import java.time.LocalDateTime;
// --- END OF ADDED IMPORTS ---


@SpringBootApplication
public class Service1Application {
    public static void main(String[] args) {
        SpringApplication.run(Service1Application.class, args);
    }
}

// --- vvv JOB STATUS ENUM vvv ---
// This enum defines the possible states of a job
enum JobStatus {
    SUBMITTED,
    IN_PROGRESS,
    COMPLETED,
    FAILED
}
// --- ^^^ JOB STATUS ENUM ^^^ ---


// --- vvv JOB ENTITY vvv ---
// This class represents the "jobs" table in your PostgreSQL database.
// Spring Boot (Hibernate) will automatically create/update this table
// because of `spring.jpa.hibernate.ddl-auto=update` in your properties.
@Entity
class Job {

    @Id
    private String id; // We will use the SQS Message ID as the Job ID

    private String description;
    
    @Enumerated(EnumType.STRING) // Stores the enum as "SUBMITTED" instead of 0, 1, 2...
    private JobStatus status;
    
    private LocalDateTime submittedAt;
    private LocalDateTime updatedAt;

    // JPA needs a no-arg constructor
    public Job() {}

    public Job(String id, String description, JobStatus status, LocalDateTime submittedAt, LocalDateTime updatedAt) {
        this.id = id;
        this.description = description;
        this.status = status;
        this.submittedAt = submittedAt;
        this.updatedAt = updatedAt;
    }

    // --- Getters and Setters ---
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getDescription() { return description; }
    public void setDescription(String d) { this.description = d; }
    public JobStatus getStatus() { return status; }
    public void setStatus(JobStatus s) { this.status = s; }
    public LocalDateTime getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(LocalDateTime s) { this.submittedAt = s; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime u) { this.updatedAt = u; }
}
// --- ^^^ JOB ENTITY ^^^ ---


// --- vvv JOB REPOSITORY vvv ---
// This interface is all Spring needs to create a fully functional
// service for talking to the "Job" table.
@Repository
interface JobRepository extends JpaRepository<Job, String> {
    // You can add custom finders here later, e.g.:
    // List<Job> findByStatus(JobStatus status);
}
// --- ^^^ JOB REPOSITORY ^^^ ---


@RestController
class JobController {
    private static final Logger logger = LoggerFactory.getLogger(JobController.class);

    private final SqsTemplate sqsTemplate;
    private final JobRepository jobRepository; // <-- INJECT THE REPOSITORY

    @Value("${SQS_QUEUE_URL}")
    private String queueUrl;

    // --- UPDATED CONSTRUCTOR ---
    public JobController(SqsTemplate sqsTemplate, JobRepository jobRepository) {
        this.sqsTemplate = sqsTemplate;
        this.jobRepository = jobRepository;
    }

    // --- NEW HEALTH CHECK ENDPOINT ---
    // This endpoint returns 200 OK without checking the database.
    // This ensures the Load Balancer sees the app as "Healthy" as soon as Java starts.
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("OK");
    }
    // --- END NEW HEALTH CHECK ---

    @PostMapping("/submit-job")
    public ResponseEntity<?> submitJob(@RequestBody JobRequest jobRequest) {
        // 1. Send to SQS
        var response = sqsTemplate.send(queueUrl, jobRequest.getDescription());
        String messageId = response.messageId().toString();
        
        // 2. Log to database
        // This is the new feature you requested:
        LocalDateTime now = LocalDateTime.now();
        Job newJob = new Job(
            messageId, 
            jobRequest.getDescription(), 
            JobStatus.SUBMITTED, // Set initial status
            now, 
            now
        );
        jobRepository.save(newJob); // <-- SAVE TO POSTGRES
        
        logger.info("Successfully submitted job to SQS and DB. Message ID: {}", messageId);
        
        // Return the newly created Job object as JSON
        return new ResponseEntity<>(newJob, HttpStatus.CREATED);
    }
    
    @GetMapping("/jobs")
    public ResponseEntity<?> getJobs() {
        // 3. Fetch jobs from database
        // This is the new feature: list all jobs from Postgres
        List<Job> jobs = jobRepository.findAll();
        return ResponseEntity.ok(jobs);
    }
}

class JobRequest {
    private String description;
    public String getDescription() { return description; }
    public void setDescription(String d) { this.description = d; }
}

@RestControllerAdvice
class GlobalExceptionHandler {
    private static final Logger logger = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(Exception.class)
    public ResponseEntity<?> handleGlobalException(Exception ex) {
        logger.error("Unhandled exception occurred: ", ex);
        Map<String, String> errorResponse = Map.of(
            "error", "An internal server error occurred.",
            "message", ex.getMessage()
        );
        return new ResponseEntity<>(errorResponse, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}