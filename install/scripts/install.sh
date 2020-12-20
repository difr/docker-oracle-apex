#!/bin/bash -xe

export ORACLE_DOCKER_INSTALL=true
DISTRS_DIR=/tmp/install/distrs
OTHERS_DIR=/tmp/install/others
SCRIPTS_DIR=/tmp/install/scripts


ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime

yum update -y
yum-config-manager --enable ol7_addons >/dev/null
yum install -y oracle-epel-release-el7
yum-config-manager --enable ol7_developer_EPEL >/dev/null
yum repolist

yum reinstall -y glibc-common
echo LANG=en_US.utf-8 >>/etc/environment
echo LC_ALL=en_US.utf-8 >>/etc/environment

yum install -y oracle-database-preinstall-18c rlwrap
#sed -i -r 's/^(session\s+required\s+pam_limits.so)/#\1/' /etc/pam.d/*

DISTR=$DISTRS_DIR/oracle-database-xe-18c-1.0-1.x86_64.rpm
yum localinstall -y $DISTR
rm $DISTR
rm -rf $ORACLE_BASE/{admin,audit,cfgtoollogs,checkpoints,diag,fast_recovery_area,oradata,oraInventory/logs}
#rm -rf $ORACLE_HOME/{admin,cfgtoollogs,dbs,log,network/admin,network/log,network/trace,rdbms/audit,rdbms/log}
rm -rf $ORACLE_HOME/{admin,cfgtoollogs,dbs,log,network/admin,network/log,network/trace,rdbms/audit}

cat >>/home/oracle/.bashrc <<EOF
export ORACLE_BASE=$ORACLE_BASE
export ORACLE_HOME=$ORACLE_HOME
export ORACLE_SID=$ORACLE_SID
export ORACLE_PDB=$ORACLE_PDB

export JAVA_HOME=$JAVA_HOME

export PATH=\$JAVA_HOME/bin:\$ORACLE_HOME/bin:\$PATH

export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/usr/lib
export CLASSPATH=\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib

export NLS_LANG=AMERICAN_AMERICA.UTF8

alias rlsql='rlwrap sqlplus'
alias rlsqla='rlwrap sqlplus / as sysdba'
alias rllsnr='rlwrap lsnrctl'
alias rlrman='rlwrap rman'
EOF

mv $OTHERS_DIR/oracle/XE_Database_mod.dbc $ORACLE_HOME/assistants/dbca/templates/
rm -rf $OTHERS_DIR/oracle
chmod 640 $ORACLE_HOME/assistants/dbca/templates/*.dbc
chown oracle:oinstall $ORACLE_HOME/assistants/dbca/templates/*.dbc

DISTR=$DISTRS_DIR/jdk-8u241-linux-x64.tar.gz
rm -rf $ORACLE_HOME/jdk
mkdir $ORACLE_HOME/jdk
tar -xzf $DISTR -C $ORACLE_HOME/jdk --strip-components=1
rm $DISTR
chown -R oracle:oinstall $ORACLE_HOME/jdk

DISTR=$DISTRS_DIR/apex_19.2.zip
unzip -oqd $ORACLE_HOME $DISTR
rm $DISTR
chown -R oracle:oinstall $ORACLE_HOME/apex

DISTR=$DISTRS_DIR/ords-19.4.0.352.1226.zip
mkdir $ORACLE_BASE/ords
unzip -oqd $ORACLE_BASE/ords $DISTR
rm $DISTR
rm -rf $ORACLE_BASE/ords/params
chown -R oracle:oinstall $ORACLE_BASE/ords


#groupadd -g 54320 tomcat
#useradd -u 54320 -g tomcat -m tomcat
#wtf, lets root
DISTR=$DISTRS_DIR/apache-tomcat-9.0.31.tar.gz
mkdir $CATALINA_HOME
tar -xzf $DISTR -C $CATALINA_HOME --strip-components=1
rm $DISTR
rm -rf $CATALINA_HOME/{logs,temp,work}
cat $OTHERS_DIR/tomcat/managers_context.xml >$CATALINA_HOME/webapps/manager/META-INF/context.xml
cat $OTHERS_DIR/tomcat/managers_context.xml >$CATALINA_HOME/webapps/host-manager/META-INF/context.xml
mv -f $OTHERS_DIR/tomcat/conf/* $CATALINA_HOME/conf/
rm -rf $OTHERS_DIR/tomcat
chmod 600 $CATALINA_HOME/conf/*


# and finally
yum install -y nano
yum install -y openssh-server
ssh-keygen -A

# for use as volume
mkdir /u02

mv $SCRIPTS_DIR/setup_oracle.sh /home/oracle/
chown oracle:oinstall /home/oracle/setup_oracle.sh
mv $SCRIPTS_DIR/entrypoint.sh /root/
chown root:root /root/entrypoint.sh

rm -rf /tmp/install

rm -rf /var/cache/yum
