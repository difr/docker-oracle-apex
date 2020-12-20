# REQUIRED FILES TO BUILD THIS IMAGE
# ----------------------------------
#   - oracle-database-xe-18c-1.0-1.x86_64.rpm
#       https://www.oracle.com/technetwork/database/database-technologies/express-edition/downloads/index.html
#   - jdk-8u241-linux-x64.tar.gz
#       https://www.oracle.com/java/technologies/javase/javase-jdk8-downloads.html
#   - apex_19.2.zip
#       http://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html
#   - ords-19.4.0.352.1226.zip
#       http://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html
#   - apache-tomcat-9.0.31.tar.gz
#       https://tomcat.apache.org/download-90.cgi
#
# COPY TO "./install/distrs"
#

FROM oraclelinux:7-slim

MAINTAINER Dmitri Frolov <dialfr@gmail.com>

# Environment variables
ENV ORACLE_BASE=/opt/oracle \
    ORACLE_HOME=/opt/oracle/product/18c/dbhomeXE \
    ORACLE_SID=XE \
    ORACLE_PDB=XEPDB1 \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/u02/tomcat

# Use second ENV so that variable get substituted
ENV JAVA_HOME=$ORACLE_HOME/jdk \
    PATH=$ORACLE_HOME/jdk/bin:$ORACLE_HOME/bin:$PATH

# Copy install files
COPY install/ /tmp/install/

RUN chmod u+x /tmp/install/scripts/*.sh && \
    /tmp/install/scripts/install.sh

EXPOSE 22 1521 8009 8080

ENTRYPOINT ["/root/entrypoint.sh"]
