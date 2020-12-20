#!/bin/bash -xe

A=$1
#links only?
mldir () {
  if [ $A != "lonly" ]; then
    mkdir -p $1
    rm -rf $2
    ln -sT $1 $2
  elif [ ! -L $2 ]; then
    ln -sT $1 $2
  fi
}
mldir /u02/oracle/admin $ORACLE_BASE/admin
mldir /u02/oracle/audit $ORACLE_BASE/audit
mldir /u02/oracle/cfgtoollogs $ORACLE_BASE/cfgtoollogs
mldir /u02/oracle/checkpoints $ORACLE_BASE/checkpoints
mldir /u02/oracle/diag $ORACLE_BASE/diag
mldir /u02/oracle/oradata $ORACLE_BASE/oradata
mldir /u02/oracle/oraInventory/logs $ORACLE_BASE/oraInventory/logs
mldir /u02/oracle/home/admin $ORACLE_HOME/admin
mldir /u02/oracle/home/cfgtoollogs $ORACLE_HOME/cfgtoollogs
mldir /u02/oracle/home/dbs $ORACLE_HOME/dbs
mldir /u02/oracle/home/log $ORACLE_HOME/log
mldir /u02/oracle/home/network/admin $ORACLE_HOME/network/admin
mldir /u02/oracle/home/network/log $ORACLE_HOME/network/log
mldir /u02/oracle/home/network/trace $ORACLE_HOME/network/trace
mldir /u02/oracle/home/rdbms/audit $ORACLE_HOME/rdbms/audit
#mldir /u02/oracle/home/rdbms/log $ORACLE_HOME/rdbms/log
#chmod a+w /u02/oracle/home/rdbms/log
#^doesnt help, f...... bug
#SQL> exec SYS.DBMS_QOPATCH.replace_logscrpt_dirs;
#BEGIN SYS.DBMS_QOPATCH.replace_logscrpt_dirs; END;
#*
#ERROR at line 1:
#ORA-29283: invalid file operation
#ORA-06512: at "SYS.DBMS_QOPATCH", line 1652
#ORA-06512: at "SYS.UTL_FILE", line 536
#ORA-29283: invalid file operation
#ORA-06512: at "SYS.UTL_FILE", line 41
#ORA-06512: at "SYS.UTL_FILE", line 478
#ORA-06512: at "SYS.DBMS_QOPATCH", line 1622
#ORA-06512: at "SYS.DBMS_QOPATCH", line 1523
#ORA-06512: at line 1
mldir /u02/oracle/ords/config $ORACLE_BASE/ords/config
mldir /u02/oracle/ords/params $ORACLE_BASE/ords/params
mldir /u02/oracle/ords/log $ORACLE_BASE/ords/log
[ $A == "lonly" ] && exit 0
chmod g+w /u02/oracle/oraInventory/logs
mkdir /u02/oracle/home/rdbms/log
mkdir /u02/oracle/home/apex

if [ -f /u02/oracle/.pwds ]; then
  . /u02/oracle/.pwds
fi
ORACLE_PWD=${ORACLE_PWD:-`cat /dev/urandom | tr -dc '[:alnum:]' | head -c 10`}
APEX_PUB_PWD=${APEX_PUB_PWD:-`cat /dev/urandom | tr -dc '[:alnum:]' | head -c 10`}
APEX_ADM_PWD=${APEX_ADM_PWD:-`cat /dev/urandom | tr -dc '[:alnum:]' | head -c 10`}
ORDS_PUB_PWD=${ORDS_PUB_PWD:-`cat /dev/urandom | tr -dc '[:alnum:]' | head -c 10`}
cat >/u02/oracle/.pwds <<EOF
ORACLE_PWD=$ORACLE_PWD
APEX_PUB_PWD=$APEX_PUB_PWD
APEX_ADM_PWD=$APEX_ADM_PWD
ORDS_PUB_PWD=$ORDS_PUB_PWD
EOF

#
cat >$ORACLE_HOME/network/admin/listener.ora <<EOF
LISTENER =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = $ORACLE_PDB)
      (SID_NAME = $ORACLE_SID)
    )
    (SID_DESC =
      (SID_NAME = PLSExtProc)
      (ORACLE_HOME = $ORACLE_HOME)
      (PROGRAM = extproc)
    )
  )

#DEFAULT_SERVICE_LISTENER = $ORACLE_SID

SECURE_PROTOCOL_LISTENER = IPC

