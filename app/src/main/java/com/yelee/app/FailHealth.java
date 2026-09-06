package com.yelee.app;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.stereotype.Component;

@Component
public class FailHealth implements HealthIndicator {

    private final boolean fail;

    public FailHealth(@Value("${FAIL_HEALTH:false}") boolean fail) {
        this.fail = fail;
    }

    @Override
    public Health health() {
        if (fail) {
            return Health.down()
                    .withDetail("reason", "rollback test")
                    .build();
        }

        return Health.up().build();
    }
}