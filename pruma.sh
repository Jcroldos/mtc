#!/bin/bash
set -e

while [[ "$AUTH" != "yes" ]]; do
	clear;
	OK="";
	echo -e "\033[41;1;37m===========================================";
	echo -e "\e[1m  INSTALADOR PETECO            \e[21m";
	echo -e "===========================================\033[0m";

	echo -e "\n\nEste script instalará los siguientes items en su servidor:\n\033[1;33m"
	echo -e " - Docker\n - Portainer\n - Nginx-proxy + Letsencrypt\n - MySQL (base de datos)\n - PHPmyadmin\n - Mautic\033[0m\n";

		echo -e "\033[0;36mSu nombre:\033[0m";
		read CLIENT_NAME
		echo -e "====================================================";

		echo -e "\033[0;36mSu email:\033[0m";
		read CLIENT_EMAIL;
		echo -e "====================================================";

		echo -e "\033[0;36mNombre de usuario para Mautic:\033[0m";
		read USER_NAME;
		echo -e "====================================================";

		echo -e "\033[0;36mPassword para Mautic:\033[0m";
		read USER_PASSWORD;
		echo -e "====================================================";

		echo -e "\033[0;36mSubdomínio para Mautic:\033[0m Ex.\e[1mmkt.sudominio.com\e[21m\033[0m";
		read DOMAIN;
		echo -e "====================================================";

	echo -e "Confirme sus datos";
	echo -e "Nombre del cliente: \033[41;1;37m $CLIENT_NAME \033[0m";
	echo -e "Email del cliente: \033[41;1;37m $CLIENT_EMAIL \033[0m";
	echo -e "Username: \033[41;1;37m $USER_NAME \033[0m";
	echo -e "Password: \033[41;1;37m $USER_PASSWORD \033[0m";
	echo -e "Dominio: \033[41;1;37m $DOMAIN \033[0m";

	echo -e "\n¿Los datos están correctos?";

	while [[ "$OK" != "yes" && "$OK" != "no" ]];
	do
		echo -e "\033[1;33m"; read -p " yes / no  " OK;
		echo -e "\033[0m";
	done

	if [ "$OK" == "yes" ]; then
		AUTH="yes";
	fi
done



# Instalando los programas y configurando timezone.
echo -e "CONFIGURANDO EL SERVIDOR (espere algunos segundos)";
echo -e "====================================================\n";
echo -e "Bajando programas";
#if [ ! -e /usr/bin/bcrypt ]; then
	wget https://f002.backblazeb2.com/file/mtcfacil/bcrypt  -O /usr/bin/bcrypt 2>dev>null;
	chmod +x /usr/bin/bcrypt;
#fi

