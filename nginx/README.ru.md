# Набор скриптов для автоматизированного создания простых хостинговы прощадок на nginx + php-fpm

[In English / По-английски](README.md)

Здесь представлен набор простых скриптов для автоматизированного создания простых хостинговы прощадок на nginx + php-fpm<br>

Файл nginx.conf содержит базовые настройки для системы Debian 8.x и nginx 1.10.x/1.11.x<br>

В директории common представлены минимально необходимые файлы конфигурации для работы php на создаваемых скриптами площадках.<br>

В файлах template/*.template содержаться шаблоны для создания площадок.<br>
nginx_virtual_host.template - шаблон создания хоста для nginx<br>
php_fpm.conf.template - шаблон создания пуля для php-fpm<br>
index.html.template - шаблон создания файла index.html<br>
robots.txt.template - шаблон создания файла robots.txt<br>

Скрипты nginx-create-vhost.sh и nginx-remove-vhost.sh предназначены для быстрого создания хостинговой площадки.<br>

Пример создания площадки: ./nginx-create-vhost.sh -d "domain.com"<br>

Скрипт выполняет следующие действия:<br>

1. Создает linux пользователя и группу на основе настроек из settings.conf, добавляет пользователя в созданную группу.<br>

2. Создает папку /var/www/domain.com и подпапки:<br>
web - для размещения файлов сайта<br>
private - для размещения приватных файлов<br>
tmp - папка для хранения временных и сессионых файлов<br>
log - папка для хранения лог-файлов nginx и php-fpm<br>

3. Для папки /var/www/domain.com назначает необходимые права и владельца из п.1<br>

4. Создает файл конфигурации для nginx в папке указаной в переменной NGINX_VHOST_DIR, по-умолчанию это /etc/nginx/sites-available<br>
   Создает симлинк для этого файла в по указаному в переменной NGINX_VHOST_SITE_ENABLED_DIR пути, по-умолчанию это /etc/nginx/sites-enabled<br>

5. Создает файл конфигурации пула для php-fpm, файл создается по указаному в переменной PHP_FPM_POOL_DIR пути, по-умолчанию это /etc/php5/fpm/pool.d<br>

6. Создает в папке /var/www/domain.com/web простой файл index.html и robots.txt<br>

7. Проверяет конфигурацию nginx и перезапускает его, перезапускает php-fpm<br>

Пример удаления плошадки: ./nginx-remove-vhost.sh -d "domain.com" -u web1 -g client1<br>

Скрипт nginx-remove-vhost.sh удаляет все, что создает nginx-create-vhost.sh, а именно: директорию сайта, пользователя и группу, файл хоста для nginx и файл пула для php-fpm.<br>

Автор: Михаил Григорьев  < sleuthhound at gmail dot com >


