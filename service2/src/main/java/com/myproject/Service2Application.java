package com.myproject;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import io.awspring.cloud.sqs.annotation.SqsListener;
import org.springframework.messaging.handler.annotation.Header; // --- ADDED IMPORT ---
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Enumerated;
import jakarta.persistence.EnumType;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Random;
import org.springframework.stereotype.Component;

@SpringBootApplication
public class Service2Application {
    public static void main(String[] args) {
        SpringApplication.run(Service2Application.class, args);
    }
}

// --- vvv JOB STATUS ENUM vvv ---
enum JobStatus {
    SUBMITTED,
    IN_PROGRESS,
    COMPLETED,
    FAILED
}

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

// --- vvv JOB REPOSITORY vvv ---
@Repository
interface JobRepository extends JpaRepository<Job, String> {}

@Component
class JobWorker {
    private static final Logger logger = LoggerFactory.getLogger(JobWorker.class);
    
    private final JobRepository jobRepository;
    private final Random random = new Random();

    public JobWorker(JobRepository jobRepository) {
        this.jobRepository = jobRepository;
    }

    // The SQS queue name is read from application.properties
    @SqsListener("${SQS_QUEUE_NAME}") 
    // --- FIX: Use the custom "job-id" header ---
    // We now send the UUID as a custom header from Service 1.
    public void processMessage(String messageBody, @Header("job-id") String jobId) {
        logger.info("Received job {} with body: {}", jobId, messageBody);

        // --- Find the job in the database ---
        Optional<Job> jobOpt = jobRepository.findById(jobId);
        if (jobOpt.isEmpty()) {
            // If this still happens (it shouldn't), we can throw exception to retry, 
            // but with the new "Save First" logic, this should be fixed.
            logger.error("Job {} not found in database! Discarding message.", jobId);
            return; 
        }
        Job job = jobOpt.get();

        try {
            // 1. Update job status to IN_PROGRESS
            job.setStatus(JobStatus.IN_PROGRESS);
            job.setUpdatedAt(LocalDateTime.now());
            jobRepository.save(job);
            logger.info("Processing job: {} ...", jobId);

            // 2. Random Delay (10s to 2 minutes)
            // 10s = 10000ms, 2m = 120000ms. Range = 110000ms
            long delay = 10000 + random.nextInt(110001);
            logger.info("Job {} sleeping for {} ms", jobId, delay);
            Thread.sleep(delay);

            // 3. Randomly Update to COMPLETED or FAILED
            if (random.nextBoolean()) {
                job.setStatus(JobStatus.COMPLETED);
                logger.info("Job {} finished: COMPLETED", jobId);
            } else {
                job.setStatus(JobStatus.FAILED);
                logger.info("Job {} finished: FAILED (simulated)", jobId);
            }
            
            job.setUpdatedAt(LocalDateTime.now());
            jobRepository.save(job);

        } catch (InterruptedException e) {
            logger.error("Job " + jobId + " was interrupted.");
            
            job.setStatus(JobStatus.FAILED);
            job.setUpdatedAt(LocalDateTime.now());
            jobRepository.save(job);
            
            Thread.currentThread().interrupt();
            throw new RuntimeException("Job processing interrupted", e);
        }
    }
}