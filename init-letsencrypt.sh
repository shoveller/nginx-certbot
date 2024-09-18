#!/bin/bash

# 인자 확인
if [ "$#" -lt 1 ]; then
    echo "사용법: $0 <도메인> [이메일]"
    exit 1
fi

# docker-compose가 설치되어 있는지 확인
if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

# 도메인 설정
domain=$1
domains=("$domain" "www.$domain")
rsa_key_size=4096
data_path="./data/certbot"
email="${2:-""}" # 두 번째 인자가 없으면 빈 문자열 사용
staging=0 # 테스트 중이라면 1로 설정하여 요청 제한 방지

# nginx 컨테이너 정지 및 삭제
echo "### Stopping and removing nginx container..."
docker stop nginx || true
docker rm nginx || true

# certbot 컨테이너 정지 및 삭제
echo "### Stopping and removing certbot container..."
docker stop certbot || true
docker rm certbot || true

# default.conf 파일 생성 함수
generate_default_conf() {
    local template_dir="./data/nginx/conf.d"
    local template_file="$template_dir/default.conf.template"
    local conf_file="$template_dir/default.conf"
    
    # 디렉토리가 없으면 생성
    if [ ! -d "$template_dir" ]; then
        mkdir -p "$template_dir"
        echo "$template_dir 디렉토리를 생성했습니다."
    fi

    # 템플릿 파일이 없으면 에러 메시지 출력 후 종료
    if [ ! -f "$template_file" ]; then
        echo "오류: $template_file 파일을 찾을 수 없습니다."
        return 1
    fi
    
    # 템플릿을 기반으로 default.conf 파일 생성
    sed "s/\${DOMAIN_NAME}/$domain/g" "$template_file" > "$conf_file"
    
    echo "default.conf 파일이 $domain 도메인으로 생성되었습니다."
}

# default.conf 파일 생성 함수 호출
generate_default_conf

# 기존 데이터가 있는 경우 사용자에게 확인
if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

# 필요한 TLS 매개변수 다운로드
if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

# 임시 인증서 생성
echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

# nginx 시작
echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

# 임시 인증서 삭제
echo "### Deleting dummy certificate for $domains ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo

# Let's Encrypt 인증서 요청
echo "### Requesting Let's Encrypt certificate for $domains ..."
# 도메인 인자 구성
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# 이메일 인자 선택
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# 필요한 경우 스테이징 모드 활성화
if [ $staging != "0" ]; then staging_arg="--staging"; fi

# certbot을 사용하여 인증서 발급
docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

# nginx 재로드
echo "### Reloading nginx and updating domain..."
docker-compose exec nginx nginx -s reload
