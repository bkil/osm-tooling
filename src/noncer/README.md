# noncer

## Usage

* Run the code through a web server as per below.
* Open the network inspector tab within your web browser
* Visit the web page of interest and commence an action tied to what you would like to test.
* Find the request to the resource of interest in the network inspector
* Right click on it, then select copy - as CURL
* Open the local URL of the running code on a new tab (e.g., http://localhost:12340/ )
* Paste in the CURL command and press submit. This will store (or update) all headers (including authorization and session ID) for the given domain and also the post body content connected to the template of the fetched URL. You will have to repeat this step once for each template within the domain.
* You will then receive a templated URL that can act as a shorthand to the original request. Copy & paste it where needed.
* If your session expires, log in again and just submit the CURL code of a new request in the browser to the domain on the above form.

## Running the code

You have multiple choices.

### Your own private server

For best results, it should support concurrent execution of multiple scripts (e.g., Apache/nginx via FCGI). It must be on a trusted machine either on localhost or over a VPN:

* It does not protect the endpoint
* It may store unencrypted session data in your web root (or in `src`)

### nginx and php-fpm as a user

```
sudo apt install nginx-core php-fpm

systemctl list-unit-files |
grep 'php.*-fpm' |
cut -d ' ' -f 1 |
xargs sudo systemctl disable

cd src
ln -s /etc/nginx/fastcgi.conf .

cat <<EOF > php-fpm.conf
[global]
pid = $PWD/php-fpm.pid
error_log = $PWD/php-fpm.log
[www]
listen = $PWD/php-fpm.sock
pm = ondemand
pm.max_children = 16
EOF

/usr/sbin/php-fpm* -y php-fpm.conf

cat <<EOF > nginx.conf
pid $PWD/nginx.pid;
error_log $PWD/error-0.log;
events {
}
http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  error_log $PWD/error-1.log;
  access_log $PWD/access.log;

  server {
    listen 12340 default_server;
    root $PWD;
    index index.php
    server_name _;
    location ~ \.php\$ {
        include /etc/nginx/snippets/fastcgi-php.conf;
        fastcgi_pass unix:php-fpm.sock;
    }
  }
}
EOF

nginx -c $PWD/nginx.conf
```

### PHP 7.4+ built-in web server

```
cd src
PHP_CLI_SERVER_WORKERS=8 php -S localhost:12340
```

### PHP 7.3- built-in web server

It will be very slow due to being blocking and serving requests on a single thread.

```
cd src
php -S localhost:12340
```
