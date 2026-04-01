#!/bin/bash
##############################################################################
#  osint.sh  –  Diagnóstico completo de domínio / e‑mail
#  Create By: Lucas Zafalon
#  
#  Recursos inclusos (executados automaticamente):
#
#    • Consulta DNS (A, AAAA, MX, NS, TXT, CNAME ftp/www)
#    • WHOIS (status published, contato técnico ISSEM, datas)
#    • Validação SSL básica + detalhada (cadeia, emissor, validade)
#    • Varredura de subdomínios via crt.sh
#    • Scan de portas (80,443,22,21,3306,8080) com nmap
#    • Cabeçalhos HTTP (server / x‑powered‑by)
#    • Brute‑force de diretórios com gobuster
#    • Coleta de e‑mails públicos com theHarvester
#
#  Execução:  sudo ./auditoria_dominios.sh     (sudo requerido p/ nmap)
##############################################################################

######################## 0. Instalação de dependências #######################
DEPS=(dnsutils whois curl openssl netcat jq nmap gobuster theharvester)
MISSING=()
for pkg in "${DEPS[@]}"; do command -v "$pkg" &>/dev/null || MISSING+=("$pkg"); done

if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "Instalando dependências: ${MISSING[*]}"
  sudo apt-get update -qq
  sudo apt-get install -y "${MISSING[@]}" >/dev/null
fi
##############################################################################

######################## 1. Variáveis de cor #################################
BOLD="\e[1m"; UNDER="\e[4m"; NC="\e[0m"
RED="\e[91m"; GRN="\e[92m"; YLW="\e[93m"; CYA="\e[96m"
##############################################################################

######################## 2. Input ###########################################
clear
echo -e "${BOLD}${CYA}=========================================="
echo -e "        ANÁLISE DE DOMÍNIO E E‑MAIL"
echo -e "==========================================${NC}\n"
read -rp "Domínio a analisar: " DOMINIO
[[ -z $DOMINIO ]] && { echo "Domínio não informado."; exit 1; }
echo
##############################################################################

declare -a ERROS EXPLICACOES

######################## 3. Subdomínios (crt.sh) #############################
echo -e "${CYA}Subdomínios (crt.sh)${NC}"
CRT_JSON=$(curl -m 12 --connect-timeout 4 -sSf \
            "https://crt.sh/?q=%25.$DOMINIO&output=json" 2>/dev/null)

if [[ -z $CRT_JSON ]]; then
  echo -e "  ${RED}Sem resposta de crt.sh (timeout)${NC}"
  ERROS+=("crt.sh não respondeu em 12 s.")
else
  echo "$CRT_JSON" | jq -r '.[].name_value' | sort -u | sed 's/^/  - /'
fi
echo

######################## 4. IP A e classificação #############################
echo -e "${CYA}Endereço IP (A)${NC}"
IP_LIST=$(dig +short "$DOMINIO" A)
if [ -z "$IP_LIST" ]; then
  echo -e "  ${RED}Nenhum IP encontrado${NC}"
  ERROS+=("Domínio sem registro A.")
else
  for IP in $IP_LIST; do
    case $IP in
      169.57.171.119) MSG="Servidor Novo"; COR=$YLW ;;
      169.57.171.118) MSG="Servidor Menos Antigo"; COR=$GRN ;;
      52.117.194.181|52.117.194.183) MSG="Servidor Mais Antigo"; COR=$GRN ;;
      *) MSG="Servidor Desconhecido"; COR=$RED; ERROS+=("IP inesperado $IP");;
    esac
    echo -e "  - ${COR}$IP${NC} ($MSG)"
  done
fi
echo

######################## 5. IPv6 #############################################
echo -e "${CYA}IPv6 (AAAA)${NC}"
IPv6=$(dig +short "$DOMINIO" AAAA)
if [ -z "$IPv6" ]; then
  echo -e "  ${RED}Nenhum IPv6 configurado${NC}"
  ERROS+=("Sem registro AAAA.")
else
  echo "  - $IPv6"
fi
echo

######################## 6. CNAME ftp / www ##################################
echo -e "${CYA}CNAME (ftp / www)${NC}"
for sub in ftp www; do
  CNAME=$(dig +short "$sub.$DOMINIO" CNAME)
  [[ -z $CNAME ]] && echo -e "  ${RED}$sub não encontrado${NC}" \
                  || echo "  - $sub.$DOMINIO → $CNAME"
done
echo

######################## 7. MX ###############################################
echo -e "${CYA}Servidores MX${NC}"
MX=$(dig +short "$DOMINIO" MX)
if [ -z "$MX" ]; then
  echo -e "  ${RED}Sem MX${NC}"; ERROS+=("Domínio sem MX.")
