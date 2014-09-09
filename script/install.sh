#!/bin/bash

IFS=$'\n' read -d '' -r -a requirements < /var/www/Registration/config/application_requirements.yml

   RB_VERSION=`echo "${requirements[0]}" | cut -d':' -f2`
   RG_VERSION=`echo "${requirements[1]}" | cut -d':' -f2`
   DB_NAME=`echo "${requirements[2]}" | cut -d':' -f2`
   BD_VERSION=`echo "${requirements[3]}" | cut -d':' -f2`

   RB_INSTALLED_VERSION=`echo "$(ruby -e 'print RUBY_VERSION')"`
   RG_INSTALLED_VERSION=`echo "$(gem -v)"` 

echo  $RB_VERSION
echo  $RG_VERSION
echo  $DB_NAME
echo  $BD_VERSION

echo $RB_INSTALLED_VERSION
echo $RG_INSTALLED_VERSION


