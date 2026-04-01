#!/bin/bash

##############################################################################
#
# dominio.sh - Create By: Lucas Zafalon
# Script em shell utilizado para analise de dominios
#
##############################################################################

# Dependências obrigatórias
for cmd in dig whois curl openssl nc; do
  if ! command -v $cmd &> /dev/null; then
    echo "Erro: o comando '$cmd' é necessário. Instale com: sudo apt install dnsutils whois curl openssl netcat"
    exit 1
  fi
done

# Cores
BOLD="\e[1m"
UNDERLINE="\e[4m"
NC="\e[0m"
RED="\e[91m"
GREEN="\e[92m"
YELLOW="\e[93m"
CYAN="\e[96m"

# Armazena erros para exibição final
declare -a ERROS

# Cabeçalho
clear
echo -e "${BOLD}${CYAN}=========================================="
echo -e "           ANÁLISE DE DOMÍNIO"
echo -e "==========================================${NC}"
echo ""

# Entrada do domínio
read -p "Digite o domínio para análise (ex: exemplo.com.br): " DOMINIO
echo ""

if [ -z "$DOMINIO" ]; then
  echo "Erro: domínio não informado."
  exit 1
fi

echo -e "${BOLD}Analisando domínio: ${CYAN}$DOMINIO${NC}"
echo "------------------------------------------"

# IP (registro A)
echo -e "${CYAN}Endereço IP (A):${NC}"
IP_LIST=$(dig +short "$DOMINIO" A)
if [ -z "$IP_LIST" ]; then
  echo -e "  ${RED}Nenhum IP encontrado${NC}"
  ERROS+=("Endereço IP não encontrado – verifique se o domínio está registrado e configurado corretamente.")
else
  for IP in $IP_LIST; do
    case $IP in
      "169.57.171.118")
        echo -e "  - ${GREEN}$IP${NC}";;
      "169.57.171.119")
        echo -e "  - ${YELLOW}$IP${NC}";;
      *)
        echo -e "  - ${RED}${UNDERLINE}$IP${NC}"
        ERROS+=("IP inesperado: $IP – pode indicar que o domínio está apontando para o servidor errado ou não autorizado.");;
    esac
  done
fi
echo ""

# IPv6
echo -e "${CYAN}IPv6 (AAAA):${NC}"
dig +short "$DOMINIO" AAAA | sed 's/^/  - /'
echo ""

# Reverso
echo -e "${CYAN}Resolução reversa de IP:${NC}"
IP=$(echo "$IP_LIST" | head -1)
if [ -n "$IP" ]; then
  PTR=$(dig +short -x "$IP")
  echo "  $IP → $PTR"
  if [ -z "$PTR" ]; then
    ERROS+=("Resolução reversa ausente – pode impactar reputação de e-mails ou análise de segurança.")
  fi
fi
echo ""

# MX
echo -e "${CYAN}Servidores de E-mail (MX):${NC}"
MX=$(dig +short "$DOMINIO" MX)
if [ -z "$MX" ]; then
  echo -e "  ${RED}Nenhum servidor de e-mail encontrado${NC}"
  ERROS+=("Sem servidores MX – o domínio não poderá enviar ou receber e-mails.")
else
  echo "$MX" | sort -n | while read line; do
    if echo "$line" | grep -iq "emailemnuvem"; then
      echo -e "  - ${RED}${UNDERLINE}$line${NC}"
      ERROS+=("Servidor MX 'emailemnuvem' detectado – pode ser genérico ou mal configurado, verifique o provedor.")
    else
      echo "  - $line"
    fi
  done
fi
echo ""

# TXT
echo -e "${CYAN}Registros TXT:${NC}"
TXT=$(dig +short "$DOMINIO" TXT)
if [ -z "$TXT" ]; then
  echo "  Nenhum"
  ERROS+=("Sem registros TXT – pode impactar autenticação de e-mails (SPF, DKIM, DMARC).")
else
  echo "$TXT" | sed 's/^/  - /'
fi
echo ""

# CNAME
echo -e "${CYAN}Registro CNAME:${NC}"
CNAME=$(dig +short "$DOMINIO" CNAME)
if [ -n "$CNAME" ]; then
  echo "  - $CNAME"
fi
echo ""

