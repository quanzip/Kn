FROM jboss/keycloak:16.1.0

RUN mkdir -p /opt/jboss/keycloak/modules/system/layers/keycloak/oracle/jdbc/main/
ADD ojdbc7.jar /opt/jboss/keycloak/modules/system/layers/keycloak/oracle/jdbc/main/ojdbc7.jar
ADD module.xml /opt/jboss/keycloak/modules/system/layers/keycloak/oracle/jdbc/main/module.xml
ADD session-limits.jar /opt/jboss/keycloak/standalone/deployments/session-limits.jar

# Update SSO Theme
RUN cp -r /opt/jboss/keycloak/themes /opt/jboss/keycloak/themes_bk
COPY ./themes /opt/jboss/keycloak/themes

# UPDATE standalone-ha.xml
USER jboss
RUN cp -r /opt/jboss/keycloak/standalone/configuration /opt/jboss/keycloak/standalone/configuration_bk
COPY --chown=jboss:root ./configuration /opt/jboss/keycloak/standalone/configuration