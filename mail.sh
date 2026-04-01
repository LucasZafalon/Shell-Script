#!/bin/bash

##############################################################################
#
# dominio.sh - Create By: Lucas Zafalon
# Script em shell utilizado para analise de e-mails
#
##############################################################################

# Dependências obrigatórias
for cmd in dig openssl nc; do
  if ! command -v $cmd &> /dev/null; then
    echo "Erro: o comando '$cmd' é necessário. Instale com: sudo apt install dnsutils openssl netcat"
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

# Armazena erros
declare -a ERROS

# Cabeçalho
clear
echo -e "${BOLD}${CYAN}=========================================="
echo -e "        ANÁLISE DE E-MAIL (DNS + SSL)"
echo -e "==========================================${NC}"
echo ""

# Entrada do domínio
read -p "Digite o domínio do e-mail (ex: exemplo.com.br): " DOMINIO
echo ""

if [ -z "$DOMINIO" ]; then
  echo "Erro: domínio não informado."
  exit 1
fi

echo -e "${BOLD}Analisando domínio de e-mail: ${CYAN}$DOMINIO${NC}"
echo "------------------------------------------"

### MX
echo -e "${CYAN}Servidores MX (entrada de e-mail):${NC}"
MX=$(dig +short "$DOMINIO" MX)
if [ -z "$MX" ]; then
  echo -e "  ${RED}Nenhum registro MX encontrado${NC}"
  ERROS+=("Falta de registro MX – e-mails não serão recebidos.")
else
  echo "$MX" | sort -n | sed 's/^/  - /'
fi
echo ""

### SPF
echo -e "${CYAN}Registro SPF (TXT):${NC}"
SPF=$(dig +short "$DOMINIO" TXT | grep spf)
if [ -z "$SPF" ]; then
  echo -e "  ${RED}SPF não encontrado${NC}"
  ERROS+=("SPF ausente – aumenta risco de rejeição e SPAM.")
else
  echo "  $SPF"
  if echo "$SPF" | grep -q "+all"; then
    echo -e "  ${RED}Atenção: uso de '+all' é perigoso${NC}"
    ERROS+=("SPF contém '+all' – autoriza qualquer IP, inseguro.")
  fi
fi
echo ""

### DKIM
echo -e "${CYAN}Registro DKIM (default._domainkey):${NC}"
DKIM=$(dig +short default._domainkey."$DOMINIO" TXT)
if [ -z "$DKIM" ]; then
  echo -e "  ${RED}DKIM não encontrado${NC}"
  ERROS+=("DKIM ausente – mensagens não são autenticadas digitalmente.")
else
  echo "  DKIM encontrado."
fi
echo ""

### DMARC
echo -e "${CYAN}Registro DMARC (_dmarc):${NC}"
DMARC=$(dig +short _dmarc."$DOMINIO" TXT)
if [ -z "$DMARC" ]; then
  echo -e "  ${RED}DMARC não encontrado${NC}"
  ERROS+=("DMARC ausente – ausência de política para SPF/DKIM.")
else
  echo "  $DMARC"
fi
echo ""

### Conexão IMAP (porta 993)
echo -e "${CYAN}Verificação de servidor IMAP (993 SSL/TLS):${NC}"
HOST_IMAP=$(echo "$MX" | head -1 | awk '{print $2}' | sed 's/\.$//')
if nc -z -w5 "$HOST_IMAP" 993 &>/dev/null; then
  echo "  Porta 993 aberta ✔"
else
  echo -e "  ${RED}Porta 993 fechada ou sem resposta${NC}"
  ERROS+=("Porta 993 indisponível – entrada de e-mails via IMAP pode estar bloqueada.")
fi
echo ""

### Conexão SMTP (porta 465)
echo -e "${CYAN}Verificação de servidor SMTP (465 SSL):${NC}"
if nc -z -w5 "$HOST_IMAP" 465 &>/dev/null; then
  echo "  Porta 465 aberta ✔"
else
  echo -e "  ${RED}Porta 465 fechada ou sem resposta${NC}"
  ERROS+=("Porta 465 indisponível – envio de e-mails via SMTP seguro pode falhar.")
fi
echo ""

### SSL SMTP
echo -e "${CYAN}Validação de SSL no servidor SMTP (porta 465):${NC}"
echo | openssl s_client -connect "$HOST_IMAP:465" -servername "$HOST_IMAP" 2>/dev/null | openssl x509 -noout -issuer -dates | sed 's/^/  /' || {
  echo -e "  ${RED}Falha ao obter certificado SSL do SMTP${NC}"
  ERROS+=("Certificado SSL do SMTP indisponível – pode impactar segurança.")
}
echo ""

### Resultado final
echo -e "${BOLD}${GREEN}Análise concluída.${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

### Exibição de erros
if [ ${#ERROS[@]} -gt 0 ]; then
  echo -e "${RED}${BOLD}Foram encontradas ${#ERROS[@]} anomalias ou erros:${NC}"
  for msg in "${ERROS[@]}"; do
    echo -e "${RED}- $msg${NC}"
  done
  echo ""
else
  echo -e "${GREEN}Nenhum erro encontrado. Configuração de e-mail parece adequada.${NC}"
fi