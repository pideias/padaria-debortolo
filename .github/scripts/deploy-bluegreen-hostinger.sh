#!/usr/bin/env bash
set -euo pipefail

sha="$1"
run_id="$2"
run_attempt="$3"
deploy_id="${sha}-${run_id}-${run_attempt}"
archive="/tmp/padaria-api-${deploy_id}.tar.gz"
stage="/tmp/padaria-api-stage-${deploy_id}"
legacy_dir=/opt/padaria-api
slot_root=/opt/padaria-api-slots
state_dir=/etc/padaria-api
active_slot_file="$state_dir/active-slot"
ready_marker="$state_dir/bluegreen-ready"
active_nginx_conf=/etc/nginx/conf.d/00-padaria-api-active.conf
backup_root=/opt/padaria-api-backups/slots

run_privileged() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

if ! run_privileged test -f "$ready_marker"; then
    echo "Blue-green não está inicializado; execute Setup-BlueGreen-Hostinger.sh primeiro." >&2
    exit 1
fi
run_privileged test -f "$legacy_dir/app.env"
run_privileged test -f "$active_nginx_conf"
test -f "$archive"

active_slot="$(run_privileged sed -nE 's/.*default (blue|green);.*/\1/p' "$active_nginx_conf" | head -n 1)"
case "$active_slot" in
    blue) target_slot=green; target_port=8082 ;;
    green) target_slot=blue; target_port=8081 ;;
    *) echo "Marcador de slot inválido: $active_slot" >&2; exit 1 ;;
esac
printf '%s\n' "$active_slot" | run_privileged tee "$active_slot_file" >/dev/null

target_service="padaria-api-${target_slot}"
target_dir="$slot_root/$target_slot"
target_log="/var/log/nginx/padaria-api-${target_slot}.access.log"
candidate="/opt/padaria-api-candidate-${deploy_id}"
backup="${backup_root}/padaria-api-${target_slot}-${deploy_id}"
failed="/opt/padaria-api-failed-${deploy_id}"

# Sessions use a 30-minute in-memory cache. Do not overwrite a slot with recent traffic.
if run_privileged test -f "$target_log"; then
    last_access="$(run_privileged stat -c %Y "$target_log")"
    idle_seconds=$(( $(date +%s) - last_access ))
    if (( idle_seconds < 1800 )); then
        echo "Slot $target_slot teve tráfego há ${idle_seconds}s; aguarde 30 minutos sem uso para preservar sessões." >&2
        exit 1
    fi
fi

mkdir -m 700 "$stage"
tar -xzf "$archive" -C "$stage"
test -f "$stage/InfiniteCoffee2.dll"
if [[ -e "$stage/app.env" ]]; then
    echo "Recusando pacote com app.env; a configuração deve permanecer na VM." >&2
    exit 1
fi

run_privileged test -d "$target_dir"
run_privileged install -d -m 700 "$backup_root"
run_privileged install -d -m 755 "$candidate"
run_privileged cp -a "$stage/." "$candidate/"
run_privileged chown -R --reference="$target_dir" "$candidate"
run_privileged chmod --reference="$target_dir" "$candidate"

if ! run_privileged systemctl stop "$target_service"; then
    echo "Não consegui parar o slot inativo $target_slot; nenhum arquivo foi trocado." >&2
    exit 1
fi
if run_privileged test -e "$target_dir"; then
    run_privileged mv "$target_dir" "$backup"
fi
if ! run_privileged mv "$candidate" "$target_dir"; then
    if run_privileged test -e "$backup"; then
        run_privileged mv "$backup" "$target_dir"
        run_privileged systemctl start "$target_service" || true
    fi
    exit 1
fi

if ! run_privileged systemctl start "$target_service"; then
    run_privileged mv "$target_dir" "$failed" || true
    if run_privileged test -e "$backup"; then
        run_privileged mv "$backup" "$target_dir"
        run_privileged systemctl start "$target_service" || true
    fi
    run_privileged journalctl -u "$target_service" -n 60 --no-pager || true
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

if ! wait_for_health "http://127.0.0.1:${target_port}/api/health"; then
    run_privileged systemctl stop "$target_service" || true
    run_privileged mv "$target_dir" "$failed" || true
    if run_privileged test -e "$backup"; then
        run_privileged mv "$backup" "$target_dir"
        run_privileged systemctl start "$target_service" || true
    fi
    run_privileged journalctl -u "$target_service" -n 60 --no-pager || true
    exit 1
fi

old_active_conf="/tmp/padaria-api-active-${deploy_id}.conf"
new_active_conf="/tmp/padaria-api-active-${deploy_id}.new"
run_privileged cp -a "$active_nginx_conf" "$old_active_conf"
printf 'map $host $padaria_active_slot { default %s; }\n' "$target_slot" > "$new_active_conf"
run_privileged install -o root -g root -m 644 "$new_active_conf" "$active_nginx_conf"

if ! run_privileged nginx -t || ! run_privileged systemctl reload nginx; then
    run_privileged install -o root -g root -m 644 "$old_active_conf" "$active_nginx_conf"
    run_privileged nginx -t && run_privileged systemctl reload nginx || true
    run_privileged systemctl stop "$target_service" || true
    run_privileged mv "$target_dir" "$failed" || true
    if run_privileged test -e "$backup"; then
        run_privileged mv "$backup" "$target_dir"
        run_privileged systemctl start "$target_service" || true
    fi
    exit 1
fi

# If the public health check fails, switch new traffic back. Keep the new slot
# running because a client may already have received its sticky-slot cookie.
if ! wait_for_health http://127.0.0.1:8080/api/health; then
    run_privileged install -o root -g root -m 644 "$old_active_conf" "$active_nginx_conf"
    run_privileged nginx -t && run_privileged systemctl reload nginx || true
    run_privileged journalctl -u nginx -n 60 --no-pager || true
    exit 1
fi

printf '%s\n' "$target_slot" | run_privileged tee "$active_slot_file" >/dev/null
rm -rf -- "$stage"
rm -f -- "$archive" "$old_active_conf" "$new_active_conf"
echo "Deploy blue-green concluído: $active_slot -> $target_slot. A instância anterior continua atendendo sessões existentes."
