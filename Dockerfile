ARG SOURCE=centos:7

FROM $SOURCE

# PHP version as used in package names, no dot (.) separator.
ARG PHP_VER=72

ENV \
	PHP_VER=${PHP_VER} \
	INSTALL_PKGS="\
	httpd24 \
	httpd24-mod_ssl \
	rh-php${PHP_VER} \
	rh-php${PHP_VER}-php \
	rh-php${PHP_VER}-php-mysqlnd \
	rh-php${PHP_VER}-php-pgsql \
	rh-php${PHP_VER}-php-bcmath \
	rh-php${PHP_VER}-php-gd \
	rh-php${PHP_VER}-php-intl \
	rh-php${PHP_VER}-php-ldap \
	rh-php${PHP_VER}-php-mbstring \
	rh-php${PHP_VER}-php-pdo \
	rh-php${PHP_VER}-php-process \
	rh-php${PHP_VER}-php-soap \
	rh-php${PHP_VER}-php-opcache \
	rh-php${PHP_VER}-php-xml \
	rh-php${PHP_VER}-php-gmp \
	rh-php${PHP_VER}-php-pecl-apcu \
	" \
	SCL_ENABLED=rh-php${PHP_VER} \
	\
	PHP_PATH=/opt/rh/rh-php${PHP_VER}/root/usr/bin \
	APACHE_PATH=/opt/rh/httpd24/root/usr/bin:/opt/rh/httpd24/root/usr/sbin \
	PATH="${PHP_PATH}:${APACHE_PATH}:${PATH}"

# Install Apache httpd and PHP
RUN set -eux ; \
	yum install -y centos-release-scl && \
	yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS --nogpgcheck && \
	rpm -V $INSTALL_PKGS && \
	yum -y clean all --enablerepo='*' && \
	rm -rf /var/cache/yum

EXPOSE 9000
CMD ["php-fpm"]

