#!/bin/bash
   # reading application configuration file
   IFS=$'\n' read -d '' -r -a requirements < /var/www/Registration/config/application_requirements.yml
   
   # initialize variables
   RB_VERSION=`echo "${requirements[0]}" | cut -d':' -f2`
   RG_VERSION=`echo "${requirements[1]}" | cut -d':' -f2`
   DB_NAME=`echo "${requirements[2]}" | cut -d':' -f2`
   BD_VERSION=`echo "${requirements[3]}" | cut -d':' -f2`
   
   # check already installed requirements
   RB_INSTALLED_VERSION=`echo "$(ruby -e 'print RUBY_VERSION')"` 
   RG_INSTALLED_VERSION=`echo "$(gem -v)"`

    
   if [ -f /etc/init.d/mysql* ]; then
     FIRST_DB_INSTALLED_NAME='mysql'
   else 
     FIRST_DB_INSTALLED_NAME='mysql not installed'
   fi

   if [ -f /usr/bin/couchdb ]; then
     SECOND_DB_INSTALLED_NAME='couchdb'
   else 
     SECOND_DB_INSTALLED_NAME='couchdb not installed'
   fi

   BUNDLER_INSTALLED_VERSION=`echo "$(gem list -i bundler --version 1.6.7)"`

   if $BUNDLER_INSTALLED_VERSION; then
     BD_INSTALLED_VERSION='1.6.2'
   else 
     BD_INSTALLED_VERSION='not correct version'
   fi
    

echo  $RB_VERSION
echo  $RG_VERSION
echo  $DB_NAME
echo  $BD_VERSION

echo $RB_INSTALLED_VERSION
echo $RG_INSTALLED_VERSION
echo $FIRST_DB_INSTALLED_NAME
echo $SECOND_DB_INSTALLED_NAME
echo $BD_INSTALLED_VERSION


