#!/bin/bash

#Leer cada linea del archivo domain
while IFS= read -r domain; do
#Ejecutar script
    python scrapping-asn.py "$domain" 
done < domains