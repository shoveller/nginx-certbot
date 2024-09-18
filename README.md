# docker-compose에서 Let's Encrypt를 사용한 nginx 보일러플레이트

> 이 저장소는 [Docker를 사용하여 5분 만에 nginx와 Let's Encrypt를 설정하는 방법에 대한 단계별 가이드](https://medium.com/@pentacent/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71)와 함께 제공됩니다.

`init-letsencrypt.sh`는 docker-compose 설정에서 nginx와 함께 사용할 하나 또는 여러 도메인에 대한 Let's Encrypt 인증서를 가져오고 갱신을 보장합니다.
이는 애플리케이션의 리버스 프록시로 nginx를 설정해야 할 때 유용합니다.

## 설치
1. [docker-compose 설치](https://docs.docker.com/compose/install/#install-compose).

2. 이 저장소 클론: `git clone https://github.com/wmnnd/certbot.git .`

3. 설정 수정:
- init-letsencrypt.sh에 도메인과 이메일 주소 추가
- data/nginx/app.conf에서 example.org의 모든 항목을 주 도메인으로 교체 (init-letsencrypt.sh에 추가한 첫 번째 도메인)

4. 초기화 스크립트 실행:

        ./init-letsencrypt.sh

5. 서버 실행:

        docker-compose up -d

## 질문이 있으신가요?
[관련 가이드](https://medium.com/@pentacent/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71)의 댓글 섹션에 자유롭게 질문을 올려주세요.

## 라이선스
이 저장소의 모든 코드는 `MIT 라이선스` 조건에 따라 라이선스가 부여됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.
