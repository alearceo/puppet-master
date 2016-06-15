## site.pp ##

# This file (/etc/puppetlabs/puppet/manifests/site.pp) is the main entry point
# used when an agent connects to a master and asks for an updated configuration.
#
# Global objects like filebuckets and resource defaults should go in this file,
# as should the default node definition. (The default node can be omitted
# if you use the console and don't define any other nodes in site.pp. See
# http://docs.puppetlabs.com/guides/language_guide.html#nodes for more on
# node definitions.)

## Active Configurations ##

# PRIMARY FILEBUCKET
# This configures puppet agent and puppet inspect to back up file contents when
# they run. The Puppet Enterprise console needs this to display file contents
# and differences.

# Define filebucket 'main':
filebucket { 'main':
  server => 'puppet.cecmed.local',
  path   => false,
}

# Make filebucket 'main' the default backup location for all File resources:
File { backup => 'main' }

# DEFAULT NODE
# Node definitions in this file are merged with node data from the console. See
# http://docs.puppetlabs.com/guides/language_guide.html#nodes for more on
# node definitions.

# The default node definition matches any node lacking a more specific node
# definition. If there are no other nodes in this file, classes declared here
# will be included in every node's catalog, *in addition* to any classes
# specified in the console for that node.

node default {
  # This is where you can declare classes for all nodes.
  # Example:
  #   class { 'my_class': }

}

node db-server {

  # NOTE Cron job to run puppet service every 5 minutes - PROD
  cron { 'puppet-agent':
    ensure  => present,
    command => '/opt/puppetlabs/puppet/bin/puppet agent --onetime --no-daemonize',
    user    => root,
    minute  => '*/5',
  }

  # MySQL server installation
  class { 'mysql::server':
    root_password           => 'hbc25ls*.50',
    restart                 => 'true',
    manage_config_file      => 'true',
    remove_default_accounts => 'false',
    override_options        => {
      mysqld => {
        'bind-address' => '192.168.50.100',
      }
    },
  }

  # DB Admin users for MySQL
  mysql_user { 'db-admin@%':
    ensure                   => 'present',
    max_connections_per_hour => '0',
    max_queries_per_hour     => '0',
    max_updates_per_hour     => '0',
    max_user_connections     => '0',
    password_hash            => mysql_password('hbc30ls*.50'),
  }

  mysql_user { 'web-admin@%':
    ensure                   => 'present',
    max_connections_per_hour => '0',
    max_queries_per_hour     => '0',
    max_updates_per_hour     => '0',
    max_user_connections     => '0',
    password_hash            => mysql_password('hbc30ls*.100'),
  }

  #mysql_user { 'db-admin@localhost':
  #  ensure                   => 'present',
  #  max_connections_per_hour => '0',
  #  max_queries_per_hour     => '0',
  #  max_updates_per_hour     => '0',
  #  max_user_connections     => '0',
  #  password_hash => mysql_password('hbc30ls*.50'),
  #}

  # Others DB users
  mysql_user { 'jcarrillo@192.168.6.16':
    ensure        => 'present',
    #max_connections_per_hour => '0',
    #max_queries_per_hour     => '0',
    #max_updates_per_hour     => '0',
    #max_user_connections     => '0',
    password_hash => mysql_password('jcarrillo12345'),
  }

  # DB Permissions per user
  mysql_grant { 'db-admin@%/*.*':
    ensure     => 'present',
    options    => ['GRANT'],
    privileges => ['ALL'],
    table      => '*.*',
    user       => 'db-admin@%',
  }

  #mysql_grant { 'db-admin@localhost/*.*':
  #  ensure     => 'present',
  #  options    => ['GRANT'],
  #  privileges => ['ALL'],
  #  table      => '*.*',
  #  user       => 'db-admin@localhost',
  #}

  # CECMED web-sites databases creation
  mysql_database { 'web':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'drupal':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'aulavirtual':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'webmail':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'intranet':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'intranetnew':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'soporte':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'ocs-db':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'media-wiki':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'helpdesk':
    ensure  => 'present',
    charset => 'utf8',
  }
  mysql_database { 'local':
    ensure  => 'present',
    charset => 'utf8',
  }

  # DB backup configuration
  class { 'mysql::server::backup':
    ensure            => 'present',
    backupuser        => 'backup-admin',
    backuppassword    => mysql_password('hbc30ls*.50'),
    backupdir         => '/var/backup/db-backup',
    backupdatabases   => ['web','aulavirtual','webmail','intranet','intranetnew','soporte'],
    file_per_database => 'true',
    time              => ['17','0'],
  }

  cron::daily { 'db-backup-to-fileserver':
    ensure      => 'present',
    minute      => '10',
    hour        => '17',
    user        => 'root',
    command     => 'cp /var/backup/db-backup/* /share/backup-drive/db-backup/',
    environment => ['MAILTO=root,ale@cecmed.cu,carmen@cecmed.cu,joseyong@cecmed.cu'],
  }

  # PostgreSQL server installation
  class { 'postgresql::server':
    ip_mask_deny_postgres_user => '0.0.0.0/32',
    ip_mask_allow_all_users    => '0.0.0.0/0',
    listen_addresses           => '*',
    postgres_password          => 'hbc25ls*.50',
  }

  postgresql::server::role { 'db-admin':
    password_hash => postgresql_password('db-admin', 'hbc30ls*.50'),
  }

  postgresql::server::db { 'cecmed-app':
    user     => 'admin',
    password => postgresql_password('admin', 'hbc40ls*.20'),
  }

  postgresql::server::database_grant { 'cecmed-app':
    privilege => 'ALL',
    db        => 'cecmed-app',
    role      => 'db-admin',
  }

  # NOTE Sendmail configuration
  class { 'sendmail':
    smart_host => 'correo.cecmed.local',
  }

  sendmail::authinfo::entry { 'correo.cecmed.local':
    password         => '12345',
    authorization_id => 'backup@cecmed.cu',
  }

  # NOTE Firewall configuration for MySQL and PostgreSQL
  firewall { '100 allow MySQL access':
    ensure => present,
    dport  => '3306',
    proto  => tcp,
    action => accept,
  }

  firewall { '100 allow PostgreSQL access':
    ensure => present,
    dport  => '5432',
    proto  => tcp,
    action => accept,
  }

}

