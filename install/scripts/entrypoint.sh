#!/bin/bash -xe

startup () {
  /etc/init.d/oracle-xe-18c start
  /opt/tomcat/bin/catalina.sh start
}
shutdown () {
  /opt/tomcat/bin/catalina.sh stop
  /etc/init.d/oracle-xe-18c stop
}
trap shutdown EXIT
trap exit SIGINT SIGKILL SIGTERM

if [ ! -d /u02/oracle ]; then
  mkdir -p /u02/oracle
  chown -R oracle:oinstall /u02/oracle
  su - oracle -c /home/oracle/setup_oracle.sh
  cp -af /etc/oratab /u02/oracle/oratab
else
  cp -af /u02/oracle/oratab /etc/oratab
fi
if [ ! -d /u02/tomcat ]; then
  mkdir -p /u02/tomcat/{bin,logs,temp,work}
  echo 'export CATALINA_OPTS="$CATALINA_OPTS -Xms1536m -Xmx1536m -server"' >/u02/tomcat/bin/setenv.sh
  cp -ar $CATALINA_HOME/conf /u02/tomcat/
  cp -ar $CATALINA_HOME/webapps /u02/tomcat/
  TOMCAT_ADM_PWD=`cat /dev/urandom | tr -dc '[:alnum:]' | head -c 10`
  sed -i -r "s|##ADM_PWD##|$TOMCAT_ADM_PWD|" /u02/tomcat/conf/tomcat-users.xml
  echo "TOMCAT_ADM_PWD=$TOMCAT_ADM_PWD" >/u02/tomcat/.pwds
  cp $ORACLE_BASE/ords/ords.war /u02/tomcat/webapps/apex.war
  ln -sT $ORACLE_HOME/apex/images /u02/tomcat/webapps/i
fi

ORACLE_LOG=$ORACLE_BASE/diag/rdbms/${ORACLE_SID,,}/$ORACLE_SID/trace/alert_$ORACLE_SID.log
TOMCAT_LOG=$CATALINA_BASE/logs/catalina.out
#comon
tail -F $ORACLE_LOG $TOMCAT_LOG &
TAIL_PID=$!
#lets go
startup
wait $TAIL_PID
