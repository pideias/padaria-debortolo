#!/usr/bin/env bash
# One-time migration from direct Kestrel :8080 to Nginx + two localhost slots.
set -euo pipefail

stage="${1:-/tmp/infinitecoffee-api-stage}"
legacy_dir=/opt/padaria-api
slot_root=/opt/padaria-api-slots
state_dir=/etc/padaria-api
ready_marker="$state_dir/bluegreen-ready"
active_slot_file="$state_dir/active-slot"
active_nginx_conf=/etc/nginx/conf.d/00-padaria-api-active.conf
proxy_nginx_conf=/etc/nginx/conf.d/10-padaria-api-bluegreen.conf
disabled_sites=/etc/nginx/sites-disabled-by-padaria-bluegreen

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Execute este script como root." >&2
    exit 1
fi
if [[ -e "$ready_marker" ]]; then
    echo "Blue-green já foi inicializado; nenhuma alteração foi feita." >&2
    exit 1
fi
if ! systemctl is-active --quiet padaria-api; then
    echo "O serviço legado padaria-api precisa estar ativo antes da migração." >&2
    exit 1
fi
if [[ ! -f "$legacy_dir/app.env" || ! -f "$stage/InfiniteCoffee2.dll" ]]; then
    echo "Falta app.env ou a publicação Linux em $stage." >&2
    exit 1
fi
if [[ -e "$stage/app.env" ]]; then
    echo "O pacote não deve conter app.env." >&2
    exit 1
fi
if [[ -e "$slot_root" || -e "$active_nginx_conf" || -e "$proxy_nginx_conf" ]]; then
    echo "Já existem arquivos ou diretórios blue-green; pare e inspecione." >&2
    exit 1
fi
for port in 8081 8082; do
    if ss -H -lnt "sport = :$port" | grep -q .; then
        echo "A porta $port já está em uso." >&2
        exit 1
    fi
done
if ! dotnet --list-runtimes | grep -qE '^Microsoft\.AspNetCore\.App 10\.'; then
    echo "É necessário ter o runtime ASP.NET Core 10 instalado." >&2
    exit 1
fi

read -r -p "Confirme que não há atendimentos abertos. A primeira troca causa uma pausa breve e reinicia as sessões em memória. Digite MIGRAR para continuar: " confirm
if [[ "$confirm" != "MIGRAR" ]]; then
    echo "Cancelado; a API atual continua ativa."
    exit 0
fi

if command -v nginx >/dev/null 2>&1; then
    if systemctl is-active --quiet nginx; then
        echo "Nginx já está ativo; este bootstrap não vai substituir uma configuração existente." >&2
        exit 1
    fi
else
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
fi
systemctl stop nginx 2>/dev/null || true

# Desativa somente o site padrão do pacote; mantém o arquivo original disponível.
if [[ -L /etc/nginx/sites-enabled/default ]]; then
    install -d -m 755 "$disabled_sites"
    mv /etc/nginx/sites-enabled/default "$disabled_sites/default"
fi

install -d -o root -g root -m 755 "$slot_root/blue" "$slot_root/green" "$state_dir"
cp -a "$stage/." "$slot_root/blue/"
cp -a "$stage/." "$slot_root/green/"
chown -R --reference="$legacy_dir" "$slot_root"
chmod --reference="$legacy_dir" "$slot_root/blue" "$slot_root/green"

write_slot_unit() {
    local slot="$1" port="$2"
    cat > "/etc/systemd/system/padaria-api-${slot}.service" <<UNIT
[Unit]
Description=Infinite Coffee API (${slot} slot)
After=network.target padaria-addam.service

[Service]
Type=simple
User=root
WorkingDirectory=${slot_root}/${slot}
EnvironmentFile=${legacy_dir}/app.env
ExecStart=/usr/bin/dotnet ${slot_root}/${slot}/InfiniteCoffee2.dll --urls http://127.0.0.1:${port}
Restart=on-failure
RestartSec=3
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
UNIT
    chmod 644 "/etc/systemd/system/padaria-api-${slot}.service"
}

