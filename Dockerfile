FROM jboss/wildfly:latest

ADD customization /opt/jboss/wildfly/customization/
ADD bin/openpkw.war /opt/jboss/wildfly/customization/openpkw.war

CMD ["/opt/jboss/wildfly/customization/execute.sh"]