#INBOUND_CONNECT_TIMEOUT_LISTENER = 400
EOF
cat >${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
NAMES.DIRECTORY_PATH = (TNSNAMES, EZCONNECT)

#SQLNET.INBOUND_CONNECT_TIMEOUT = 400
EOF
lsnrctl start
if [ -f /etc/oratab ]; then
  cat /dev/null >/etc/oratab
fi
dbca -silent -createDatabase \
  -templateName XE_Database_mod.dbc \
  -gdbname $ORACLE_SID \
  -sid $ORACLE_SID \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 \
  -pdbName $ORACLE_PDB \
  -sysPassword $ORACLE_PWD \
  -systemPassword $ORACLE_PWD \
  -pdbAdminPassword $ORACLE_PWD \
  -emConfiguration NONE \
  -characterSet AL32UTF8 \
  -J-Doracle.assistants.dbca.validate.DBCredentials=false
#  -emConfiguration DBEXPRESS \
#  -emExpressPort 5500 \
cat >${ORACLE_HOME}/network/admin/tnsnames.ora <<EOF
LISTENER_$ORACLE_SID =
  (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))

$ORACLE_SID =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = $ORACLE_SID)
    )
  )

$ORACLE_PDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = $ORACLE_PDB)
    )
  )

EXTPROC_CONNECTION_DATA =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
    (CONNECT_DATA =
      (SID = PLSExtProc)
      (PRESENTATION = RO)
    )
  )
EOF

sqlplus -s / as sysdba <<EOF
alter pluggable database $ORACLE_PDB save state;
--exec dbms_xdb_config.setglobalportenabled(true);
alter system set dispatchers='' scope=spfile;
startup force;
exit;
EOF

# prepare Tablespaces
sqlplus -s / as sysdba <<EOF
prompt prepare tablespaces

prompt UNDO@CDB
create undo tablespace UNDO datafile '$ORACLE_BASE/oradata/$ORACLE_SID/undo01.dbf' size 50m autoextend on next 50m;
alter system set UNDO_TABLESPACE=UNDO scope=both;

prompt TEMP@CDB
alter database tempfile '$ORACLE_BASE/oradata/$ORACLE_SID/temp01.dbf' resize 150m;
alter database tempfile '$ORACLE_BASE/oradata/$ORACLE_SID/temp01.dbf' autoextend on next 50m;

prompt SYSTEM@CDB
alter database datafile '$ORACLE_BASE/oradata/$ORACLE_SID/system01.dbf' resize 900m;
alter database datafile '$ORACLE_BASE/oradata/$ORACLE_SID/system01.dbf' autoextend on next 100m;

prompt SYSAUX@CDB
alter database datafile '$ORACLE_BASE/oradata/$ORACLE_SID/sysaux01.dbf' resize 900m;
alter database datafile '$ORACLE_BASE/oradata/$ORACLE_SID/sysaux01.dbf' autoextend on next 100m;

alter session set container=$ORACLE_PDB;

prompt UNDO@PDB
create undo tablespace UNDO datafile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/undo01.dbf' size 500m autoextend on next 100m;
alter system set UNDO_TABLESPACE=UNDO scope=both;

prompt TEMP@PDB
alter database tempfile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/temp01.dbf' resize 500m;
alter database tempfile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/temp01.dbf' autoextend on next 100m;

prompt SYSTEM@PDB
alter database datafile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/system01.dbf' resize 500m;
alter database datafile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/system01.dbf' autoextend on next 100m;

prompt XDB@PDB
create tablespace XDB datafile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/xdb01.dbf' size 100m autoextend on next 50m;
alter system enable restricted session;
set serverout on
begin
 xdb.dbms_xdb_admin.movexdb_tablespace('XDB', trace => false);
end;
/
alter system disable restricted session;
alter user XDB default tablespace XDB;

prompt SYSAUX@PDB
alter database datafile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/sysaux01.dbf' resize 500m;
alter database datafile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/sysaux01.dbf' autoextend on next 100m;

prompt APEX@PDB
create tablespace APEX datafile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/apex01.dbf' size 500m autoextend on next 100m;
create tablespace APEXX datafile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/apexx01.dbf' size 50m autoextend on next 50m;
--
--prompt ORDS@PDB
--create tablespace ORDS datafile '$ORACLE_BASE/oradata/$ORACLE_SID/$ORACLE_PDB/ords01.dbf' size 50m autoextend on next 50m;

prompt now restart
alter session set container=CDB\$ROOT;
startup force;

prompt and cleanup
drop tablespace UNDOTBS1 including contents and datafiles cascade constraints;
alter session set container=$ORACLE_PDB;
drop tablespace UNDOTBS1 including contents and datafiles cascade constraints;

prompt tablespaces prepared.
exit;
EOF


#APEX

cd $ORACLE_HOME/apex
sqlplus -s / as sysdba <<EOF
alter session set container=$ORACLE_PDB;

prompt install APEX
@apexins.sql APEX APEXX TEMP /i/

prompt unlock APEX_PUBLIC_USER
alter user APEX_PUBLIC_USER identified by "$APEX_PUB_PWD" account unlock;

prompt create APEX Instance Administrator
begin
 apex_util.set_security_group_id(10);
 apex_util.create_user(
  p_user_name => 'ADMIN'
 ,p_email_address => 'your@email.addr'
 ,p_web_password => '$APEX_ADM_PWD'
 ,p_developer_privs => 'ADMIN'
 ,p_change_password_on_first_use => 'N'
 );
 apex_util.set_security_group_id(null);
 commit;
