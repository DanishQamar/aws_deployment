package com.myproject;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import io.awspring.cloud.sqs.annotation.SqsListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

// (Imports for database/JPA repositories would also be here)

@SpringBootApplication
public class Service2Application {
    public static void main(String[] args) {
        SpringApplication.run(Service2Application.class, args);
    }
}

@org.springframework.stereotype.Component
class JobWorker {
    private static final Logger logger = LoggerFactory.getLogger(JobWorker.class);
    // private final JobRepository jobRepository;

    // The SQS queue name is read from application.properties
    @SqsListener("${SQS_QUEUE_NAME}") 
    public void processMessage(String messageBody, @org.springframework.messaging.handler.annotation.Header("MessageId") String messageId) {
        logger.info("Received job " + messageId + " with body: " + messageBody);

        try {
            // 1. Update job status to IN_PROGRESS
            // jobRepository.updateStatus(messageId, "IN_PROGRESS");
            logger.info("Processing job: " + messageId);

            // 2. Simulate long-running work
            Thread.sleep(10000); // 10 seconds

            // 3. Update job status to COMPLETE
            // jobRepository.updateStatus(messageId, "COMPLETE");
            logger.info("Finished job: " + messageId);

        } catch (InterruptedException e) {
            logger.error("Job " + messageId + " was interrupted.");
            // (Job would be returned to queue)
        }
    }
}