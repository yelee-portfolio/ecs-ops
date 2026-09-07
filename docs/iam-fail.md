IAM 권한 장애 및 복구 확인

ECS Task Execution Role에서 Secrets Manager 조회 권한을 제거한 뒤 새 버전을 배포함



1\. 문제

* 기존 Task는 계속 정상적으로 동작함
* 새 Task는 `RUNNING` 상태에 도달하지 못함
* 새 배포의 실패 Task 수가 증가함
* ECS Deployment Circuit Breaker가 새 배포를 실패로 판단함



2\. 원인

* Task Execution Role에 Secret 값을 가져오는 secretsmanager:GetSecretValue 권한이 없어서 Task 실행에 실패함
* DescribeSecret 권한만으로는 Secret 정보를 확인할 수 있지만, 실제 값을 가져와 컨테이너에 넣을 수는 없음
* ECS는 컨테이너를 시작하기 전에 Task Execution Role을 사용해 Secret 값을 가져옴. 이때 권한이 없으면 애플리케이션이 실행되기 전에 Task가 종료됨



3\. 확인 내용

* ECS 이벤트에서 `ResourceInitializationError` 확인
* AWS 오류에서 `AccessDeniedException` 확인
* 거부된 작업이 `secretsmanager:GetSecretValue`인 것을 확인
* 권한이 거부된 대상이 `ecs-ops-exec` Execution Role인 것을 확인
* 장애가 발생하는 동안 기존 정상 Task가 사용자 요청을 계속 처리함



4\. 복구 및 결과

Task Execution Role 정책에 secretsmanager:GetSecretValue 권한을 다시 추가함

권한 복구 후 새로 배포하여 Task가 Secret 값을 정상적으로 가져오고 실행되는 것을 확인함

* ECS 배포 상태: COMPLETED
* 실행 중인 Task: 1개
* Task Definition: Revision 4
* 실행 중인 버전: v1
* Health 상태: UP
* Terraform Plan: No changes



5\. 시간

* 장애 배포 시작: 21:31:02
* 배포 실패 및 롤백: 21:42:41
* 기존 배포 정상화: 21:43:19
* 권한 복구 후 재배포: 21:45:15



6\. 알람 확인

새 Task가 ALB Target으로 등록되기 전에 실패했기 때문에 ALB Unhealthy Alarm은 발생하지 않음

이번 장애는 ECS 이벤트와 중지된 Task의 ResourceInitializationError를 통해 확인함



7\. 개선한 점



* Task Definition에 Secret을 추가할 때 Task Execution Role 권한도 함께 확인
* 필요한 Secret ARN에만 접근할 수 있도록 최소 권한 적용
* ECS 배포 실패 이벤트를 EventBridge와 SNS에 연결
* 배포 전에 Secret과 AWSCURRENT 버전이 있는지 확인

