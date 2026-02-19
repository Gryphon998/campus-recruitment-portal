package com.platform.campusrecruitmentportal.controller;

import com.platform.campusrecruitmentportal.service.S3Service;
import lombok.RequiredArgsConstructor;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/candidates")
@RequiredArgsConstructor
public class candidateController {
    private final S3Service s3Service;

    @GetMapping("/resume/upload-url")
    public ResponseEntity<Map<String, String>> getResumeUploadUrl(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam String fileName) {

        // 从 JWT 获取用户唯一标识 (Google 账号在 Cognito 中的 ID)
        String candidateId = jwt.getClaimAsString("sub");

        // 生成预签名 URL
        String presignedUrl = s3Service.generatePresignedUrl(candidateId, fileName);

        Map<String, String> response = new HashMap<>();
        response.put("uploadUrl", presignedUrl);
        response.put("fileKey", "resumes/" + candidateId + "/" + fileName);

        return ResponseEntity.ok(response);
    }
}
