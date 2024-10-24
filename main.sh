#!/bin/bash

# Usar figlet para mostrar el nombre
figlet -f slant suprimoware

# Comprobar si se pasó un argumento
if [ -z "$1" ]; then
    echo "Error: No enviaste un dominio"
    echo "Uso: ./main.sh <dominio>"
    exit 1
fi

# Asignar el dominio a una variable
domain=$1
echo "Escanenado $domain"

# Estructura de carpetas 
timestamp=$(date +"%Y-%m-%d_%H:%M:%S")
ruta_resultados=./resultados/$domain/$timestamp
mkdir -p "$ruta_resultados"
mkdir -p $ruta_resultados/raw
mkdir -p $ruta_resultados/clean

# Análisis infraestructura

dig +short A $domain > $ruta_resultados/clean/IP
dig +short MX $domain > $ruta_resultados/clean/MX
dig +short TXT $domain > $ruta_resultados/clean/TXT
dig +short NS $domain > $ruta_resultados/clean/NS
dig +short SRV $domain > $ruta_resultados/clean/SRV
dig +short AAAA $domain > $ruta_resultados/clean/AAAA
dig +short CNAME $domain > $ruta_resultados/clean/CNAME
dig +short SOA $domain > $ruta_resultados/clean/SOA


echo "Extrayendo rangos de IP"
# Revisar y eliminar archivos vacíos en la carpeta /clean
for file in "$ruta_resultados/clean"/*; do
  if [ ! -s "$file" ]; then
    echo "Eliminando archivo vacío: $file"
    rm "$file"
  fi
done

# Archivos en raw

whois $domain > $ruta_resultados/raw/whois
dig $domain > $ruta_resultados/raw/dig

curl -I https://$domain > $ruta_resultados/raw/headers
cat $ruta_resultados/raw/headers | grep -i 'server' | awk '{ print $2 }' > $ruta_resultados/clean/header_server

# Scan completo
sudo nmap -sS -Pn -sV -sC -O -vv --open --reason --min-hostgroup 16 --min-rate 100 --max-parallelism=10 -F -oA output_nmap scanme.nmap.org 

# Revisar y eliminar archivos vacíos en la carpeta /clean
for file in "$ruta_resultados/clean"/*; do
  if [ ! -s "$file" ]; then
    echo "Eliminando archivo vacío: $file"
    rm "$file"
  fi
done



