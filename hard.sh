#!/usr/bin/env bash

##############################################################################
#
# har.sh - Create By: Lucas Zafalon
# Script em shell utilizado para analise de hardware e rede dos servidores
#
##############################################################################

###########################
###        Variaveis
###########################

VERSION="1.3"
CREATOR="Lucas_Zafalon"
TIME1=1
TIME2=2
TIME3=3

TEMPFILE=$(mktemp)

###########################
###        Collor
###########################

RESET="\033[0m"
GREEN="\033[32;1m"
PURPLE="\033[35;1m"
YELLOW="\033[33;1m"
REDP="\033[31;5m"
RED="\033[31;1m"
BLUE="\033[36;4m"

###########################
###        Funcoes
###########################

show_version() {
    echo -e "${BLUE}$(basename $0) $VERSION\nCreate by $CREATOR.${RESET}\n"
}

main() {
    echo "$(clear)"
    echo ""
    echo ""
    echo -e "${YELLOW}Registros atuais: \n"
    echo -e "Usuário: $(whoami)"
    echo -e "Diretório: $(pwd)"
    echo -e "Uptime: $(uptime)"
    echo -e "Máquina: $(hostname) $(hostname -I)"
    echo -e "Versão do sistema: $(cat /etc/*-release | grep "PRETTY_NAME")${RESET}"
    echo -e "${PURPLE}Inicio do Script: $(date)${RESET}"
}

check_dependences() {
    echo -e "${YELLOW}Verificando dependências...${RESET}"

    # Função para exibir a barra de carregamento
    progress_bar() {
        echo -n "["
        while true; do
            echo -n "="
            sleep 0.1
        done
    }

    # Verificar se pv está instalado
    if ! command -v pv &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y pv > /dev/null 2>&1
        elif command -v yum &> /dev/null; then
            sudo yum install -y pv > /dev/null 2>&1
        fi
    fi

    # Verificar e instalar smartctl
    if ! command -v smartctl &> /dev/null; then
        echo -e "${RED}Smartctl não encontrado. Instalando...${RESET}"
        progress_bar &
        PROGRESS_PID=$!
        if command -v apt-get &> /dev/null; then
            sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y smartmontools > /dev/null 2>&1
        elif command -v yum &> /dev/null; then
            sudo yum install -y smartmontools > /dev/null 2>&1
        fi
        kill $PROGRESS_PID
        echo -e "]\n"
    fi

    echo -e "${GREEN}Dependências verificadas.${RESET}"
}

################################################################################
###       Comandos
################################################################################

if [ "$(whoami)" != "root" ] ; then
echo -e "${REDP}Rode esse script como usuário root${RESET}"
exit 1
fi

check_dependences
sleep $TIME1