# NS
echo -e "${CYAN}Servidores DNS (NS):${NC}"
NS=$(dig +short NS "$DOMINIO")
if [ -z "$NS" ]; then
  echo -e "  ${RED}Nenhum servidor DNS encontrado${NC}"
  ERROS+=("Sem servidores DNS – o domínio pode estar mal configurado ou inativo.")
else
  echo "$NS" | sed 's/^/  - /'
fi
echo ""

# WHOIS
echo -e "${CYAN}Informações WHOIS:${NC}"
WHOIS=$(whois "$DOMINIO")

ORG=$(echo "$WHOIS" | grep -iE "owner|organisation|org-name" | head -1 | cut -d: -f2- | sed 's/^[ \t]*//')
[ -n "$ORG" ] && echo "  Organização: $ORG"

CREATED=$(echo "$WHOIS" | grep -iE "created|Creation Date" | head -1 | grep -oE '[0-9]{4}-?[0-9]{2}-?[0-9]{2}')
[ -n "$CREATED" ] && echo "  Criado em: $(echo $CREATED | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')"

UPDATED=$(echo "$WHOIS" | grep -iE "changed|Updated Date" | head -1 | grep -oE '[0-9]{4}-?[0-9]{2}-?[0-9]{2}')
[ -n "$UPDATED" ] && echo "  Atualizado em: $(echo $UPDATED | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')"

EXPIRES=$(echo "$WHOIS" | grep -iE "expires|Expiration Date|validade" | head -1 | grep -oE '[0-9]{4}-?[0-9]{2}-?[0-9]{2}')
[ -n "$EXPIRES" ] && echo "  Expira em: $(echo $EXPIRES | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')"

STATUS=$(echo "$WHOIS" | grep -iE "status" | head -3 | sed 's/^/  - /')
[ -n "$STATUS" ] && echo "  Status:\n$STATUS"
echo ""

# Localização IP
if [ -n "$IP" ]; then
  COUNTRY=$(whois "$IP" | grep -i country | head -1 | awk '{print $2}')
  echo -e "${CYAN}Localização do IP:${NC} $COUNTRY"
  if [ -z "$COUNTRY" ]; then
    ERROS+=("Localização do IP não identificada – pode indicar IP inválido ou bloqueado.")
  fi
  echo ""
fi

# HTTP/HTTPS
echo -e "${CYAN}Status do site (HTTP/HTTPS):${NC}"
CURL_STATUS=$(curl -s -o /dev/null -I -L -w "%{http_code}" "https://$DOMINIO")
echo "  Código HTTP: $CURL_STATUS"
if [[ "$CURL_STATUS" -ge 400 ]]; then
  ERROS+=("Código HTTP $CURL_STATUS – o site pode estar fora do ar ou com erro de servidor.")
fi
echo ""

# SSL
echo -e "${CYAN}Certificado SSL (porta 443):${NC}"
nc -z -w3 "$DOMINIO" 443 &>/dev/null
if [ $? -eq 0 ]; then
  SSLINFO=$(echo | openssl s_client -servername "$DOMINIO" -connect "$DOMINIO:443" 2>/dev/null | openssl x509 -noout -issuer -dates)
  echo "$SSLINFO" | sed 's/^/  /'
  EXPDATE=$(echo "$SSLINFO" | grep 'notAfter' | cut -d= -f2)
  EXPSEC=$(date -d "$EXPDATE" +%s 2>/dev/null)
  NOWSEC=$(date +%s)
  if [ "$EXPSEC" -le "$NOWSEC" ]; then
    ERROS+=("Certificado SSL expirado – renove seu certificado para manter a segurança do site.")
  fi
else
  echo -e "  ${RED}Não foi possível conectar na porta 443 (SSL indisponível)${NC}"
  ERROS+=("SSL não disponível – o site pode estar sem HTTPS, comprometendo segurança e indexação.")
fi

echo ""
echo -e "${BOLD}${GREEN}Análise concluída.${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

# ERROS ENCONTRADOS
if [ ${#ERROS[@]} -gt 0 ]; then
  echo -e "${RED}${BOLD}Foram encontradas ${#ERROS[@]} anomalias ou erros:${NC}"
  for msg in "${ERROS[@]}"; do
    echo -e "${RED}- $msg${NC}"
  done
  echo ""
fi