end;
/

prompt config APEX REST
@apex_rest_config_core.sql @ $APEX_PUB_PWD $APEX_PUB_PWD

prompt create a network ACE for APEX (this is used when consuming Web services or sending outbound mail)
begin
 for c1 in
  (
   select schema
     from sys.dba_registry
    where comp_id = 'APEX'
  )
 loop
  sys.dbms_network_acl_admin.append_host_ace(
   host => '*'
  ,ace => xs\$ace_type(privilege_list => xs\$name_list('connect')
  ,principal_name => c1.schema
  ,principal_type => xs_acl.ptype_db)
  );
 end loop;
 commit;
end;
/
exit;
EOF


#ORDS

java -jar $ORACLE_BASE/ords/ords.war configdir $ORACLE_BASE/ords/config
ln -sT ./ords $ORACLE_BASE/ords/config/apex
#mkdir -p $ORACLE_BASE/ords/config/ords/standalone
#mkdir -p $ORACLE_BASE/ords/config/ords/doc_root
#cat >$ORACLE_BASE/ords/config/ords/standalone/standalone.properties << EOF
#jetty.port=8080
#standalone.context.path=/ords
#standalone.doc.root=$ORACLE_BASE/ords/config/ords/doc_root
#standalone.scheme.do.not.prompt=true
#standalone.static.context.path=/i
#standalone.static.path=$ORACLE_HOME/apex/images
#EOF
sqlplus -s / as sysdba <<EOF
alter session set container=$ORACLE_PDB;
alter user APEX_LISTENER identified by "$APEX_PUB_PWD" account unlock;
alter user APEX_REST_PUBLIC_USER identified by "$APEX_PUB_PWD" account unlock;
exit;
EOF
cat >$ORACLE_BASE/ords/params/ords_params.properties << EOF
db.hostname=localhost
db.port=1521
db.servicename=$ORACLE_PDB
db.username=APEX_PUBLIC_USER
db.password=$APEX_PUB_PWD
migrate.apex.rest=false
plsql.gateway.add=true
rest.services.apex.add=true
rest.services.ords.add=true
#schema.tablespace.default=ORDS
schema.tablespace.default=APEX
schema.tablespace.temp=TEMP
sys.user=sys
sys.password=$ORACLE_PWD
standalone.mode=false
#standalone.mode=true
#standalone.http.port=8080
#standalone.use.https=false
#standalone.static.images=$ORACLE_HOME/apex/images
user.apex.listener.password=$APEX_PUB_PWD
user.apex.restpublic.password=$APEX_PUB_PWD
user.public.password=$ORDS_PUB_PWD
user.tablespace.default=USERS
user.tablespace.temp=TEMP
restEnabledSql.active=true
feature.sdw=true
EOF
java -jar $ORACLE_BASE/ords/ords.war install simple --logDir $ORACLE_BASE/ords/log
sed -i -r "s/(\.password\=).+/\1**********/" $ORACLE_BASE/ords/params/ords_params.properties
cat >$ORACLE_BASE/ords/params/ords_config.properties << EOF
jdbc.MinLimit=5
jdbc.MaxLimit=25
jdbc.InitialLimit=5
EOF
java -jar $ORACLE_BASE/ords/ords.war set-properties $ORACLE_BASE/ords/params/ords_config.properties

#
sqlplus -s / as sysdba <<EOF
prompt disable password expiration for agent accounts
alter session set container=$ORACLE_PDB;
create profile AGENT limit PASSWORD_LIFE_TIME unlimited;
alter user APEX_PUBLIC_USER profile AGENT;
alter user APEX_LISTENER profile AGENT;
alter user APEX_REST_PUBLIC_USER profile AGENT;
alter user ORDS_PUBLIC_USER profile AGENT;
EOF

# finish
sqlplus -s / as sysdba <<EOF
prompt perform some fixes
exec dbms_stats.init_package();

prompt and shutdown.
shutdown immediate;
exit;
EOF
lsnrctl stop

# and cleanup
rm -rf /tmp/CVU_18.0.0.0.0_oracle
find $ORACLE_HOME/rdbms/log -mindepth 1 -maxdepth 1 -exec mv -ft /u02/oracle/home/rdbms/log -- {} +
find $ORACLE_HOME/apex -mindepth 1 -maxdepth 1 -type f -name \*.log -exec mv -ft /u02/oracle/home/apex -- {} +
mkdir -p $ORACLE_BASE/diag/rdbms/${ORACLE_SID,,}/$ORACLE_SID/trace/setup
find $ORACLE_BASE/diag/rdbms/${ORACLE_SID,,}/$ORACLE_SID/trace -mindepth 1 -maxdepth 1 -type f -exec mv -ft $ORACLE_BASE/diag/rdbms/${ORACLE_SID,,}/$ORACLE_SID/trace/setup -- {} +