write_slot_unit blue 8081
write_slot_unit green 8082

cat > "$active_nginx_conf" <<'NGINX'
map $host $padaria_active_slot {
    default blue;
}
NGINX

cat > "$proxy_nginx_conf" <<'NGINX'
map $cookie_padaria_slot $padaria_route_slot {
    blue blue;
    green green;
    default $padaria_active_slot;
}

map $padaria_route_slot $padaria_upstream {
    blue 127.0.0.1:8081;
    green 127.0.0.1:8082;
}

map $padaria_route_slot $padaria_access_log {
    blue /var/log/nginx/padaria-api-blue.access.log;
    green /var/log/nginx/padaria-api-green.access.log;
}

log_format padaria_api_slot '$time_iso8601 $remote_addr $request_method $uri $status $body_bytes_sent';

server {
    listen 8080;
    server_name srv1956950.hstgr.cloud 179.199.144.253 _;
    access_log $padaria_access_log padaria_api_slot;
    client_max_body_size 1m;

    location / {
        proxy_pass http://$padaria_upstream;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 10s;
        proxy_read_timeout 90s;
        add_header Set-Cookie "padaria_slot=$padaria_route_slot; Path=/; HttpOnly; SameSite=Lax; Max-Age=1800" always;
    }
}
NGINX

install -o www-data -g adm -m 640 /dev/null /var/log/nginx/padaria-api-blue.access.log
install -o www-data -g adm -m 640 /dev/null /var/log/nginx/padaria-api-green.access.log

nginx -t
systemctl daemon-reload
if ! systemctl enable --now padaria-api-blue padaria-api-green; then
    systemctl disable --now padaria-api-blue padaria-api-green 2>/dev/null || true
    echo "Os slots não iniciaram; a API legada continua em 8080." >&2
    exit 1
fi

wait_for_health() {
    local url="$1"
    for attempt in $(seq 1 20); do
        if curl --fail --silent --show-error --max-time 5 "$url"; then
            return 0
        fi
        sleep 2
    done
    return 1
}

for port in 8081 8082; do
    if ! wait_for_health "http://127.0.0.1:${port}/api/health"; then
        systemctl disable --now padaria-api-blue padaria-api-green 2>/dev/null || true
        echo "Slot na porta $port falhou; a API legada ainda está em 8080." >&2
        exit 1
    fi
done

if ! nginx -t; then
    systemctl disable --now padaria-api-blue padaria-api-green 2>/dev/null || true
    echo "A configuração do Nginx falhou; a API legada continua em 8080." >&2
    exit 1
fi

rollback_legacy_api() {
    systemctl stop nginx 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true
    systemctl disable --now padaria-api-blue padaria-api-green 2>/dev/null || true
    systemctl enable padaria-api >/dev/null 2>&1 || true
    systemctl start padaria-api || true
}

# One-time cutover. The old files and app.env are deliberately preserved.
systemctl stop padaria-api
if ! systemctl disable padaria-api >/dev/null; then
    systemctl start padaria-api || true
    systemctl disable --now padaria-api-blue padaria-api-green 2>/dev/null || true
    echo "Não foi possível desabilitar o serviço legado; ele foi iniciado novamente." >&2
    exit 1
fi
if ! systemctl enable --now nginx; then
    rollback_legacy_api
    echo "Nginx não iniciou; a API legada foi restaurada." >&2
    exit 1
fi

if ! wait_for_health http://127.0.0.1:8080/api/health; then
    rollback_legacy_api
    echo "O health-check pelo proxy falhou; a API legada foi restaurada." >&2
    exit 1
fi

printf 'blue\n' > "$active_slot_file"
touch "$ready_marker"
systemctl enable nginx padaria-api-blue padaria-api-green >/dev/null
echo "Blue-green ativo: Nginx :8080 -> slot blue :8081; slot green :8082 está pronto."