main
{
################################################################################

LSCPU=$(lscpu | head -n 14 | tail -n 13)

LSBLK=$(lsblk -i)

DF=$(df -H)

FREE=$(free -h)

DiskName=$(lsblk -o NAME,TYPE | awk '$2 == "disk" {print $1; exit}')

REBOOT=$(sudo last -n40 -xF shutdown reboot)

################################################################################|-Rede

IFCONF=$(ifconfig)


ROUTE=$(route -n)


WF=$(wf-info)

ARP=$(arp -v)

################################################################################



echo -e "\n###############################\++++++++++${GREEN}REQUISITOS MINIMOS${RESET}++++++++++/#############################\n"
sleep $TIME1

echo -e "${YELLOW}Servidor Central:
        Processador: i5 10ª Geração 10400f ou superior. Recomendado processadores da linha i9 ou i7. (4 - 6 Núcleos)
        Memória RAM mínimo: 16gb
        Memória RAM recomendado: 32GB.
        Armazenamento mínimo - SSD/NVME: 500Gb.
        Armazenamento recomendado - SSD/NVME: 1 TB ${RESET}\n"

echo -e "${YELLOW}Servidor loja:
        Processador: i5 10ª Geração 10400f ou superior. Recomendado processadores da linha i9 ou i7. (4 - 6 Núcleos)
        Memória RAM mínimo: 8gb
        Memória RAM recomendado: 16GB.
        Armazenamento mínimo - SSD/NVME: 500Gb.
        Armazenamento recomendado - SSD/NVME: 1 TB ${RESET}\n"

echo -e "\n#######################################################\++++++++++++++++++++|${GREEN}Informações sobre a CPU\n${RESET}"
sleep $TIME2

echo -e "[${GREEN}lscpu${RESET}]\n"
echo "$LSCPU"
sleep $TIME1

echo -e "\n#######################################################\++++++++++++++++++++|${GREEN}Estrutura de blocos e armazenamento\n${RESET}"
sleep $TIME2

echo -e "[${GREEN}lsblk -i${RESET}] - Repartições do disco\n"
echo -e "$LSBLK\n"
sleep $TIME1

echo -e "[${GREEN}df -h${RESET}] - Uso de espaço em disco\n"
echo -e "$DF\n"
sleep $TIME1

echo -e "[${GREEN}free -h${RESET}] - Uso de memória RAM e swap\n"
echo -e "$FREE\n"
sleep $TIME1


echo -e "\n#######################################################\++++++++++++++++++++|${GREEN}Ultimos 40 Desligamentos\n${RESET}"
sleep $TIME2

echo -e "[${GREEN}last -n40 -xF shutdown reboot${RESET}]\n"
echo -e "$REBOOT\n"

echo -e "\n#######################################################\++++++++++++++++++++|${GREEN}Verificação Smart\n${RESET}"
sleep $TIME2

echo -e "[${GREEN}smartctl -a /dev/"$DiskName"${RESET}]\n"

echo "Verificando informações de discos com smartctl..."

# Tentar o primeiro método de verificação com smartctl -x
sudo -k -S /bin/bash -c 'for disk in $(lsblk -o TYPE,NAME | grep disk | sed "s/  */ /" | cut -d" " -f2); do
    echo "===== smartctl -x /dev/$disk"
    result1=$(sudo smartctl -x /dev/"$disk" 2>&1)
    
    if [[ "$?" -ne 0 ]]; then
        echo "Primeira verificação falhou, tentando com parâmetros alternativos..."
        
        # Tentar fallback com smartctl -a e cciss,0
        result2=$(sudo smartctl -a /dev/"$disk" -d cciss,0 2>&1)
        
        if [[ "$?" -ne 0 ]]; then
            echo "Segunda verificação falhou, tentando com smartctl -a sem cciss,0..."
            result3=$(sudo smartctl -a /dev/"$disk" 2>&1)
            echo "$result3"
        else
            echo "$result2"
        fi
    else
        echo "$result1"
    fi
done'


sleep $TIME2
echo -e "\n#######################################################\++++++++++++++++++++|${GREEN}Erros de memória - hs_err\n${RESET}"

cd /usr/wildfly/bin 2>/dev/null || echo -e "${GREEN}Diretório /usr/wildfly/bin não encontrado"

# Busca e lista os arquivos hs_err
hs_err_files=$(find . -iname "hs_err_*" -exec ls -lsth {} + 2>/dev/null)

if [[ -n "$hs_err_files" ]]; then
    echo -e "${REDP}Apresentado possíveis erros de memória:${RESET}"
    echo "$hs_err_files"
else
    echo -e "${GREEN}\nNenhum 'hs_err' encontrado.${RESET}"
fi

# Busca e lista os arquivos heapDump
heap_dump_files=$(find . -iname "heapDump*" -exec ls -lsth {} + 2>/dev/null)

if [[ -n "$heap_dump_files" ]]; then
    echo -e "${REDP}Apresentado arquivos heapDump encontrados:${RESET}"
    echo "$heap_dump_files"
else
    echo -e "${GREEN}\nNenhum 'heapDump' encontrado.${RESET}"
fi

echo -e "\n#######################################################\++++++++++++++++++++|${GREEN}Base Corrompida - Segmentation\n${RESET}"

for version in 9.6 14; do
    log_dir="/var/lib/pgsql/${version}/data/pg_log"
    if [[ -d "$log_dir" ]]; then
        cd "$log_dir" 2>/dev/null || continue
        segmentation_logs=$(ls -lsth | grep "Segmentation" postgresql-* | cut -d':' -f1 | uniq -dc)
        if [[ -n "$segmentation_logs" ]]; then
            echo "${REDP}Apresentado Segmentation nos seguintes log's do PG BASE CORROMPIDA! (Versão $version)${RESET}"
            echo "$segmentation_logs"
        else
            echo -e "${GREEN}\nNenhuma 'segmentation' encontrada\n${RESET}"
        fi
    else
        echo -e "${GREEN}Diretório /var/lib/pgsql/${version}/data/pg_log não encontrado${RESET}"
    fi
done

echo -e "\n#######################################################\++++++++++++++++++++|${GREEN}Verificação de Rede\n${RESET}"
sleep $TIME2

echo -e "[${GREEN}ifconfig${RESET}] - Interfaces de rede\n"
echo -e "$IFCONF\n"
sleep $TIME1

echo -e "[${GREEN}route -n${RESET}] - Rotas\n"
echo -e "$ROUTE\n"
sleep $TIME1

echo -e "[${GREEN}Placas de rede${RESET}] - Configurações das placas de rede\n"
sleep $TIME1
# Identificando as interfaces de rede
if command -v ifconfig &> /dev/null
then
    # ifconfig para listar interfaces de rede
    interfaces=($(ifconfig -a | grep -o '^[a-zA-Z0-9]\+'))
else
    # ip como alternativa para listar interfaces de rede
    interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
fi

# Caminhos de configuração para CentOS e Oracle Linux
config_paths=(
    "/etc/sysconfig/network-scripts/ifcfg-"
    "/etc/NetworkManager/system-connections/"
)

# Iterando sobre as interfaces encontradas
for interface in "${interfaces[@]}"; do
    for config_path in "${config_paths[@]}"; do
        config_file="${config_path}${interface}"

        if [ -f "$config_file" ]; then
            echo -e "[${BLUE}Placa de rede ${interface}${RESET}]\n$"
            cat "$config_file"
            echo -e "\n"
        else
            echo -e "\n${GREEN}Não foi possível localizar as configurações da placa de rede${RESET}[${interface}]\n"
        fi
    done
done

echo -e "\n#######################################################\++++++++++++++++++++|${GREEN}Wildfly info\n${RESET}"

sleep $TIME1
echo -e "[${GREEN}wf -info${RESET}] - Wildfly\n"

if command -v wf-info &> /dev/null
then
    
    echo -e "$WF\n"
else
    
    echo -e "${GREEN}O wildfly não se encontra instalado${RESET}"
fi

echo ""

read -p "Deseja verificar os dispositivos na mesma rede? (Y/N): " resposta

case "$resposta" in
    [Yy]* )
        echo -e "${GREEN}Continuando com a verificação...${RESET}"

