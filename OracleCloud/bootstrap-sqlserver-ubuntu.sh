#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Execute como root: sudo $0 --allow-cidr <CIDR>" >&2
  exit 1
fi

ALLOW_CIDR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-cidr)
      ALLOW_CIDR="${2:-}"
      shift 2
      ;;
    *)
      echo "Argumento desconhecido: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ALLOW_CIDR" ]]; then
  echo "Informe --allow-cidr para liberar o SQL Server de forma explicita." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates gnupg ufw apt-transport-https

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
  gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/22.04/mssql-server-2022 jammy main" \
  > /etc/apt/sources.list.d/mssql-server-2022.list
apt-get update
apt-get install -y mssql-server

if [[ ! -f /var/opt/mssql/data/master.mdf ]]; then
  read -r -s -p "Senha forte do usuario sa: " MSSQL_SA_PASSWORD
  echo
  read -r -s -p "Repita a senha: " MSSQL_SA_PASSWORD_CONFIRM
  echo
  if [[ "$MSSQL_SA_PASSWORD" != "$MSSQL_SA_PASSWORD_CONFIRM" || -z "$MSSQL_SA_PASSWORD" ]]; then
    echo "As senhas nao conferem." >&2
    exit 1
  fi
  export MSSQL_SA_PASSWORD
  export ACCEPT_EULA=Y
  export MSSQL_PID=Developer
  /opt/mssql/bin/mssql-conf -n setup
  unset MSSQL_SA_PASSWORD MSSQL_SA_PASSWORD_CONFIRM ACCEPT_EULA MSSQL_PID
fi

systemctl enable --now mssql-server

ufw allow ssh/tcp
ufw allow from "$ALLOW_CIDR" to any port 1433 proto tcp
ufw --force enable

echo "SQL Server instalado e ativo. Verifique tambem a regra TCP 1433 na VCN/NSG da Oracle Cloud."
echo "Aplique DatabaseScripts/InstallDatabase.sql com sqlcmd e configure PADARIA_CONNECTION_STRING no Render."
