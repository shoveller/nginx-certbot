@echo off
setlocal enabledelayedexpansion

REM 인자 확인
if "%~1"=="" (
    echo 사용법: %0 ^<도메인^> [이메일]
    exit /b 1
)

REM docker-compose가 설치되어 있는지 확인
where docker-compose >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: docker-compose is not installed.
    exit /b 1
)

REM 도메인 설정
set domain=%~1
set domains=%domain% www.%domain%
set rsa_key_size=4096
set data_path=.\data\certbot
if "%~2"=="" (set email=) else (set email=%~2)
set staging=0

REM nginx-proxy 컨테이너 정지 및 삭제
echo ### Stopping and removing nginx-proxy container...
docker stop nginx-proxy 2>nul
docker rm nginx-proxy 2>nul

REM nginx-certbot 컨테이너 정지 및 삭제
echo ### Stopping and removing nginx-certbot container...
docker stop nginx-certbot 2>nul
docker rm nginx-certbot 2>nul

REM default.conf 파일 생성 함수
call :generate_default_conf
if %errorlevel% neq 0 exit /b %errorlevel%

REM 기존 데이터가 있는 경우 사용자에게 확인
if exist "%data_path%" (
    set /p decision=Existing data found for %domains%. Continue and replace existing certificate? (y/N) 
    if /i "!decision!" neq "y" exit /b
)

REM 필요한 TLS 매개변수 다운로드
if not exist "%data_path%\conf\options-ssl-nginx.conf" (
    echo ### Downloading recommended TLS parameters ...
    mkdir "%data_path%\conf" 2>nul
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "%data_path%\conf\options-ssl-nginx.conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "%data_path%\conf\ssl-dhparams.pem"
    echo.
)

REM 임시 인증서 생성
echo ### Creating dummy certificate for %domains% ...
set path=/etc/letsencrypt/live/%domain%
mkdir "%data_path%\conf\live\%domain%" 2>nul
docker-compose run --rm --entrypoint "openssl req -x509 -nodes -newkey rsa:%rsa_key_size% -days 1 -keyout '%path%/privkey.pem' -out '%path%/fullchain.pem' -subj '/CN=localhost'" certbot
echo.

REM nginx 시작
echo ### Starting nginx ...
docker-compose up --force-recreate -d nginx
echo.

REM 임시 인증서 삭제
echo ### Deleting dummy certificate for %domains% ...
docker-compose run --rm --entrypoint "rm -Rf /etc/letsencrypt/live/%domain% && rm -Rf /etc/letsencrypt/archive/%domain% && rm -Rf /etc/letsencrypt/renewal/%domain%.conf" certbot
echo.

REM Let's Encrypt 인증서 요청
echo ### Requesting Let's Encrypt certificate for %domains% ...
set domain_args=
for %%d in (%domains%) do set domain_args=!domain_args! -d %%d

if "%email%"=="" (
    set email_arg=--register-unsafely-without-email
) else (
    set email_arg=--email %email%
)

if %staging% neq 0 set staging_arg=--staging

docker-compose run --rm --entrypoint "certbot certonly --webroot -w /var/www/certbot %staging_arg% %email_arg% %domain_args% --rsa-key-size %rsa_key_size% --agree-tos --force-renewal" certbot
echo.

REM nginx 재로드
echo ### Reloading nginx and updating domain...
docker-compose exec nginx nginx -s reload

exit /b 0

:generate_default_conf
set template_dir=.\data\nginx\conf.d
set template_file=%template_dir%\default.conf.template
set conf_file=%template_dir%\default.conf

if not exist "%template_dir%" (
    mkdir "%template_dir%"
    echo %template_dir% 디렉토리를 생성했습니다.
)

if not exist "%template_file%" (
    echo 오류: %template_file% 파일을 찾을 수 없습니다.
    exit /b 1
)

(for /f "delims=" %%i in (%template_file%) do (
    set "line=%%i"
    setlocal enabledelayedexpansion
    set "line=!line:${DOMAIN_NAME}=%domain%!"
    echo !line!
    endlocal
)) > "%conf_file%"

echo default.conf 파일이 %domain% 도메인으로 생성되었습니다.
exit /b 0