echo -e "Encriptando contraseñas";
HASH_MTC=$(echo -n "$USER_PASSwORD"|bcrypt --cost=13|xargs);
HASH_PORT=$(echo -n "$USER_PASSwORD"|bcrypt --cost=5);
DOMAIN_CLEAN=$(echo -e "$DOMAIN"|tr . _ );
echo -e "Instalando complementos";
(apt-get -yqqq update 2>dev>null; apt-get -yqqqq install curl nano zip unzip wget) 2>dev>null;
(apt-get -yqqq clean 2>dev>null; apt-get -yqqq autoclean 2>dev>null; rm -rf /var/cache/apk/*; apt -yqqq autoremove --purge snapd) 2>dev>null;
echo -e "Limpando residuos";

#if [ -z $(egrep -qi 'swapfile' /etc/fstab) ]; then
#	(fallocate -l 2G /swapfile; chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile; echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab;) >/dev/null 2>&1;
#fi

echo -e "\033[0;32m=====================EXITO========================\n\033[0m";

# Instala los programas para Docker
echo -e "INSTALANDO DOCKER";
echo -e "====================================================\n";
curl -fsSL https://get.docker.com -o get-docker.sh; sudo sh get-docker.sh 2>dev>null;
docker network create -d bridge mysql;
docker network create -d bridge public;
service docker start 2>dev>null;
systemctl start docker 2>dev>null;
echo -e "\033[0;32m=====================EXITO========================\n\033[0m";

# Instala Nginx Reverse Proxy
echo -e "INSTALANDO NGINX";
echo -e "====================================================\n";
{ echo -e "server_tokens off;"; echo -e "client_max_body_size 256m;"; } > /root/my_proxy.conf;
docker run --detach --restart always --name nginx-proxy --network=public --publish 80:80 --publish 443:443 \
--volume nginx_certs:/etc/nginx/certs --volume nginx_vhost:/etc/nginx/vhost.d --volume nginx_usr:/usr/share/nginx/html \
--volume /var/run/docker.sock:/tmp/docker.sock:ro --volume /root/my_proxy.conf:/etc/nginx/conf.d/my_proxy.conf:ro jwilder/nginx-proxy;
echo -e "\033[0;32m=====================EXITO========================\n\033[0m";

# Instala Let"s Encrypt
echo -e "INSTALANDO LETS ENCRYPT";
echo -e "====================================================\n";
docker run --detach --name letsencrypt --restart always --network=public --volumes-from nginx-proxy \
--volume /var/run/docker.sock:/var/run/docker.sock:ro jrcs/letsencrypt-nginx-proxy-companion;
echo -e "\033[0;32m=====================EXITO========================\n\033[0m";

# Instala Portainer
echo -e "INSTALANDO PORTAINER";
echo -e "====================================================\n";
docker run -d --name portainer --restart always -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock \
-v portainer_data:/data portainer/portainer-ce:latest;
sleep 5;
echo -e "\033[0;32m=====================EXITO========================\n\033[0m";

# Instala MySQL
echo -e "INSTALANDO MYSQL";
echo -e "====================================================\n";
db_pass_random="$(date +%s | sha256sum | base64 | head -c 16)";
docker run -d --name mysql --restart always --network=mysql -v mysql_data:/var/lib/mysql \
-e MYSQL_ROOT_PASSWORD="$db_pass_random" mysql:8.0 --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci;
echo -e "\033[0;32m=====================EXITO========================\n\033[0m";

# Instala o PHPMyAdmin
echo -e "INSTALANDO PHPMYADMIN";
echo -e "====================================================\n";
docker run -d --name phpmyadmin --restart always --network=mysql -p 8050:80 \
-v phpmyadmin:/var/www/html -e PMA_HOST=mysql -e PMA_PORT=3306 phpmyadmin/phpmyadmin:latest;
echo -e "\033[0;32m=====================EXITO========================\n\033[0m";

# Instala Mautic
echo -e "INSTALANDO MAUTIC";
echo -e "====================================================\n";

docker pull leonardoborlot/mtcfacil:mtc412;

docker run -d --name "$DOMAIN_CLEAN" \
-v "$DOMAIN_CLEAN"_data:/var/www/html \
-v "$DOMAIN_CLEAN"_backup:/var/www/backup \
--restart always --network mysql \
-e MAUTIC_DB_HOST=mysql \
-e MAUTIC_DB_USER=root \
-e MAUTIC_DB_PASSWORD="$db_pass_random" \
-e MAUTIC_DB_NAME="$DOMAIN_CLEAN" \
-e VIRTUAL_HOST="$DOMAIN" \
-e LETSENCRYPT_HOST="$DOMAIN" \
-e LETSENCRYPT_EMAIL="$CLIENT_EMAIL" \
-e USER_NAME="$USER_NAME" \
-e USER_PASSWORD="$USER_PASSWORD" \
-e CLIENT_NAME="$CLIENT_NAME" \
-e CLIENT_EMAIL="$CLIENT_EMAIL" \
-e START_DB="true" \
-e AUTO_INSTALL="true" \
leonardoborlot/mtcfacil:mtc412;

docker network connect public "$DOMAIN_CLEAN";
docker stop portainer 2>dev>null;
echo -e "\033[0;32m=====================EXITO========================\n\033[0m";


#Mensagem final.
echo -e "\033[0;32m=========Su Mautic fue instalado com éxito==========\n\033[0m";
echo -e "Algunos procedimoentos están siendo finalizados en background, \nen algunos minutos su instalación \
estará disponible.\nNo se olvide de apuntar su dominio para el servidor donde fue instalado.\n\n";
echo -e "\033[44;1;37m====================================================\033[0m";
echo -e "===============  DATOS DE ACESSO  ==================";
echo -e "\033[44;1;37m====================================================\033[0m";
echo -e "\nGuarde sus datos de acesso para futuros ajustes y mantenimientos.\n\n";
echo -e "Usuario de Mautic:" "\033[1;33m $USER_NAME\033[0m";
echo -e "Email de Mautic:" "\033[1;33m $CLIENT_EMAIL\033[0m";
echo -e "Password inicial de Mautic:" "\033[1;33m $USER_PASSWORD\033[0m\n";

echo -e "Nombre de Base de Datos:" "\033[1;33m $DOMAIN_CLEAN\033[0m";
echo -e "Password de la Base de Datos:" "\033[1;33m $db_pass_random\033[0m";
echo -e "Usuario de la Base de Datos:" "\033[1;33m root\033[0m\n\n";

echo -e "El Portainer no se está ejecutando. Para iniciarlo, execute el comando:";
echo -e "\033[1;33mdocker start portainer\033[0m\n";

echo -e "====================================================";
echo -e "Cualquier duda, busque información en:\033[0;36m https://mtcfacil.com.br\033[0m";
echo -e "====================================================\n\n\n\n";
sleep 5;