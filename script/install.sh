#!/bin/bash

IFS=$'\n' read -d '' -r -a requirements < /var/www/Registration/config/application_requirements.yml

for r in "${requirements[@]}"
do
   echo "$r"
done
