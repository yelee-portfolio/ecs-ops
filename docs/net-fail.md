Network 장애 및 복구 확인

ALB에서 ECS로 접근할 때 사용하는 ECS Security Group의 인바운드 포트를

8080에서 9999로 변경함



1\. 문제

* 외부 요청이 10초 후 타임아웃됨
* ALB Health Check가 ECS Task에 도달하지 못함
* Target이 unhealthy 상태로 변경됨
* ECS가 비정상 Task를 반복해서 교체함



2\. 원인

* ALB는 Target의 8080 포트로 요청했지만,
ECS Security Group의 인바운드 포트가 9999로 변경되어 요청이 차단됨
* 애플리케이션 장애에서는 Health Check 요청에 503이 반환됐지만, 
이번에는 요청이 애플리케이션까지 도달하지 못해 타임아웃이 발생함
* ECS가 Task를 교체해도 모든 Task가 같은 Security Group을 사용하기 때문에 자동 재시작만으로는 복구되지 않음



3\. 확인 내용

* 외부 요청에서 타임아웃 확인
* ECS 이벤트에서 Request timed out 확인
* CloudWatch Alarm이 OK에서 ALARM으로 변경됨
* ECS 이벤트에서 비정상 상태로 인한 Task 교체 확인
* Target 상태가 unhealthy로 변경된 것을 확인함



4\. 결과

Terraform에서 ECS Security Group의 인바운드 포트를 9999에서 8080으로 복구함

* ECS Service 상태: steady state
* Target 상태: healthy
* 실행 중인 버전: v1
* Health 상태: UP
* CloudWatch Alarm: ALARM에서 OK로 복귀
* Terraform Plan: No changes



5\. 시간

* 장애 적용: 20:50
* 알람 발생: 20:53:39
* 서비스 안정화: 20:57:40
* 알람 정상화: 21:00:39
* 장애 감지까지 약 3분 40초 소요
* 서비스 안정화까지 약 7분 40초 소요



6\. 개선한 점

* ALB에서 ECS로 허용하는 포트가 변경되는지 Terraform Plan에서 확인
* Target 상태가 타임아웃이면 Security Group과 네트워크 경로를 먼저 확인
* Task가 반복해서 재시작되면 공통으로 사용하는 인프라 설정부터 점검

