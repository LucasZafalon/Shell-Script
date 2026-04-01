#!/bin/bash

##############################################################################
#
# hostname.sh - Create By: Lucas Zafalon
# Script em shell utilizado para indentificar as maquinas na mesma rede
#
##############################################################################

# Cabeçalho da tabela
echo -e "Endereço\t\tTipoHW\tEndereçoHW\t\tFlags\tMascara\t\tIface\t\tHostname"
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
