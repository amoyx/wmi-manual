## 对外访问的域名
external_url 'http://gitlab.example.com'

### Email Settings 邮箱设置
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.server"
gitlab_rails['smtp_port'] = 465
gitlab_rails['smtp_user_name'] = "smtp user"
gitlab_rails['smtp_password'] = "smtp password"
gitlab_rails['smtp_domain'] = "example.com"
gitlab_rails['smtp_authentication'] = "login"
# gitlab_rails['smtp_enable_starttls_auto'] = true
# gitlab_rails['smtp_tls'] = false


### LDAP Settings  LDAP设置
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = YAML.load <<-'EOS'
   main: # 'main' is the GitLab 'provider ID' of this LDAP server
     label: 'LDAP'
     host: '192.168.100.250' 
     port: 389
     uid: 'sAMAccountName'
     bind_dn: 'ad用户'
     password: 'ad用户密码'
     encryption: 'plain' # "start_tls" or "simple_tls" or "plain"
     verify_certificates: true
     ca_file: ''
     ssl_version: ''
     active_directory: true
     allow_username_or_email_login: false
     block_auto_created_users: false
     base: 'ou=ou,dc=dc,dc=dc,dc=cn'
     user_filter: '(&(objectClass=user)(sAMAccountName=*))'
     attributes:
       username: ['uid', 'userid', 'sAMAccountName']
       email:    ['mail', 'email', 'userPrincipalName']
       name:       'cn'
       first_name: 'givenName'
       last_name:  'sn'
     group_base: 'ou=ou,dc=dc,dc=dc,dc=cn'
     admin_group: ''
     sync_ssh_keys: false
EOS

### Backup Settings 备份设置
gitlab_rails['manage_backup_path'] = true
gitlab_rails['backup_path'] = "/var/opt/gitlab/backups"   # gitlab数据备份

### GitLab NGINX  nginx配置，比如https配置
nginx['enable'] = true
nginx['client_max_body_size'] = '250m'
nginx['redirect_http_to_https'] = true
nginx['redirect_http_to_https_port'] = 80
nginx['ssl_certificate'] = "/etc/gitlab/ssl/#{node['fqdn']}.crt"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/#{node['fqdn']}.key"
 