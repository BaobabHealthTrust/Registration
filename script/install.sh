#!/bin/bash
# check if stacktrace is passed and set it to true
# stacktrace gives useful debug information
if [[ ! -z "$4" ]]; then
    if [ "$4" == "true" ]; then
        set -x
    fi
fi

# set colors and message
red='\e[0;31m'
green='\e[0;32m'
NC='\e[0m'
MSG="and run $0 { ENVIRONMENT SITE MACHINE_PASSWORD STACKTRACE=true } again"
ENV=$1
SITE=$2

# check if application requirements file is available then set it  
if [ ! -f config/application_requirements.yml ] ; then
	cp config/application_requirements.yml.example config/application_requirements.yml
fi
   
# read application configuration file
IFS=$'\n' read -d '' -r -a requirements < /var/www/Registration/config/application_requirements.yml

# initialize variables
RB_VERSION=`echo "${requirements[0]}" | cut -d':' -f2`
RG_VERSION=`echo "${requirements[1]}" | cut -d':' -f2`
DB_NAME=`echo "${requirements[2]}" | cut -d':' -f2`
BD_VERSION=`echo "${requirements[3]}" | cut -d':' -f2`

#### check already installed requirements
   
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
BUNDLER_INSTALLED_VERSION=`echo "$(gem list -i bundler --version $BD_VERSION)"`
if $BUNDLER_INSTALLED_VERSION; then
    BD_INSTALLED_VERSION=$BD_VERSION
else 
    BD_INSTALLED_VERSION='not correct version'
fi

#check if nginx is installed
if [ ! -f /opt/nginx/conf/nginx.conf ]; then
    echo -e "${red}Nginx not installed${NC}"
    echo "Please install nginx with passenger $MSG"
    exit 0
else
    echo "Nginx installed"
fi 
    
#compare installed ruby with specified ruby
if [ "$RB_VERSION" == "$RB_INSTALLED_VERSION" ] ; then
    echo "ruby $RB_INSTALLED_VERSION already installed"
else 
    echo -e "${red}ruby $RB_VERSION not installed${NC}"
    echo "Please install ruby $RB_VERSION $MSG"
    exit 0
fi
#compare installed rubygems with specified rubygems
if [ "$RG_VERSION" == "$RG_INSTALLED_VERSION" ] ; then
    echo "rubygems $RG_INSTALLED_VERSION already installed"
else 
    echo -e "${red}rubygems $RG_VERSION not installed${NC}"
    echo "Please install rubygems $RG_VERSION $MSG"
    exit 0
fi

#compare installed databases with specified database
if [ "$FIRST_DB_INSTALLED_NAME" == "$DB_NAME" ] || [ "$SECOND_DB_INSTALLED_NAME" == "$DB_NAME" ] ; then
    echo "$DB_NAME database already installed"
else 
    echo -e "${red}$DB_NAME database not installed${NC}"
    echo "Please install $DB_NAME database $MSG"
    exit 0
fi

#compare bundler versions
if [ "$BD_VERSION" == "$BD_INSTALLED_VERSION" ] ; then
    echo "bundler $BD_VERSION already installed"
else 
    echo -e "${red}bundler $BD_VERSION not installed${NC}"
    #installing bundler
    echo 'Installing now'
    BN_INSTALL=`echo "$(gem install bundler -v $BD_VERSION)"`
    echo "Successfully installed bundler-$BD_VERSION"
fi

###installing application dependencies and gems
#installing application dependencies
echo 'Installing application dependencies'
DP_INSTALL=`echo "$3" | sudo -S apt-get -y install build-essential libopenssl-ruby git-core libmysql-ruby libmysqlclient-dev libxslt-dev libxml2-dev`
echo "$DP_INSTALL"
echo 'Finished installing application dependencies'
#installing gems   
echo 'Installing required gems'
BD_INSTALL=`bundle install`
echo 'Finished installing gems'

#setting up database and application
if [ "mysql" == "$DB_NAME" ] ; then
    usage(){
        echo "Usage: $0 ENVIRONMENT SITE"
        echo
        echo "ENVIRONMENT should be: development|test|production"
    } 

    if [ -z "$ENV" ] || [ -z "$SITE" ] ; then
        usage
        exit 0
    fi

    if [ ! -f config/database.yml ] ; then
        cp config/database.yml.example config/database.yml
    fi

    USERNAME=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['username']"`
    PASSWORD=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['password']"`
    DATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['database']"`
    HOST=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['host']"`

    echo "DROP DATABASE $DATABASE;" | mysql --host=$HOST --user=$USERNAME --password=$PASSWORD
    echo "CREATE DATABASE $DATABASE;" | mysql --host=$HOST --user=$USERNAME --password=$PASSWORD


    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/openmrs_1_7_2_concept_server_full_db.sql
    #echo "schema additions"
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/schema_bart2_additions.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/bart2_views_schema_additions.sql
    #echo "defaults"
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/defaults.sql
    #echo "user schema modifications"
    #mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/user_schema_modifications.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/malawi_regions.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/mysql_functions.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/drug_ingredient.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/pharmacy.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/national_id.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/weight_for_heights.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/data/${SITE}/${SITE}.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/data/${SITE}/tasks.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/moh_regimens_only.sql
    #mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/regimen_indexes.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/retrospective_station_entries.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/create_dde_server_connection.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/openmrs_metadata_1_7.sql


    #mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/privilege.sql
    #mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/bart2_role_privileges.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/migrate/create_weight_height_for_ages.sql
    mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/migrate/insert_weight_for_ages.sql
    #mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/regimens.sql

    #rake openmrs:bootstrap:load:defaults RAILS_ENV=$ENV
    #rake openmrs:bootstrap:load:site SITE=$SITE RAILS_ENV=production#

    echo "Succesfully created and configured database"
elif [ "couchdb" == "$DB_NAME" ] ; then
    `rake dde:setup`
else 
    exit 0
fi

