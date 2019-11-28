#
# This initial code was mostly copied from https://github.com/docker-library/php/blob/master/7.3/buster/cli/Dockerfile then adapted for Centos and Redhat family base images.
#

FROM centos:7

# dependencies required for running "phpize"
# these get automatically installed and removed by "docker-php-ext-*" (unless they're already installed)
ENV PHPIZE_DEPS \
	autoconf \
	dpkg-dev dpkg \
	file \
	g++ \
	gcc \
	libc-dev \
	make \
	pkgconf \
	re2c

# persistent / runtime deps
RUN yum install -y \
	ca-certificates \
	curl \
	tar \
	xz \
	# https://github.com/docker-library/php/issues/494
	openssl

# ensure www-data user exist. @TODO is this needed?
RUN set -eux; \
	groupadd -g 82 -r www-data -f; \
	useradd -u 82 -r -g www-data www-data

ENV PHP_INI_DIR /usr/local/etc/php
RUN set -eux; \
	mkdir -p "$PHP_INI_DIR/conf.d"; \
	# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
	[ ! -d /var/www/html ]; \
	mkdir -p /var/www/html; \
	chown www-data:www-data /var/www/html; \
	chmod 777 /var/www/html

ENV PHP_EXTRA_CONFIGURE_ARGS --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --disable-cgi

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

ENV GPG_KEYS CBAF69F173A0FEA4B537F470D66C9593118BCCB6 F38252826ACD957EF380D39F2F7956BC5DA04B5D

ENV PHP_VERSION 7.3.12
ENV PHP_URL="https://www.php.net/get/php-7.3.12.tar.xz/from/this/mirror" PHP_ASC_URL="https://www.php.net/get/php-7.3.12.tar.xz.asc/from/this/mirror"
ENV PHP_SHA256="aafe5e9861ad828860c6af8c88cdc1488314785962328eb1783607c1fdd855df" PHP_MD5=""

RUN set -eux; \
	\
	yum install -y gnupg2; \
	\
	mkdir -p /usr/src; \
	cd /usr/src; \
	\
	curl -fsSL -o php.tar.xz "$PHP_URL"; \
	\
	if [ -n "$PHP_SHA256" ]; then \
	echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
	fi; \
	if [ -n "$PHP_MD5" ]; then \
	echo "$PHP_MD5 *php.tar.xz" | md5sum -c -; \
	fi; \
	\
	if [ -n "$PHP_ASC_URL" ]; then \
	curl -fsSL -o php.tar.xz.asc "$PHP_ASC_URL"; \
	export GNUPGHOME="$(mktemp -d)"; \
	for key in $GPG_KEYS; do \
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	done; \
	gpg --batch --verify php.tar.xz.asc php.tar.xz; \
	#@TODO fix:
	# gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	fi;

ADD https://raw.githubusercontent.com/docker-library/php/master/docker-php-source /usr/local/bin/
ADD https://raw.githubusercontent.com/docker-library/php/master/docker-php-entrypoint /usr/local/bin/
ADD https://raw.githubusercontent.com/docker-library/php/master/docker-php-ext-configure /usr/local/bin/
ADD https://raw.githubusercontent.com/docker-library/php/master/docker-php-ext-enable /usr/local/bin/
ADD https://raw.githubusercontent.com/docker-library/php/master/docker-php-ext-install /usr/local/bin/
ADD https://raw.githubusercontent.com/docker-library/php/master/docker-php-source /usr/local/bin/

RUN set -eux; \
	chmod -v +x /usr/local/bin/docker-php-*

