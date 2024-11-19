#!/bin/bash
#HACER OTRO BUCLE PARA HACER LOS RANGOS, GOWITNESS, MIRAR QUE SE CREAN BIEN LAS CARPETAS, IMPLEMENTA WHATWEB -i Y RANGOS BUSQUEDA, Hay que refinar amass y limpiarlo
# Usar figlet para mostrar el nombre del script
figlet -f slant suprimoware

# Comprobar si se pasó un argumento (dominio)
if [ -z "$1" ]; then
    echo "Error: No enviaste un dominio"
    echo "Uso: ./main.sh <dominio>"
    exit 1
fi

# Asignar el dominio a una variable
dominio=$1
echo "Escaneando $dominio"

# Estructura de carpetas para almacenar resultados
timestamp=$(date +"%Y-%m-%d_%H:%M:%S")  # Crear una marca de tiempo
ruta_resultados=./resultados/$dominio/$timestamp  # Definir la ruta para los resultados
mkdir -p "$ruta_resultados/raw" 
mkdir -p "$ruta_resultados/clean"  # Crear carpeta para resultados procesados

# Análisis de infraestructura utilizando comandos dig en paralelo
{
    dig +short A $dominio > "$ruta_resultados/clean/IP" &
    dig +short MX $dominio > "$ruta_resultados/clean/MX" &
    dig +short TXT $dominio > "$ruta_resultados/clean/TXT" &
    dig +short NS $dominio > "$ruta_resultados/clean/NS" &
    dig +short SRV $dominio > "$ruta_resultados/clean/SRV" &
    dig +short AAAA $dominio > "$ruta_resultados/clean/AAAA" &
    dig +short CNAME $dominio > "$ruta_resultados/clean/CNAME" &
    dig +short SOA $dominio > "$ruta_resultados/clean/SOA" &
    dig +short txt _dmarc.$dominio > "$ruta_resultados/clean/DMARC" &
    dig +short txt default._domainkey.$dominio > "$ruta_resultados/clean/DKIM" &
    wait  # Esperar a que todos los comandos terminen
}

# Dominios y subdominios
#echo "Extrayendo rangos de IP"
while IFS= read -r ip; do
    # Realizar un whois para cada IP y extraer el rango
    whois -b "$ip" | grep 'inetnum' | awk '{print $2, $3, $4}' >> "$ruta_resultados/clean/rangos_ripe"
done < "$ruta_resultados/clean/IP"  # Leer las IPs desde el archivo 

#echo "Realizando whois"
whois $dominio > "$ruta_resultados/raw/whois" &  # Obtener información WHOIS del dominio
#echo "Realizando dig"
dig $dominio > "$ruta_resultados/raw/dig" &  # Obtener información detallada del dominio

# Obtener los encabezados de la respuesta HTTP de manera paralela
curl -sI https://$dominio > "$ruta_resultados/raw/headers" &

# Filtrar y guardar el servidor en el archivo correspondiente
{
    cat "$ruta_resultados/raw/headers" | grep -i Server | awk '{ print $2 }' > "$ruta_resultados/clean/header_server" &
    wait  # Esperar a que termine el proceso de curl
}

# Realizar un escaneo de puertos con nmap
sudo nmap -sS -Pn -sV -sC -O -vv --open --reason --min-hostgroup 16 --min-rate 100 --max-parallelism=10 -F -oA "$ruta_resultados/raw/nmap" &> /dev/null &

# Herramientas
#python scrapping-asn.py $dominio | sed '1,2d;$d;$d' > "$ruta_resultados/clean/ASN"
ctfr -d $dominio -o "$ruta_resultados/raw/ctfr_raw" &> /dev/null &
katana -u $dominio -o "$ruta_resultados/raw/katana_raw" &> /dev/null &
gau $dominio --o "$ruta_resultados/raw/gau_raw" &> /dev/null &
#amass enum -d $dominio -o "$ruta_resultados/raw/amass_raw" &> /dev/null & 
wait  # Esperar a que terminen los escaneos


#if [[ -s "$ruta_resultados/raw/ctfr_raw" || -s "$ruta_resultados/raw/katana_raw" || -s "$ruta_resultados/raw/gau_raw" ]]; then
#    cat "$ruta_resultados/raw/ctfr_raw" "$ruta_resultados/raw/katana_raw" "$ruta_resultados/raw/gau_raw" | sort -u | httpx -silent -o "$ruta_resultados/clean/resultados_tools" &> /dev/null
#else
#    echo "No se encontraron resultados para unificar."
#fi

# Unificar resultados en limpio sin duplicados y ordenado, validando URLs con httpx
cat "$ruta_resultados/raw/ctfr_raw" "$ruta_resultados/raw/katana_raw" "$ruta_resultados/raw/gau_raw" | sort -u | httpx -silent -o "$ruta_resultados/clean/resultados_tools" &> /dev/null

# Revisar y eliminar archivos vacíos en la carpeta /clean
for file in "$ruta_resultados/clean"/*; do
  if [ ! -s "$file" ]; then
    echo "Eliminando archivo vacío: $file"  # Informar sobre la eliminación
    rm "$file"  # Eliminar el archivo vacío
  fi
done

# Crear el archivo con el encabezado del dominio en formato Markdown
echo "# $dominio" > "resultado.md"
echo "## Infraestructura" >> "resultado.md"

# Función para agregar contenido de archivos a una sección específica
function agregar_registros {
    tipo_registro=$1  # Tipo de registro (por ejemplo, NS, IP)
    archivo_registro="$ruta_resultados/clean/$tipo_registro"  # Ruta del archivo correspondiente
    
    # Solo agregar la sección si el archivo tiene contenido
    if [[ -s "$archivo_registro" ]]; then
        echo "### $tipo_registro" >> "resultado.md"  # Agregar encabezado de sección
        
        # Cambiar aquí para añadir tres # al inicio de cada línea
        sed 's/^/#### /' "$archivo_registro" >> "resultado.md"  # Agregar el contenido del archivo con formato
        
        echo "" >> "resultado.md"  # Añadir una línea en blanco para separar secciones
    fi
}

# Agregar diferentes tipos de registros
agregar_registros "NS"
agregar_registros "IP"
agregar_registros "MX"
agregar_registros "TXT"
agregar_registros "CNAME"
agregar_registros "SRV"
agregar_registros "AAAA"
agregar_registros "SOA"
agregar_registros "DMARC"
agregar_registros "DKIM"
agregar_registros "header_server"
agregar_registros "rangos_ripe"

# Generar el mapa mental con markmap
markmap "resultado.md" --no-open  # Crear un mapa mental basado en el archivo Markdown
