pre_start_action() {
    mkdir -p $GERRIT_HOME/gerrit
    mkdir -p $LOG_DIR/supervisor

    chown $GERRIT_USER:$GERRIT_USER -R $GERRIT_HOME
    java -jar $GERRIT_WAR init --no-auto-start --batch -d ${GERRIT_HOME}/gerrit

    cat > ${GERRIT_HOME}/gerrit/etc/secure.config <<EOF
#[database]
#    password = $DB_PASS
[ldap]
    password = $LDAP_PASS
EOF
    cat > ${GERRIT_HOME}/gerrit/etc/gerrit.config <<EOF
[gerrit]
    basePath = git
    canonicalWebUrl = http://$VIRTUAL_HOST/
[database]
#    type = mysql
#    hostname = $DB_HOST
#    database = $DB_NAME
#    username = $DB_USER
    type = H2
    database = db/reviewdb
[auth]
    type = LDAP
    gitBasicAuth = true
[sendemail]
    smtpServer = $SMTP_HOST
    from = MIXED
[container]
    user = $GERRIT_USER
    javaHome = $JAVA_HOME
[sshd]
    listenAddress = *:29418
[httpd]
#    listenUrl = http://*:8080
    listenUrl = proxy-http://*:8081/
[cache]
    directory = cache
[ldap]
    server = ldap://$LDAP_HOST
    username = $LDAP_USER
    accountBase = ou=users,$LDAP_BASE
    accountPattern = (&(objectclass=posixAccount)(uid=\${uid}))
    accountFullName = cn
    accountEmailAddress = \${uid}@$MTA_DOMAIN
    groupBase = ou=groups,$LDAP_BASE
    groupPattern = (cn=\${groupname})
    groupMemberPattern = (|(memberUid=\${username})(gidNumber=\${gidNumber}))
[user]
    email = gerrit2@$MTA_DOMAIN
[commitmessage]
    maxSubjectLength = 65
    maxLineLength = 80
EOF

    touch /etc/msmtprc
    mkdir -p $LOG_DIR/msmtp
    chown $GERRIT_USER:$GERRIT_USER $LOG_DIR/msmtp
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

    cat > /etc/nginx/sites-enabled/gerrit.conf <<EOF
upstream gerrit {
    server localhost:8081;
}
## This is a normal HTTP host which redirects all traffic to the HTTPS host.
server {
    listen 80;
    server_name $VIRTUAL_HOST;
    charset utf-8;

    location / {
        proxy_pass http://gerrit;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header Host \$host;
    }
}
server {
  listen 443 ssl;
  server_name  $VIRTUAL_HOST;

  location / {
      proxy_pass http://gerrit;
      proxy_set_header X-Forwarded-For \$remote_addr;
      proxy_set_header Host \$host;
  }

  ## SSL Security
  ## https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
  ssl on;
  ssl_certificate /etc/nginx/ssl/gerrit.crt;
  ssl_certificate_key /etc/nginx/ssl/gerrit.key;

  ssl_ciphers 'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4';

  ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
  ssl_session_cache  builtin:1000  shared:SSL:10m;

  ssl_prefer_server_ciphers   on;

  add_header Strict-Transport-Security max-age=63072000;
  add_header X-Frame-Options DENY;
  add_header X-Content-Type-Options nosniff;

  # logging
  error_log $LOG_DIR/nginx/error.log;
  access_log $LOG_DIR/nginx/access.log;
}
EOF
    mkdir -p $LOG_DIR/nginx
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -subj "/C=CN/ST=SH/L=SHANGHAI/O=MoreTV/OU=Helios/CN=muzili@gmail.com"  -keyout /etc/nginx/ssl/gerrit.key -out /etc/nginx/ssl/gerrit.crt

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
[program:gerrit]
command=/bin/bash -c "/data/gerrit2/gerrit/bin/gerrit.sh run"

[program:nginx]
command=/usr/sbin/nginx

EOF
}

post_start_action() {
    rm /first_run
}
