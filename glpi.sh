#!/usr/bin/env bash
set -e

#############################################
# GLPI Automated Installer for Ubuntu 24.04 #
#############################################

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root (use sudo)"
  exit 1
fi

echo "=== GLPI Installation Script ==="

# --- Prompt for variables ---
read -rp "Enter GLPI database name [glpidb]: " GLPI_DB
GLPI_DB=${GLPI_DB:-glpidb}

read -rp "Enter GLPI database user [glpiuser]: " GLPI_DB_USER
GLPI_DB_USER=${GLPI_DB_USER:-glpiuser}

read -rsp "Enter GLPI database password: " GLPI_DB_PASS
echo
read -rsp "Confirm GLPI database password: " GLPI_DB_PASS_CONFIRM
echo

if [[ "$GLPI_DB_PASS" != "$GLPI_DB_PASS_CONFIRM" ]]; then
  echo "Passwords do not match"
  exit 1
fi

read -rp "Enter GLPI ServerName (DNS or IP) [glpi.local]: " GLPI_SERVERNAME
GLPI_SERVERNAME=${GLPI_SERVERNAME:-glpi.local}

echo "Variables set"
sleep 1

################################
# Refresh system repositories #
################################
echo "Updating system..."
apt update
apt upgrade -y

####################
# Install Apache  #
####################
echo "Installing Apache..."
apt install apache2 -y

systemctl enable apache2
systemctl start apache2

######################
# Install MariaDB   #
######################
echo "Installing MariaDB..."
apt install mariadb-server mariadb-client -y

systemctl enable mariadb
systemctl start mariadb

echo "MariaDB secure installation will start now"
echo "Recommended answers:"
echo "  Switch to unix_socket authentication → Y"
echo "  Change root password → N"
echo "  Remove anonymous users → Y"
echo "  Disallow root login remotely → Y"
echo "  Remove test database → Y"
echo "  Reload privilege tables → Y"
sleep 3

mysql_secure_installation

########################################
# Install PHP and required extensions  #
########################################
echo "Installing PHP and extensions..."
apt install -y \
php libapache2-mod-php \
php-mysql php-gd php-xml php-mbstring php-curl php-zip \
php-intl php-bz2 php-ldap php-imap

#############################
# Create GLPI database     #
#############################
echo "Creating GLPI database..."

mysql <<EOF
CREATE DATABASE IF NOT EXISTS ${GLPI_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${GLPI_DB_USER}'@'localhost' IDENTIFIED BY '${GLPI_DB_PASS}';
GRANT ALL PRIVILEGES ON ${GLPI_DB}.* TO '${GLPI_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

################################
# Download and install GLPI    #
################################
echo "⬇ Downloading latest GLPI..."

cd /tmp
curl -fsSL https://github.com/glpi-project/glpi/releases/download/11.0.4/glpi-11.0.4.tgz -o glpi.tgz

echo "Extracting GLPI..."
tar -xzf glpi.tgz

echo "Moving GLPI to /var/www..."
mv glpi /var/www/

#################################
# Set correct permissions       #
#################################
echo "Setting permissions..."
chown -R www-data:www-data /var/www/glpi
chmod -R 755 /var/www/glpi

#################################
# Configure Apache VirtualHost  #
#################################
echo "Configuring Apache VirtualHost..."

cat <<EOF > /etc/apache2/sites-available/glpi.conf
<VirtualHost *:80>
    ServerName ${GLPI_SERVERNAME}
    DocumentRoot /var/www/glpi/public
    #Redirect permanent / https://${GLPI_SERVERNAME}/


    <Directory /var/www/glpi/public>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF

cat <<EOF > /etc/apache2/sites-available/glpi-ssl.conf
<VirtualHost *:443>
    ServerName ${GLPI_SERVERNAME}
    DocumentRoot /var/www/glpi/public

    SSLEngine on
    SSLCertificateFile      /etc/ssl/certs/csf.crt
    SSLCertificateKeyFile   /etc/ssl/private/csf.key

    <Directory /var/www/glpi/public>
        #AllowOverride All
        #Require all granted
        #RewriteEngine On
        #RewriteCond %{REQUEST_FILENAME} !-f
        #RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/glpi_ssl_error.log
    CustomLog ${APACHE_LOG_DIR}/glpi_ssl_access.log combined
</VirtualHost>
EOF

a2enmod rewrite
a2enmod ssl
a2ensite glpi.conf
a2dissite 000-default.conf

systemctl reload apache2

###################
# Final message  #
###################
echo "GLPI installation files deployed successfully!"
echo "Open your browser and go to:"
echo "http://${GLPI_SERVERNAME}"
echo
echo "Use these database settings during web installer:"
echo "Database: ${GLPI_DB}"
echo "User: ${GLPI_DB_USER}"
echo "Password: (the one you entered)"
echo
echo "Installation ready!"
