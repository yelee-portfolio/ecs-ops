Health Check 장애 및 자동 롤백 확인

Health Check가 실패하도록 설정한 v2 이미지를 ECS에 배포함



1\. 문제

* v2의 `/actuator/health`가 503을 반환
* ALB는 새로 실행된 Task를 비정상 상태로 판단했고, v2 배포는 실패함
* 배포 중에도 기존 v1 Task는 계속 실행되고 있어서 서비스는 정상적으로 이용 가능



2\. 원인

v2에 설정한 `FAIL\_HEALTH=true` 때문에 Health Check가 503을 반환함



3\. 확인 내용

* ECS 이벤트에서 Health Check 503 오류 확인
* v2 배포 상태가 `FAILED`로 변경됨
* CloudWatch 알람이 `OK`에서 `ALARM`으로 변경됨
* SNS 장애 알림 메일 수신
* Circuit Breaker가 v1으로 자동 롤백한 것을 확인함



4\. 결과

실패한 v2 Task는 제거되고 정상 버전인 v1으로 자동 복구 됨

* ECS 배포 상태: COMPLETED
* 실행 중인 Task: 1개
* 버전: v1
* Health 상태: UP
* CloudWatch 알람: ALARM에서 OK로 복귀



5\. 알람

장애 알람: 20:03:39

정상 복귀: 20:04:39

\->  장애 감지부터 정상 복귀까지 약 1분 소요



6\. 개선한 점

* 비정상 Target을 1분 안에 감지하도록 알람 설정을 변경
* 배포 전에 자동 롤백 설정이 켜져 있는지 확인
* 배포할 이미지가 ECR에 있는지 먼저 확인

