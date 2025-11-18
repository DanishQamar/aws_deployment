package com.myproject;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import io.awspring.cloud.sqs.annotation.SqsListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

// --- ADDED IMPORTS FOR JPA/DATABASE ---
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Enumerated;
import jakarta.persistence.EnumType;
import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.stereotype.Component;
import java.util.Random;
// --- END OF ADDED IMPORTS ---

@SpringBootApplication
public class Service2Application {
    public static void main(String[] args) {
        SpringApplication.run(Service2Application.class, args);
    }
}

// --- vvv JOB STATUS ENUM vvv ---
// This MUST be identical to the one in Service 1
enum JobStatus {
    SUBMITTED,
    IN_PROGRESS,
    COMPLETED,
    FAILED
}
// --- ^^^ JOB STATUS ENUM ^^^ ---


// --- vvv JOB ENTITY vvv ---
// This class MUST be identical to the one in Service 1
// It allows Service 2 to read/write to the same "jobs" table
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
// This interface MUST be identical to the one in Service 1
@Repository
interface JobRepository extends JpaRepository<Job, String> {}
// --- ^^^ JOB REPOSITORY ^^^ ---


@Component
class JobWorker {
    private static final Logger logger = LoggerFactory.getLogger(JobWorker.class);
    
    // --- INJECT THE REPOSITORY ---
    private final JobRepository jobRepository;
    private final Random random = new Random();

    public JobWorker(JobRepository jobRepository) {
        this.jobRepository = jobRepository;
    }

    // The SQS queue name is read from application.properties
    @SqsListener("${SQS_QUEUE_NAME}") 
    public void processMessage(String messageBody, @org.springframework.messaging.handler.annotation.Header("MessageId") String messageId) {
        logger.info("Received job " + messageId + " with body: " + messageBody);

        // --- Find the job in the database ---
        Optional<Job> jobOpt = jobRepository.findById(messageId);
        if (jobOpt.isEmpty()) {
            logger.error("Job {} not found in database! Discarding message.", messageId);
            return; // Acknowledge SQS message but do nothing
        }
        Job job = jobOpt.get();

        try {
            // 1. Random wait before picking up the task (2s to 20s)
            // Range: 2000ms to 20000ms
            long startDelay = 2000 + random.nextInt(18001);
            logger.info("Job {}: Waiting {} ms before starting...", messageId, startDelay);
            Thread.sleep(startDelay);

            // 2. Update job status to IN_PROGRESS
            job.setStatus(JobStatus.IN_PROGRESS);
            job.setUpdatedAt(LocalDateTime.now());
            jobRepository.save(job);
            logger.info("Processing job: " + messageId);

            // 3. Random processing time (2s to 2 minutes)
            // Range: 2000ms to 120000ms
            long processDelay = 2000 + random.nextInt(118001); 
            logger.info("Job {}: Simulating processing for {} ms...", messageId, processDelay);
            Thread.sleep(processDelay);

            // 4. Randomly determine Outcome (COMPLETED or FAILED)
            boolean isSuccess = random.nextBoolean();
            
            if (isSuccess) {
                job.setStatus(JobStatus.COMPLETED);
                logger.info("Finished job: " + messageId + " [SUCCESS]");
            } else {
                job.setStatus(JobStatus.FAILED);
                logger.warn("Finished job: " + messageId + " [FAILED]");
            }
            
            job.setUpdatedAt(LocalDateTime.now());
            jobRepository.save(job);

        } catch (InterruptedException e) {
            logger.error("Job " + messageId + " was interrupted.");
            
            // --- SET STATUS TO FAILED ON ERROR ---
            job.setStatus(JobStatus.FAILED);
            job.setUpdatedAt(LocalDateTime.now());
            jobRepository.save(job);
            
            // Re-throw exception so SQS knows processing failed
            // This will cause SQS to retry or send to a Dead-Letter Queue (DLQ)
            Thread.currentThread().interrupt();
            throw new RuntimeException("Job processing interrupted", e);
        }
    }
}