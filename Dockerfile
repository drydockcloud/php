ARG SOURCE=centos:7

FROM $SOURCE


# Install Apache httpd and PHP
RUN set -eux ; \
	yum install -y centos-release-scl && \
	INSTALL_PKGS="rh-php72 rh-php72-php rh-php72-php-mysqlnd rh-php72-php-pgsql rh-php72-php-bcmath \
	rh-php72-php-gd rh-php72-php-intl rh-php72-php-ldap rh-php72-php-mbstring rh-php72-php-pdo \
	rh-php72-php-process rh-php72-php-soap rh-php72-php-opcache rh-php72-php-xml \
	rh-php72-php-gmp rh-php72-php-pecl-apcu httpd24-mod_ssl" && \
	yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS --nogpgcheck && \
	rpm -V $INSTALL_PKGS && \
	yum -y clean all --enablerepo='*'


ENV SCL_ENABLED=rh-php72 \
	PATH=${PATH}:/opt/rh/rh-php72/root/usr/bin

EXPOSE 9000
CMD ["php-fpm"]
