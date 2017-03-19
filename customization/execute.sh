#!/bin/bash

# Usage: execute.sh [WildFly mode] [configuration file]
#
# The default mode is 'standalone' and default configuration is based on the
# mode. It can be 'standalone.xml' or 'domain.xml'.

JBOSS_HOME=/opt/jboss/wildfly
JBOSS_CLI=$JBOSS_HOME/bin/jboss-cli.sh
JBOSS_MODE=${1:-"standalone"}
JBOSS_CONFIG=${2:-"$JBOSS_MODE.xml"}
OPENPKW_DATA_SOURCE="OpenPKWDS"
OPENPKW_JNDI_NAME="openpkw"

CONNECTION_URL="jdbc:mysql://$OPENPKW_MYSQL_URI:$OPENPKW_MYSQL_PORT/$OPENPKW_MYSQL_DATABASE?useUnicode=true&amp;characterEncoding=UTF-8"
DATA_SOURCE=$OPENPKW_DATA_SOURCE
MYSQL_USER=$OPENPKW_MYSQL_USER
MYSQL_PASSWORD=$OPENPKW_MYSQL_PASSWORD
JNDI_NAME=java:/jboss/databases/$OPENPKW_JNDI_NAME



function wait_for_server() {
  until `$JBOSS_CLI -c ":read-attribute(name=server-state)" 2> /dev/null | grep -q running`; do
    sleep 1
  done
}

function wait_for_mysql() {
  while true; do
    echo "show databases" | mysql -h $OPENPKW_MYSQL_URI  -u $OPENPKW_MYSQL_USER --password=$OPENPKW_MYSQL_DATABASE -P $OPENPKW_MYSQL_PORT 2>&1 | grep "$OPENPKW_MYSQL_DATABASE" 
    result=$?
    if [[ result -eq 0 ]]; then
         echo "Found mysql database"   
      break
    fi
    sleep 1
    echo "."
 done
}



echo "=> Starting WildFly server"
$JBOSS_HOME/bin/$JBOSS_MODE.sh -b 0.0.0.0 -c $JBOSS_CONFIG &
 
echo "=> Waiting for the database mysql running"
wait_for_mysql

echo "=> Waiting for the server to boot"
wait_for_server

echo "=> Variables"
echo "=> OPENPKW_MYSQL_DATABASE: " $OPENPKW_MYSQL_DATABASE
echo "=> OPENPKW_MYSQL_USER: "  $OPENPKW_MYSQL_USER 
echo "=> OPENPKW_MYSQL_PASSWORD: " $OPENPKW_MYSQL_PASSWORD
echo "=> OPENPKW_MYSQL_URI: " $OPENPKW_MYSQL_URI
echo "=> OPENPKW_MYSQL_PORT ": $OPENPKW_MYSQL_PORT

echo "=> Connection URL: " $CONNECTION_URL
echo "=> Data Source: " $DATA_SOURCE
echo "=> JNDI name: " $JNDI_NAME
echo "=> Mysql User: " $MYSQL_USER
echo "=> Mysql Password: " $MYSQL_PASSWORD



$JBOSS_CLI -c << EOF
batch

# Add MySQL module
module add --name=com.mysql --resources=/opt/jboss/wildfly/customization/mysql-connector-java-5.1.31-bin.jar --dependencies=javax.api,javax.transaction.api

# Add MySQL driver
/subsystem=datasources/jdbc-driver=mysql:add(driver-name=mysql,driver-module-name=com.mysql,driver-xa-datasource-class-name=com.mysql.jdbc.jdbc2.optional.MysqlXADataSource)

# Add the datasourcee
data-source add --name=$DATA_SOURCE --driver-name=mysql --jndi-name=$JNDI_NAME --connection-url=$CONNECTION_URL --user-name=$MYSQL_USER --password=$MYSQL_PASSWORD --use-ccm=false --max-pool-size=25 --blocking-timeout-wait-millis=5000 --enabled=true

# Execute the batch
run-batch
EOF

# Deploy the WAR
cp /opt/jboss/wildfly/customization/openpkw.war $JBOSS_HOME/$JBOSS_MODE/deployments/openpkw.war

echo "=> Shutting down WildFly"
if [ "$JBOSS_MODE" = "standalone" ]; then
  $JBOSS_CLI -c ":shutdown"
else
  $JBOSS_CLI -c "/host=*:shutdown"
fi

# Is our database running wait for database



echo "=> Restarting WildFly"
$JBOSS_HOME/bin/$JBOSS_MODE.sh -b 0.0.0.0 -c $JBOSS_CONFIG
