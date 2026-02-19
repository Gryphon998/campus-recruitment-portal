package com.platform.campusrecruitmentportal.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.net.URI;
import java.time.Duration;

@Service
public class S3Service {
    // 从 application.properties 读取 Terraform 生成的桶名
    @Value("${app.s3.resume-bucket-name}")
    private String bucketName;

    // S3Presigner 是 SDK v2 中专门用于生成预签名 URL 的类
    private final S3Presigner presigner;

    public S3Service() {
        this.presigner = S3Presigner.builder()
                .region(Region.US_EAST_1)
                .endpointOverride(URI.create("https://s3-external-1.amazonaws.com")) // 强制指定区域 Endpoint
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(true)
                        .build())
                .build();
    }

    public String generatePresignedUrl(String candidateId, String fileName) {
        // 1. 构建文件在 S3 中的唯一路径 (Key)
        String objectKey = "resumes/" + candidateId + "/" + fileName;

        // 2. 创建一个上传请求对象
        PutObjectRequest objectRequest = PutObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
//                .contentType("application/pdf") // 限制上传类型为 PDF
                .build();

        // 3. 设置预签名请求的参数（如 15 分钟有效期）
        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(15))
                .putObjectRequest(objectRequest)
                .build();

        // 4. 生成预签名 URL
        PresignedPutObjectRequest presignedRequest = presigner.presignPutObject(presignRequest);

        return presignedRequest.url().toString();
    }
}
