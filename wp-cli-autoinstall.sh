#!/bin/bash
VERSION='0.0.2'
YES='y'
NO='n'
LOCALE="en_US"
DB_HOST='localhost'
USER='www-data'
GROUP='www-data'

printf "WordPress autoinstaller for WP-CLI v $VERSION.\n"

#Optional Mysql DB and user creation
printf "MySQL DB and user creation. You will need mysql root password for this. Skip to the next step?[y/n] "

read SKIP_DB

if [ "$SKIP_DB" != "$YES" ]; 
	then
	
		MYSQL=`which mysql`
		printf "DB name: "
		read DB_NAME
		printf "DB user: "
		read DB_USER
		printf "Generate DB password? [y/n] "
		read GEN_PASS
		if [ "$GEN_PASS" = "$YES" ];
		then
			DB_PASS=`openssl rand -base64 32`
			
		else
			printf "DB password: "
			read DB_PASS
		fi
		printf "New database with name $DB_NAME and user $DB_USER will be created. Type in MySQL root password.\n"
		
		#Create SQL Query
		Q1="CREATE DATABASE IF NOT EXISTS $DB_NAME;"
		Q2="GRANT USAGE ON *.* TO $DB_USER@localhost IDENTIFIED BY '$DB_PASS';"
		Q3="GRANT ALL PRIVILEGES ON $DB_NAME.* TO $DB_USER@localhost;"
		Q4="FLUSH PRIVILEGES;"
		SQL="${Q1}${Q2}${Q3}${Q4}"
		$MYSQL -uroot -p -e "$SQL"
	else
		printf "DB name: "
		read DB_NAME
		printf "DB user: "
		read DB_USER
		printf "DB password: "
		read DB_PASS	
fi


printf "WP core installation.\n"
printf "Web URL: "
read WP_URL
printf "Web Title: "
read WP_TITLE
printf "Admin e-mail: "
read WP_EMAIL
printf "Admin username: "
read WP_ADMIN
printf "Admin password (won't be echoed): "
read -s WP_PASS
echo
printf "Web DB prefix: "
read WP_PREFIX

INSTALL_PATH="/var/www/html/$WP_URL"
printf "Provide sudo password for install directory creation\n"
sudo mkdir "$INSTALL_PATH"
sudo chown "$USER:$GROUP" "$INSTALL_PATH"
sudo chmod 775 "$INSTALL_PATH"

# Install WordPress and create the wp-config.php file...
wp core download --path="$INSTALL_PATH" --locale="$LOCALE" 
wp core config --path="$INSTALL_PATH" --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" --dbhost="$DB_HOST" --dbprefix="$WP_PREFIX" 
wp core install --path="$INSTALL_PATH" --title="$WP_TITLE" --url="http://$WP_URL" --admin_user="$WP_ADMIN" --admin_email="$WP_EMAIL" --admin_password="$WP_PASS" 

cd $INSTALL_PATH

# Update WordPress options
wp option update permalink_structure '/%postname%/'  
wp option update default_ping_status 'closed'  
wp option update default_pingback_flag '0'  

#printf "WP users setup. Skip to next step?[y/n]\n"

printf "WP plugins installation. Skip to next step?[y/n]: "
read SKIP_PLUGINS

if [ "$SKIP_PLUGINS" != "$YES" ]; 
	then
	# Install and activate default plugins
	wp plugin install coming-soon better-wp-security wordpress-seo  --activate 
	
fi	

sudo chown -R "$USER:$GROUP" "$INSTALL_PATH"

printf "NGINX configuration. Skip to next step?[y/n]: "
read SKIP NGINX
if [ "$SKIP_NGINX" != "$YES" ]; 
	then
	printf "nginx setup\n"
	NGNIX_CONFIG="server {
	
	listen 80;
	listen [::]:80;
	root $INSTALL_PATH;
	index index.php;
	server_name $WP_URL;
	
	include restrictions.conf;
	include wpsc.conf;
	
	}"
	
	# Write conf file
	printf "$NGNIX_CONFIG" | sudo tee "/etc/nginx/sites-available/$WP_URL" > /dev/null
	# Create link in sites-enabled
	sudo ln -s "/etc/nginx/sites-available/$WP_URL" "/etc/nginx/sites-enabled/$WP_URL"
	# Test settings and reload
	sudo nginx -t && sudo nginx -s reload

fi
