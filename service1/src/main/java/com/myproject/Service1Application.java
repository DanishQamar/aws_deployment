package com.myproject;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import org.springframework.stereotype.Controller;
import org.springframework.http.ResponseEntity;
import io.awspring.cloud.sqs.operations.SqsTemplate;
import org.springframework.beans.factory.annotation.Value;

// (Imports for database/JPA repositories would also be here)

@SpringBootApplication
public class Service1Application {
    public static void main(String[] args) {
        SpringApplication.run(Service1Application.class, args);
    }
}

// (The WebController class is GONE)

@RestController
class JobController {

    private final SqsTemplate sqsTemplate;
    // Inject a JPA repository for database operations
    // private final JobRepository jobRepository;

    @Value("${SQS_QUEUE_URL}") // Reads from env var
    private String queueUrl;

    public JobController(SqsTemplate sqsTemplate) {
        this.sqsTemplate = sqsTemplate;
    }

    @PostMapping("/submit-job")
    public ResponseEntity<?> submitJob(@RequestBody JobRequest jobRequest) {
        // 1. Send to SQS
        var response = sqsTemplate.send(queueUrl, jobRequest.getDescription());
        String messageId = response.messageId().toString();
        
        // 2. Log to database
        // Job newJob = new Job(messageId, jobRequest.getDescription(), "SUBMITTED");
        // jobRepository.save(newJob);
        
        return ResponseEntity.ok(java.util.Map.of("message", "Job submitted", "message_id", messageId));
    }
    
    @GetMapping("/jobs")
    public ResponseEntity<?> getJobs() {
        // 3. Fetch jobs from database
        // return ResponseEntity.ok(jobRepository.findAll());
        
        // Return dummy data for now
        return ResponseEntity.ok(java.util.Collections.emptyList());
    }
}

class JobRequest {
    private String description;
    public String getDescription() { return description; }
    public void setDescription(String d) { this.description = d; }
}