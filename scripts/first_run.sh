pre_start_action() {
  mkdir -p $GERRIT_HOME
  mkdir -p $LOG_DIR/supervisor

  java -jar $GERRIT_WAR init --batch -d ${GERRIT_HOME}/gerrit

  cat > ${GERRIT_HOME}/gerrit/etc/gerrit.config <<EOF
[gerrit]
    basePath = git
    canonicalWebUrl = http://localhost:8080/
[database]
    type = H2
    database = db/ReviewDB
[auth]
    type = OpenID
[sendemail]
    smtpServer = localhost
[container]
    user = $GERRIT_USER
[sshd]
    listenAddress = *:29418
[httpd]
    listenUrl = http://*:8080/
[cache]
    directory = cache

EOF
      echo "check mysql status"
      mysql -u$MYSQL_ENV_USER -p$MYSQL_ENV_PASS \
            -h$MYSQL_PORT_3306_TCP_ADDR \
            -P$MYSQL_PORT_3306_TCP_PORT \
            -e "status"
      RET=$?
      echo "mysql status is $RET"
  done

  touch /etc/msmtprc
  mkdir -p $LOG_DIR/msmtp
  chown phab-daemon:wwwgrp-phabricator $LOG_DIR/msmtp
  cat > /etc/msmtprc <<EOF
# The SMTP server of the provider.
defaults
logfile $LOG_DIR/msmtp/msmtplog

account mail
host $SMTP_HOST
port $SMTP_PORT
user $SMTP_USER
password $SMTP_PASS
auth login
tls on
tls_trust_file /etc/pki/tls/certs/ca-bundle.crt

account default : mail

EOF
  chmod 600 /etc/msmtprc

  mkdir -p /etc/supervisor/conf.d
  cat > /etc/supervisord.conf <<-EOF
[unix_http_server]
file=/run/supervisor.sock   ; (the path to the socket file)

[supervisord]
logfile=/var/log/supervisor/supervisord.log ; (main log file;default $CWD/supervisord.log)
logfile_maxbytes=50MB       ; (max main logfile bytes b4 rotation;default 50MB)
logfile_backups=10          ; (num of main logfile rotation backups;default 10)
loglevel=info               ; (log level;default info; others: debug,warn,trace)
pidfile=/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
nodaemon=true               ; (start in foreground if true;default false)
minfds=1024                 ; (min. avail startup file descriptors;default 1024)
minprocs=200                ; (min. avail process descriptors;default 200)

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///run/supervisor.sock ; use a unix:// URL  for a unix socket

[include]
files = /etc/supervisor/conf.d/*.conf
EOF
  cat > /etc/supervisor/conf.d/gerrit.conf <<-EOF
[program:nginx]
command=/usr/sbin/nginx

[program:cron]
command=crond -n

EOF

  chown -R nginx:nginx "$LOG_DIR/nginx"
}

post_start_action() {
  rm /first_run
}
