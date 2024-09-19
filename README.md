# docker-compose에서 Let's Encrypt를 사용한 nginx 보일러플레이트

## 사옹법
0. `data/nginx/conf.d/default.conf.template` 에 서버 설정을 편집한다.
1. `.init-letsencrypt.sh <도메인> <이메일>` 을 실행해서 `data/nginx/conf.d/default.conf` 을 생성한다.

위 커맨드가 certbot 과 nginx 를 동시에 실행한다.