node webserver-lan {

  # NOTE Cron job to run puppet service every 5 minutes
  cron { 'puppet-agent':
    ensure  => present,
    command => '/opt/puppetlabs/puppet/bin/puppet agent --onetime --no-daemonize',
    user    => root,
    minute  => '*/5',
  }

  class { 'apache':
    default_mods     => false,
    default_vhost    => false,
    purge_configs    => false,
    vhost_dir        => '/etc/httpd/sites-available',
    confd_dir        => '/etc/httpd/conf.d',
    mpm_module       => 'prefork',
    server_signature => 'Off',
    trace_enable     => 'Off',
    server_tokens    => 'Prod',
  }

  apache::custom_config { 'welcome':
    ensure   => present,
    source   => 'puppet:///modules/apache/welcome.conf',
    priority => false,
  }

  include apache::mod::php
  include apache::mod::autoindex
  include apache::mod::alias
  include apache::mod::dir
  include apache::mod::mime
  include apache::mod::rewrite
  include apache::mod::proxy
  include apache::mod::proxy_html
  include apache::mod::proxy_http

  # NOTE Ticket app on OSTicket - STATUS Prod
  apache::vhost { 'soporte.cecmed.local':
    ensure        => present,
    serveraliases => ['soporte.cecmed.local'],
    port          => '80',
    docroot       => '/var/www/soporte.cecmed.local',
    priority      => '00',
    log_level     => 'warn',
    directories   => [
      { path           => '/var/www/soporte.cecmed.local',
        allow          => 'from all',
        order          => 'Allow,Deny',
        allow_override => ['All'],
        options        => ['Indexes','FollowSymLinks','MultiViews','ExecCGI'],
      },
    ],
  }

  # NOTE Previous intranet website on Drupal - STATUS Prod
  apache::vhost { 'intranet-old.cecmed.local':
    ensure        => present,
    serveraliases => ['intranet-old.cecmed.local'],
    port          => '80',
    docroot       => '/var/www/intranet.cecmed.local',
    priority      => '25',
    log_level     => 'warn',
    directories   => [
      { path           => '/var/www/intranet.cecmed.local',
        allow          => 'from all',
        order          => 'Allow,Deny',
        allow_override => ['All'],
        options        => ['Indexes','FollowSymLinks','MultiViews','ExecCGI'],
      },
    ],
  }

  # NOTE Static Calidad website - STATUS Prod
  apache::vhost { 'calidad.cecmed.local':
    ensure        => present,
    serveraliases => ['calidad.cecmed.local'],
    port          => '80',
    docroot       => '/var/www/calidad.cecmed.local',
    priority      => '40',
    log_level     => 'warn',
    directories   => [
      { path           => '/var/www/calidad.cecmed.local',
        directoryindex => 'index.htm',
        allow          => 'from all',
        order          => 'Allow,Deny',
        allow_override => ['All'],
        options        => ['Indexes','FollowSymLinks','MultiViews','ExecCGI'],
      },
    ],
  }

  # NOTE New intranet website on Drupal - STATUS dev
  apache::vhost { 'ex.cecmed.local':
    ensure        => absent,
    serveraliases => ['ex.cecmed.local'],
    port          => '80',
    docroot       => '/var/www/example.cecmed.local',
    priority      => '12',
    log_level     => 'warn',
    directories   => [
      {
        path           => '/var/www/example.cecmed.local',
        allow          => 'from all',
        order          => 'Allow,Deny',
        allow_override => ['All'],
        options        => ['Indexes','FollowSymLinks','MultiViews','ExecCGI'],
        # NOTE Clean URLs configuration
        rewrites       => [
          {
            rewrite_base => '/',
            rewrite_cond => ['%{REQUEST_FILENAME} !-f',
                            '%{REQUEST_FILENAME} !-d',
                            '%{REQUEST_URI} !=/favicon.ico'
                            ],
            rewrite_rule => ['^ index.php [L]'],
          },
        ],
      },
    ],
  }

  # NOTE New intranet website on Drupal - STATUS prod
  apache::vhost { 'intranet.cecmed.local':
    ensure        => present,
    serveraliases => ['intranet.cecmed.local'],
    port          => '80',
    docroot       => '/var/www/intranet-new.cecmed.local',
    priority      => '01',
    log_level     => 'warn',
    directories   => [
      {
        path           => '/var/www/intranet-new.cecmed.local',
        allow          => 'from all',
        order          => 'Allow,Deny',
        allow_override => ['All'],
        options        => ['Indexes','FollowSymLinks','MultiViews','ExecCGI'],
        # NOTE Clean URLs configuration
        rewrites       => [
          {
            rewrite_base => '/',
            rewrite_cond => ['%{REQUEST_FILENAME} !-f',
                            '%{REQUEST_FILENAME} !-d',
                            '%{REQUEST_URI} !=/favicon.ico'
                            ],
            rewrite_rule => ['^ index.php [L]'],
          },
        ],
      },
    ],
  }

  # NOTE Forum website - OCS 2.3.6
  apache::vhost { 'forum.cecmed.local':
    ensure        => absent,
    serveraliases => ['forum.cecmed.local'],
    port          => '80',
    docroot       => '/var/www/forum.cecmed.local',
    priority      => '30',
    log_level     => 'warn',
    directories   => [
      { path           => '/var/www/forum.cecmed.local',
        allow          => 'from all',
        order          => 'Allow,Deny',
        allow_override => ['All'],
        options        => ['Indexes','FollowSymLinks','MultiViews','ExecCGI'],
      },
    ],
  }

#  apache::vhost { 'example.cecmed.local':
#    ensure              => absent,
#    serveraliases       => ['example.cecmed.local'],
#    port                => '80',
#    docroot             => '/var/www/example.cecmed.local',
#    priority            => false,
#    proxy_preserve_host => true,
#    proxy_pass          => [
#      {
#        'path' => '/',
#        'url'  => 'http://www.google.com/'
#      },
#    ],
    # NOTE review redirect configuration
    # redirect_dest => ['http://www.google.com/'],
#  }

  #exec { 'ln':
  #  command => 'ln -s /etc/httpd/sites-available/soporte.conf /etc/httpd/sites-enabled/soporte.conf',
  #  path    => '/usr/local/bin/:/bin/',
  #}

# NOTE Backup block for hosted webs
  cron::job::multiple { 'backup-cron-jobs':
    ensure      => 'present',
    jobs        => [
      {
        minute      => '00',
        hour        => '17',
        user        => 'root',
        command     => 'tar cfz /var/share/backup-drive/new-intranet/backup-new-intranet-$(date +\%Y\%m\%d-\%H\%M\%S).tar.gz -C /var/www/intranet-new.cecmed.local/ .',
        description => 'backup new intranet directory',
      },
      {
        minute      => '00',
        hour        => '17',
        user        => 'root',
        command     => 'tar cfz /var/share/backup-drive/web-soporte-files/backup-web-soporte-$(date +\%Y\%m\%d-\%H\%M\%S).tar.gz -C /var/www/soporte.cecmed.local/ .',
        description => 'backup soporte directory',
      },
      {
        minute      => '00',
        hour        => '17',
        user        => 'root',
        command     => 'tar cfz /var/share/backup-drive/old-intranet/backup-old-intranet-$(date +\%Y\%m\%d-\%H\%M\%S).tar.gz -C /var/www/intranet.cecmed.local/ .',
        description => 'backup old intranet directory',
      },
      {
        minute      => '00',
        hour        => '17',
        user        => 'root',
        command     => 'tar cfz /var/share/backup-drive/web-calidad/backup-web-calidad-$(date +\%Y\%m\%d-\%H\%M\%S).tar.gz -C /var/www/calidad.cecmed.local/ .',
        description => 'backup calidad directory',
      },
    ],
    environment => ['MAILTO=root,ale@cecmed.cu,carmen@cecmed.cu,joseyong@cecmed.cu'],
}


  # NOTE Sendmail configuration
  class { 'sendmail':
    smart_host => 'correo.cecmed.local',
  }

  sendmail::authinfo::entry { 'correo.cecmed.local':
    password         => '12345',
    authorization_id => 'backup@cecmed.cu',
  }

  # NOTE Local FTP Configuration - vsftpd
  #class { 'vsftpd':
  #  anonymous_enable       => 'NO',
  #  write_enable           => 'NO',
  #  ftpd_banner            => 'Local FTP Server - Unathorized Access Prohibited!!',
  #  chroot_local_user      => 'YES',
  #  allow_writeable_chroot => 'NO',
  #  ascii_upload_enable    => 'NO',
  #  ascii_download_enable  => 'NO',
  #  directives             => {
  #      pasv_enable => 'NO',
  #    },
  #}

  # NOTE Firewall configuration
  firewall { '100 allow http & https access':
    ensure => present,
    dport  => ['80','443'],
    proto  => tcp,
    action => accept,
  }

  firewall { '100 allow ftp access':
    ensure => present,
    dport  => ['21'],
    proto  => tcp,
    action => accept,
  }

}