RUN set -eux; \
	yum install -y \
	$PHPIZE_DEPS \
	#argon2-devel \
	coreutils \
	curl-devel \
	libedit-devel \
	#libsodium-devel \
	libxml2-devel \
	openssl-devel \
	sqlite-devel \
	; \
	\
	export \
	CFLAGS="$PHP_CFLAGS" \
	CPPFLAGS="$PHP_CPPFLAGS" \
	LDFLAGS="$PHP_LDFLAGS" \
	; \
	docker-php-source extract; \
	cd /usr/src/php; \
	gnuArch="$(arch)"; \
	./configure \
	--build="$gnuArch" \
	--with-config-file-path="$PHP_INI_DIR" \
	--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
	\
	# make sure invalid --configure-flags are fatal errors intead of just warnings
	--enable-option-checking=fatal \
	\
	# https://github.com/docker-library/php/issues/439
	--with-mhash \
	\
	# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
	--enable-ftp \
	# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
	--enable-mbstring \
	# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
	--enable-mysqlnd \
	# https://wiki.php.net/rfc/argon2_password_hash (7.2+)
	# @TODO missing argon2 package
	#--with-password-argon2 \
	# https://wiki.php.net/rfc/libsodium
	# @TODO missing libsodium package
	#--with-sodium=shared \
	# always build against system sqlite3 (https://github.com/php/php-src/commit/6083a387a81dbbd66d6316a3a12a63f06d5f7109)
	--with-pdo-sqlite=/usr \
	--with-sqlite3=/usr \
	\
	--with-curl \
	--with-libedit \
	--with-openssl \
	--with-zlib \
	\
	# bundled pcre does not support JIT on s390x
	# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
	$(test "$gnuArch" = 's390x-linux-musl' && echo '--without-pcre-jit') \
	\
	${PHP_EXTRA_CONFIGURE_ARGS:-} \
	; \
	make -j "$(nproc)"; \
	make install; \
	find -type f -name '*.a' -delete; \
	find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; \
	make clean; \
	\
	# https://github.com/docker-library/php/issues/692 (copy default example "php.ini" files somewhere easily discoverable)
	cp -v php.ini-* "$PHP_INI_DIR/"; \
	\
	cd /; \
	docker-php-source delete; \
	\
	runDeps="$( \
	scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
	| tr ',' '\n' \
	| sort -u \
	| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	# @TODO?: yum remove -y $runDeps; \
	yum remove -y $PHPIZE_DEPS; \
	package-cleanup -q --leaves | xargs -l1 yum -y remove ; \
	yum autoremove -y && yum clean all; \
	# libedit was removed above but we still need it:
	yum install -y libedit; \
	\
	# update pecl channel definitions https://github.com/docker-library/php/issues/443
	pecl update-channels; \
	rm -rf /tmp/pear ~/.pearrc; \
	# smoke test
	php --version

# sodium was built as a shared module (so that it can be replaced later if so desired), so let's enable it too (https://github.com/docker-library/php/issues/598)
#RUN docker-php-ext-enable sodium

ENTRYPOINT ["docker-php-entrypoint"]
WORKDIR /var/www/html

RUN set -eux; \
	cd /usr/local/etc; \
	if [ -d php-fpm.d ]; then \
	# for some reason, upstream's php-fpm.conf.default has "include=NONE/etc/php-fpm.d/*.conf"
	sed 's!=NONE/!=!g' php-fpm.conf.default | tee php-fpm.conf > /dev/null; \
	cp php-fpm.d/www.conf.default php-fpm.d/www.conf; \
	else \
	# PHP 5.x doesn't use "include=" by default, so we'll create our own simple config that mimics PHP 7+ for consistency
	mkdir php-fpm.d; \
	cp php-fpm.conf.default php-fpm.d/www.conf; \
	{ \
	echo '[global]'; \
	echo 'include=etc/php-fpm.d/*.conf'; \
	} | tee php-fpm.conf; \
	fi; \
	{ \
	echo '[global]'; \
	echo 'error_log = /proc/self/fd/2'; \
	echo; echo '; https://github.com/docker-library/php/pull/725#issuecomment-443540114'; echo 'log_limit = 8192'; \
	echo; \
	echo '[www]'; \
	echo '; if we send this to /proc/self/fd/1, it never appears'; \
	echo 'access.log = /proc/self/fd/2'; \
	echo; \
	echo 'clear_env = no'; \
	echo; \
	echo '; Ensure worker stdout and stderr are sent to the main error log.'; \
	echo 'catch_workers_output = yes'; \
	echo 'decorate_workers_output = no'; \
	} | tee php-fpm.d/docker.conf; \
	{ \
	echo '[global]'; \
	echo 'daemonize = no'; \
	echo; \
	echo '[www]'; \
	echo 'listen = 9000'; \
	} | tee php-fpm.d/zz-docker.conf

# Override stop signal to stop process gracefully
# https://github.com/php/php-src/blob/17baa87faddc2550def3ae7314236826bc1b1398/sapi/fpm/php-fpm.8.in#L163
STOPSIGNAL SIGQUIT

EXPOSE 9000
CMD ["php-fpm"]
