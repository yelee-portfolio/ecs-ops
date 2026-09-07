# ECS 장애 대응 절차

ECS 서비스에서 장애가 발생했을 때 원인을 확인하고 복구하는 순서를 정리했습니다.

## 1. 알림 확인

SNS 이메일에서 다음 내용을 확인합니다.

* 알람 이름
* 장애 발생 시각
* ECS Service 이름
* 오류 내용
* 배포 실패 여부

## 2. ECS Service 상태 확인

```powershell
aws ecs describe-services `
  --cluster ecs-ops `
  --services ecs-ops `
  --query "services[0].deployments[].{Status:status,Rollout:rolloutState,Reason:rolloutStateReason,Task:taskDefinition,Running:runningCount,Failed:failedTasks}"
```

다음 항목을 확인합니다.

* 배포 상태가 `COMPLETED`인지
* 실행 중인 Task가 1개인지
* 실패한 Task가 있는지
* 이전 정상 버전으로 롤백됐는지
* `rolloutStateReason`에 오류 내용이 있는지

## 3. ECS 이벤트 확인

```powershell
aws ecs describe-services `
  --cluster ecs-ops `
  --services ecs-ops `
  --query "services[0].events[0:20].[createdAt,message]" `
  --output table
```

이벤트에서 다음 내용을 확인합니다.

* `Health checks failed with codes 503`
* `Request timed out`
* `AccessDeniedException`
* `ResourceInitializationError`
* `tasks failed to start`
* `rolling back`

## 4. ALB Target 상태 확인

먼저 Target Group ARN을 조회합니다.

```powershell
$tg = aws elbv2 describe-target-groups `
  --names ecs-ops `
  --query "TargetGroups[0].TargetGroupArn" `
  --output text
```

Target 상태와 오류 내용을 확인합니다.

```powershell
aws elbv2 describe-target-health `
  --target-group-arn $tg `
  --query "TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}" `
  --output table
```

| 확인 결과               | 예상 원인                      |
| ------------------- | -------------------------- |
| HTTP 503            | 애플리케이션 Health Check 실패     |
| `Request timed out` | Security Group 또는 포트 설정 문제 |
| Target 없음           | Task 시작 실패 또는 Target 등록 실패 |

## 5. 중지된 Task 확인

최근에 중지된 Task ARN을 조회합니다.

```powershell
$tasks = aws ecs list-tasks `
  --cluster ecs-ops `
  --service-name ecs-ops `
  --desired-status STOPPED `
  --query "taskArns" `
  --output text

$tasks
```

Task ARN이 조회됐을 때만 다음 명령을 실행합니다.

```powershell
aws ecs describe-tasks `
  --cluster ecs-ops `
  --tasks $tasks `
  --query "tasks[].{Time:stoppedAt,Reason:stoppedReason,ContainerReason:containers[0].reason,ExitCode:containers[0].exitCode}"
```

다음 내용을 확인합니다.

* Task가 중지된 시각
* Task 중지 원인
* 컨테이너 오류 내용
* 컨테이너 종료 코드

## 6. 원인에 따라 복구

### Health Check 실패

* 배포한 이미지가 정상 버전인지 확인
* `APP_VERSION`과 `FAIL_HEALTH` 환경변수 확인
* ECS 자동 롤백 상태 확인
* 이전 정상 Task Definition이 실행됐는지 확인

### 네트워크 장애

* ALB에서 ECS로 가는 Security Group 규칙 확인
* ECS 애플리케이션 포트인 8080이 허용되어 있는지 확인
* Terraform 코드에서 포트를 8080으로 복구
* `terraform plan` 확인 후 정상 설정 적용

### IAM 권한 장애

* Task Execution Role 확인
* `secretsmanager:GetSecretValue` 권한 확인
* 필요한 Secret ARN에 접근할 수 있는지 확인
* 권한 복구 후 새 배포 실행

```powershell
aws ecs update-service `
  --cluster ecs-ops `
  --service ecs-ops `
  --force-new-deployment
```

## 7. 정상화 확인

ECS Service가 안정 상태가 될 때까지 기다립니다.

```powershell
aws ecs wait services-stable `
  --cluster ecs-ops `
  --services ecs-ops
```

서비스 주소를 가져와 버전과 Health 상태를 확인합니다.

```powershell
$url = terraform -chdir=".\infra\dev" output -raw url

Invoke-RestMethod "http://${url}/version"
Invoke-RestMethod "http://${url}/actuator/health"
```

다음 항목이 모두 정상인지 확인합니다.

* ECS 배포 상태: `COMPLETED`
* 실행 중인 Task: 1개
* Health 상태: `UP`
* CloudWatch Alarm: `OK`
* 서비스 요청: 정상 응답
* 실행 중인 버전: `v1`

CloudWatch Alarm은 지표 반영에 시간이 걸릴 수 있으므로 `OK` 상태로 돌아올 때까지 기다립니다.

## 8. 장애 기록

복구가 끝나면 다음 내용을 기록합니다.

* 장애 발생 시각
* 장애 탐지 시각
* 서비스 복구 시각
* 사용자에게 나타난 증상
* 실제 장애 원인
* 원인을 확인한 방법
* 적용한 복구 방법
* 복구에 걸린 시간
* 재발 방지를 위해 개선한 내용
