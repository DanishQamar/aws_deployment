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
import java.util.List;
import java.util.UUID; // --- ADDED IMPORT ---

// --- IMPORTS FOR JPA/DATABASE ---
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Enumerated;
import jakarta.persistence.EnumType;
import java.time.LocalDateTime;

// --- ADDED IMPORTS FOR AUTO SCALING ---
import software.amazon.awssdk.services.applicationautoscaling.ApplicationAutoScalingClient;
import software.amazon.awssdk.services.applicationautoscaling.model.RegisterScalableTargetRequest;
import software.amazon.awssdk.services.applicationautoscaling.model.ScalableDimension;
import software.amazon.awssdk.services.applicationautoscaling.model.ServiceNamespace;
import software.amazon.awssdk.services.applicationautoscaling.model.ApplicationAutoScalingException;
// --- END ADDED IMPORTS ---


@SpringBootApplication
public class Service1Application {
    public static void main(String[] args) {
        SpringApplication.run(Service1Application.class, args);
    }
}

// --- vvv JOB STATUS ENUM vvv ---
enum JobStatus {
    SUBMITTED,
    IN_PROGRESS,
    COMPLETED,
    FAILED
}
// --- ^^^ JOB STATUS ENUM ^^^ ---


// --- vvv JOB ENTITY vvv ---
@Entity
class Job {

    @Id
    private String id; 

    private String description;
    
    @Enumerated(EnumType.STRING) 
    private JobStatus status;
    
    private LocalDateTime submittedAt;
    private LocalDateTime updatedAt;

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
@Repository
interface JobRepository extends JpaRepository<Job, String> {
}
// --- ^^^ JOB REPOSITORY ^^^ ---


@RestController
class JobController {
    private static final Logger logger = LoggerFactory.getLogger(JobController.class);

    private final SqsTemplate sqsTemplate;
    private final JobRepository jobRepository; 

    @Value("${SQS_QUEUE_URL}")
    private String queueUrl;

    public JobController(SqsTemplate sqsTemplate, JobRepository jobRepository) {
        this.sqsTemplate = sqsTemplate;
        this.jobRepository = jobRepository;
    }

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("OK");
    }

    @PostMapping("/submit-job")
    public ResponseEntity<?> submitJob(@RequestBody JobRequest jobRequest) {
        // --- FIX: RACE CONDITION ---
        // 1. Generate ID and Save to DB FIRST.
        // This ensures the job exists before Service 2 tries to process it.
        String jobId = UUID.randomUUID().toString();
        LocalDateTime now = LocalDateTime.now();
        
        Job newJob = new Job(
            jobId, 
            jobRequest.getDescription(), 
            JobStatus.SUBMITTED, 
            now, 
            now
        );
        jobRepository.save(newJob); 
        
        // 2. Send to SQS with the generated ID in a header
        sqsTemplate.send(to -> to
            .queue(queueUrl)
            .payload(jobRequest.getDescription())
            .header("job-id", jobId)
        );
        
        logger.info("Successfully submitted job to DB and SQS. Job ID: {}", jobId);
        
        return new ResponseEntity<>(newJob, HttpStatus.CREATED);
    }
    
    @GetMapping("/jobs")
    public ResponseEntity<?> getJobs() {
        List<Job> jobs = jobRepository.findAll();
        return ResponseEntity.ok(jobs);
    }
}

// --- NEW CONTROLLER FOR SCALING ---
@RestController
class ScalingController {
    private static final Logger logger = LoggerFactory.getLogger(ScalingController.class);
    
    private final ApplicationAutoScalingClient autoScalingClient;

    @Value("${ECS_CLUSTER_NAME:my-ecs-project-cluster}")
    private String clusterName;

    // We assume the worker service is named "service2" as defined in Terraform
    private final String serviceName = "service2"; 

    public ScalingController() {
        this.autoScalingClient = ApplicationAutoScalingClient.create();
    }

    @PostMapping("/update-scaling")
    public ResponseEntity<?> updateScaling(@RequestBody ScalingRequest request) {
        logger.info("Received request to update scaling: min={}, max={}", request.getMinCapacity(), request.getMaxCapacity());

        // The resource ID format for ECS Service Auto Scaling is: service/clusterName/serviceName
        String resourceId = String.format("service/%s/%s", clusterName, serviceName);

        try {
            RegisterScalableTargetRequest targetRequest = RegisterScalableTargetRequest.builder()
                .serviceNamespace(ServiceNamespace.ECS)
                .scalableDimension(ScalableDimension.ECS_SERVICE_DESIRED_COUNT)
                .resourceId(resourceId)
                .minCapacity(request.getMinCapacity())
                .maxCapacity(request.getMaxCapacity())
                .build();

            autoScalingClient.registerScalableTarget(targetRequest);
            
            logger.info("Successfully updated scaling target for {}", resourceId);
            return ResponseEntity.ok("Scaling updated successfully");
            
        } catch (ApplicationAutoScalingException e) {
            logger.error("Failed to update auto scaling", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("AWS Error: " + e.awsErrorDetails().errorMessage());
        }
    }
}

class ScalingRequest {
    private int minCapacity;
    private int maxCapacity;

    public int getMinCapacity() { return minCapacity; }
    public void setMinCapacity(int minCapacity) { this.minCapacity = minCapacity; }
    public int getMaxCapacity() { return maxCapacity; }
    public void setMaxCapacity(int maxCapacity) { this.maxCapacity = maxCapacity; }
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