else
  while read -r line; do
    if echo "$line" | grep -iqE "mailnuvem|skymail"; then
      echo -e "  - ${RED}${UNDER}$line${NC} (genérico)"
      ERROS+=("MX genérico detectado: $line")
    else
      echo "  - $line"
    fi
  done <<<"$MX"
fi
echo

######################## 8. NS ###############################################
echo -e "${CYA}Servidores DNS (NS)${NC}"
NS=$(dig +short "$DOMINIO" NS)
[[ -z $NS ]] && { echo -e "  ${RED}Sem NS${NC}"; ERROS+=("Sem NS."); } \
             || echo "$NS" | sed 's/^/  - /'
echo

######################## 9. TXT ##############################################
echo -e "${CYA}Registros TXT${NC}"
TXT=$(dig +short "$DOMINIO" TXT)
[[ -z $TXT ]] && { echo "  ${RED}Nenhum TXT${NC}"; ERROS+=("Sem TXT."); } \
              || echo "$TXT" | sed 's/^/  - /'
echo

######################## 10. WHOIS ###########################################
echo -e "${CYA}WHOIS${NC}"
WHO=$(whois "$DOMINIO")
STATUS=$(grep -iE "status" <<<"$WHO" | head -1)
if grep -qi "published" <<<"$STATUS"; then
  echo -e "  ${GRN}Status: published${NC}"
else
  echo -e "  ${RED}$STATUS${NC}"; ERROS+=("Status não é published.")
fi
grep -qi "ISSEM" <<<"$WHO" \
  && echo -e "  Contato técnico: ISSEM ${GRN}(OK)${NC}" \
  || { echo -e "  ${RED}Contato técnico não é ISSEM${NC}"; ERROS+=("Contato técnico ≠ ISSEM."); }
echo

######################## 11. Validação SSL simples ###########################
echo -e "${CYA}SSL (conexão HTTPS)${NC}"
curl -s -o /dev/null -w "%{http_code}" "https://$DOMINIO" | grep -q "^200" \
  && echo -e "  ${GRN}HTTPS responde 200 OK${NC}" \
  || { echo -e "  ${RED}HTTPS não responde corretamente${NC}"; ERROS+=("HTTPS falhou."); }
echo

######################## 12. SSL detalhado ###################################
echo -e "${CYA}SSL detalhado (tempo‑máx 15 s)${NC}"
if nc -z -w4 "$DOMINIO" 443 &>/dev/null; then
  if timeout 15 openssl s_client -connect "$DOMINIO:443" -servername "$DOMINIO" -tls1_2 2>/dev/null |
       openssl x509 -noout -subject -issuer -dates >/tmp/ssl_$DOMINIO.txt; then
    sed 's/^/  /' /tmp/ssl_$DOMINIO.txt
  else
    echo -e "  ${RED}Tempo excedido (15 s) ao obter certificado${NC}"
    ERROS+=("openssl s_client excedeu 15 s.")
  fi
else
  echo -e "  ${RED}Porta 443 inacessível${NC}"
fi
echo

######################## 13. Headers HTTP ####################################
echo -e "${CYA}Headers HTTP${NC}"
curl -sI "http://$DOMINIO" | grep -iE "server:|x-powered-by:" | sed 's/^/  /'
echo

######################## 14. Scan de portas nmap #############################
if command -v nmap &>/dev/null; then
  echo -e "${CYA}Scan de portas (80,443,22,21,3306,8080)${NC}"
  sudo nmap -Pn -p 80,443,22,21,3306,8080 --open -T4 "$IP_LIST" | sed 's/^/  /'
  echo
fi

######################## 15. Gobuster ########################################
if command -v gobuster &>/dev/null; then
  echo -e "${CYA}Gobuster (10 primeiros resultados)${NC}"
  gobuster dir -q -t 20 -w /usr/share/wordlists/dirb/common.txt \
    -u "http://$DOMINIO" -s "200,204,301,302" -r -z -k \
    -o /tmp/"$DOMINIO"_gobuster.txt >/dev/null
  head -n 10 /tmp/"$DOMINIO"_gobuster.txt | sed 's/^/  /'
  echo
fi

######################## 16. theHarvester ####################################
if command -v theHarvester &>/dev/null; then
  echo -e "${CYA}theHarvester (e‑mails google, 20 linhas)${NC}"
  theHarvester -d "$DOMINIO" -b google -l 20 2>/dev/null |
    grep -Eo "[A-Za-z0-9._%+-]+@$DOMINIO" | sort -u | sed 's/^/  - /'
  echo
fi

######################## 17. Resumo #########################################
echo -e "${BOLD}${GRN}Análise concluída.${NC}\n${CYA}==========================================${NC}\n"

if [ "${#ERROS[@]}" -gt 0 ]; then
  echo -e "${RED}${BOLD}Foram encontradas ${#ERROS[@]} anomalias:${NC}"
  printf '%s\n' "${ERROS[@]}" | sed 's/^/  - /'
  echo
fi
