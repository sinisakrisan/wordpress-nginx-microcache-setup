# Define path to cache and memory zone. The memory zone should be unique.
# keys_zone=sinisakrisan.com:100m creates the memory zone and sets the maximum size in MBs.
# inactive=60m will remove cached items that haven't been accessed for 60 minutes or more.

fastcgi_cache_path /var/www/sinisakrisan.com/cache levels=1:2 keys_zone=sinisakrisan.com:100m inactive=60m;

server {
	# Ports to listen on
	listen 80;
	listen [::]:80;

	# Server name to listen for
	server_name sinisakrisan.com;

	# Path to document root
	root /var/www/sinisakrisan.com;

	# File to be used as index
	index index.php;

	# Overrides logs defined in nginx.conf, allows per site logs.
	access_log /var/www/sinisakrisan.com/logs/access.log;
	error_log /var/www/sinisakrisan.com/logs/error.log;

	# Default server block rules
	include global/server/defaults.conf;

	# Fastcgi cache rules
	include global/server/fastcgi-cache.conf;

	location / {
		try_files $uri $uri/ /index.php?$args;
	}

	location ~ \.php$ {
		try_files $uri =404;
		include global/fastcgi-params.conf;

		# Use the php pool defined in the upstream variable.
		# See global/php-pool.conf for definition.
		fastcgi_pass   $upstream;

		# Skip cache based on rules in global/server/fastcgi-cache.conf.
		fastcgi_cache_bypass $skip_cache;
		fastcgi_no_cache $skip_cache;

		# Define memory zone for caching. Should match key_zone in fastcgi_cache_path above.
		fastcgi_cache sinisakrisan.com;

		# Define caching time.
		fastcgi_cache_valid 60m;
	}

	# Rewrite robots.txt
	rewrite ^/robots.txt$ /index.php last;

	# Uncomment if using the fastcgi_cache_purge module and Nginx Helper plugin (https://wordpress.org/plugins/nginx-helper/)
	# location ~ /purge(/.*) {
	#	fastcgi_cache_purge sinisakrisan.com "$scheme$request_method$host$1";
	# }
}

# Redirect www to non-www
server {
	listen 80;
	listen [::]:80;
	server_name www.sinisakrisan.com;

	return 301 $scheme://sinisakrisan.com$request_uri;
}
