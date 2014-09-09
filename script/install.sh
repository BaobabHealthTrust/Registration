#!/bin/bash
   # reading application configuration file
   IFS=$'\n' read -d '' -r -a requirements < /var/www/Registration/config/application_requirements.yml

   #set colors
   red='\e[0;31m'
   green='\e[0;32m'
   NC='\e[0m'
   
   # initialize variables
   RB_VERSION=`echo "${requirements[0]}" | cut -d':' -f2`
   RG_VERSION=`echo "${requirements[1]}" | cut -d':' -f2`
   DB_NAME=`echo "${requirements[2]}" | cut -d':' -f2`
   BD_VERSION=`echo "${requirements[3]}" | cut -d':' -f2`
   
   # check already installed requirements
   
   #check for ruby version
   RB_INSTALLED_VERSION=`echo "$(ruby -e 'print RUBY_VERSION')"` 

   #check for rubygems version
   RG_INSTALLED_VERSION=`echo "$(gem -v)"`

   #check for mysql
   if [ -f /etc/init.d/mysql* ]; then
     FIRST_DB_INSTALLED_NAME='mysql'
   else 
     FIRST_DB_INSTALLED_NAME='mysql not installed'
   fi
   
   #check for couchdb
   if [ -f /usr/bin/couchdb ]; then
     SECOND_DB_INSTALLED_NAME='couchdb'
   else 
     SECOND_DB_INSTALLED_NAME='couchdb not installed'
   fi
   #check for bundler gem
   BUNDLER_INSTALLED_VERSION=`echo "$(gem list -i bundler --version 1.6.2)"`
   if $BUNDLER_INSTALLED_VERSION; then
     BD_INSTALLED_VERSION='1.6.2'
   else 
     BD_INSTALLED_VERSION='not correct version'
   fi
    
   #compare installed ruby with specified ruby
   if [ "$RB_VERSION" == "$RB_INSTALLED_VERSION" ] ; then
     echo "ruby $RB_INSTALLED_VERSION already installed"
   else 
     echo -e "${red}ruby $RB_VERSION not installed${NC}"
     exit 0
   fi
    #compare installed rubygems with specified rubygems
   if [ "$RG_VERSION" == "$RG_INSTALLED_VERSION" ] ; then
     echo "rubygems $RG_INSTALLED_VERSION already installed"
   else 
     echo -e "${red}rubygems $RG_VERSION not installed${NC}"
     exit 0
   fi

   #compare installed databases with specified database
   if [ "$FIRST_DB_INSTALLED_NAME" == "$DB_NAME" ] || [ "$SECOND_DB_INSTALLED_NAME" == "$DB_NAME" ] ; then
     echo "$DB_NAME database already installed"
   else 
     echo -e "${red}$DB_NAME database not installed${NC}"
     exit 0
   fi

   if [ "$BD_VERSION" == "$BD_INSTALLED_VERSION" ] ; then
     echo "bundler $BD_VERSION already installed"
   else 
     echo -e "${red}bundler $BD_VERSION not installed${NC}"
     exit 0
   fi

#echo  $RB_VERSION
#echo  $RG_VERSION
#echo  $DB_NAME
#echo  $BD_VERSION

#echo $RB_INSTALLED_VERSION
#echo $RG_INSTALLED_VERSION
#echo $FIRST_DB_INSTALLED_NAME
#echo $SECOND_DB_INSTALLED_NAME
#echo $BD_INSTALLED_VERSION