node webserver-dmz {

  # NOTE Cron job to run puppet service every 5 minutes
  cron { 'puppet-agent':
    ensure  => present,
    command => '/opt/puppetlabs/puppet/bin/puppet agent --onetime --no-daemonize',
    user    => root,
    minute  => '*/5',
  }

  #class {'newrelic::server::linux':
  #  ensure => absent,
  #  newrelic_license_key => '8aaf631d914a4376ade0eccdbc1eaade8ec79130',
  #}

  class { 'apache':
    default_mods     => false,
    default_vhost    => false,
    purge_configs    => false,
    vhost_dir        => '/etc/httpd/sites-available',
    confd_dir        => '/etc/httpd/conf.d',
    mpm_module       => 'prefork',
    server_signature => 'Off',
    trace_enable     => 'Off',
    server_tokens    => 'Prod',
  }

  apache::custom_config { 'welcome':
    ensure   => present,
    source   => 'puppet:///modules/apache/welcome.conf',
    priority => false,
  }

  include apache::mod::php
  include apache::mod::autoindex
  include apache::mod::alias
  include apache::mod::dir
  include apache::mod::mime
  include apache::mod::rewrite

  apache::vhost { 'www.cecmed.cu':
    ensure        => present,
    serveraliases => ['www.cecmed.cu'],
    port          => '80',
    docroot       => '/var/www/www.cecmed.cu',
    priority      => false,
    log_level     => 'warn',
    directories   => [
      {
        path           => '/var/www/www.cecmed.cu',
        allow          => 'from all',
        order          => 'Allow,Deny',
        allow_override => ['All'],
        options        => ['Indexes','FollowSymLinks','MultiViews','ExecCGI'],
        # NOTE Clean URLs configuration
        rewrites       => [
          {
            rewrite_base => '/',
            rewrite_cond => ['%{REQUEST_FILENAME} !-f',
                            '%{REQUEST_FILENAME} !-d',
                            '%{REQUEST_URI} !=/favicon.ico'
                            ],
            rewrite_rule => ['^ index.php [L]'],
          },
        ],
      },
    ],
  }

  apache::vhost { 'drupal.cecmed.cu':
    ensure        => absent,
    serveraliases => ['drupal.cecmed.cu'],
    port          => '80',
    docroot       => '/var/www/drupal.cecmed.cu',
    priority      => false,
    log_level     => 'warn',
    directories   => [
      {
        path           => '/var/www/drupal.cecmed.cu',
        allow          => 'from all',
        order          => 'Allow,Deny',
        allow_override => ['All'],
        options        => ['Indexes','FollowSymLinks','MultiViews','ExecCGI'],
        # NOTE Clean URLs configuration
        rewrites       => [
          {
            rewrite_base => '/',
            rewrite_cond => ['%{REQUEST_FILENAME} !-f',
                            '%{REQUEST_FILENAME} !-d',
                            '%{REQUEST_URI} !=/favicon.ico'
                            ],
            rewrite_rule => ['^ index.php [L]'],
          },
        ],
      },
    ],
  }

  file { '/var/www/www.cecmed.cu/info.php':
    ensure => present,
    source => 'puppet:///modules/apache/info.php',
  }

  # NOTE Firewall configuration for web access
  firewall { '100 allow http & https access':
    ensure => present,
    dport  => ['80','443'],
    proto  => tcp,
    action => accept,
  }

}

node testserver {

  # Firewall configuration
  firewall { '100 allow http & https access':
    ensure => present,
    dport  => ['80','443'],
    proto  => tcp,
    action => accept,
  }

}