echo -e "\n#######################################################\++++++++++++++++++++|${GREEN}Dispositivos na mesma rede\n${RESET}"
sleep $TIME2

# Executa o comando arp -v e processa a saída
arp -v | while read line; do
    # Extrai o endereço IP da linha
    ip=$(echo "$line" | awk '{print $1}')
    
    # Pula as linhas que não têm um endereço IP válido
    if [[ "$ip" == "Address" || -z "$ip" ]]; then
        continue
    fi
    
    # Tenta resolver o hostname para o IP usando nmblookup
    hostname=$(nmblookup -A "$ip" | awk -F' ' '/<20>/{print $1}')
    
    # Se o hostname não foi encontrado, define como "Desconhecido"
    if [ -z "$hostname" ]; then
        hostname="Desconhecido"
    fi
    
    # Imprime a linha original do arp -v junto com o hostname
    echo -e "$line\t$hostname"
done


echo -e "\n"

    
    ;;
    [Nn]* )
        echo -e "${REDP}Verificação cancelada.${RESET}"

        
        exit 0
        ;;
    * )
        echo -e "${RED}Opção inválida. Saindo...${RESET}"
        exit 1
        ;;
esac

show_version


} 2>&1 | tee "$TEMPFILE"

# Enviar o conteúdo do arquivo temporário para o Termbin
LINK=$(cat "$TEMPFILE" | nc termbin.com 9999)

# Exibir o link no terminal
echo "Link para visualização: $LINK"

# Remover o arquivo temporário após o uso
rm -f "$TEMPFILE"
