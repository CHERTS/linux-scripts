# A scripts to automate the creation of simple web hosting to nginx + php-fpm

[По-русски / In Russian](README.ru.md)

Here is a simple scripts to automate the creation of simple web hosting to nginx + php-fpm<br>

nginx.conf file contains the basic settings for the system Debian 8.x and nginx 1.8.x/1.9.x<br>

The directory common/ a minimum necessary configuration files for php on sites created scripts.<br>

Scripts nginx-create-vhost.sh and nginx-remove-vhost.sh designed to quickly create a hosting site using php-fpm<br>

Example of creating site: ./nginx-create-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1<br>

The script does the following:<br>

1. Creates linux user and group, add users to the new group.<br>

2. Create a folder and subfolders /var/www/domain.com:<br>
web - site for the files<br>
private - to private files<br>
tmp - temporary files and session files<br>
log - log files nginx and php-fpm <br>

3. Set permissions for the folder, and the owner /var/www/domain.com<br>

4. Create a configuration file for nginx in a folder of a specified variable NGINX_VHOST_DIR, default is /etc/nginx/sites-available<br>
It creates a symbolic link to the file in an indication of variable NGINX_VHOST_SITE_ENABLED_DIR way, the default is /etc/nginx/sites-enabled<br>

5. Create a configuration file pool for php-fpm, a file is created on the instructions of variable PHP_FPM_POOL_DIR way, the default is /etc/php5/fpm/pool.d<br>

6. Create a folder /var/www/domain.com/web simple index.html file and robots.txt<br>

7. Checks nginx configuration and restarts it, restart php-fpm<br>

Example of deleting site: ./nginx-remove-vhost.sh -s "/var/www/domain.com" -d "domain.com" -u web1 -g client1<br>

nginx-remove-vhost.sh script removes everything that creates nginx-create-vhost.sh, site directory, user and group, hosts file for nginx and pool file for php-fpm.<br>

Author: Mikhail Grigoryev <sleuthhound@gmail.com>
