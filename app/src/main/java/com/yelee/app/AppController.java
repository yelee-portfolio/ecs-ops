package com.yelee.app;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AppController {

    private final String version;
    private final String secret;

    public AppController(
            @Value("${APP_VERSION:local}") String version,
            @Value("${DEMO_SECRET:}") String secret) {
        this.version = version;
        this.secret = secret;
    }

    @GetMapping("/")
    public Map<String, String> home() {
        return Map.of(
                "service", "ecs-ops",
                "status", "ok"
        );
    }

    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of("version", version);
    }

    @GetMapping("/env-check")
    public Map<String, Boolean> envCheck() {
        return Map.of("secret", !secret.isBlank());
    }
}