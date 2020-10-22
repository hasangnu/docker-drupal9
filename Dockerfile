FROM ubuntu:20.04
ENV DEBIAN_FRONTEND noninteractive
ARG DRUPALVER=9.0.7

RUN apt-get update; \
  dpkg-divert --local --rename --add /sbin/initctl; \
  ln -sf /bin/true /sbin/initctl; \
  echo "postfix postfix/mailname string drupal-mail" | debconf-set-selections; \
  echo "postfix postfix/main_mailer_type string 'Local only'" | debconf-set-selections; \
  apt-get -y install git curl wget supervisor openssh-server locales \
  mysql-client mysql-server apache2 pwgen vim-tiny mc iproute2 python-setuptools \
  unison netcat net-tools memcached nano libapache2-mod-php php php-cli php-common \
  php-gd php-json php-mbstring php-xdebug php-mysql php-opcache php-curl \
  php-readline php-xml php-memcached php-oauth php-bcmath \
  postfix mailutils; \
  echo site: root >> /etc/aliases; \
  echo admin: root >> /etc/aliases; \
  newaliases; \
  apt-get clean; \
  apt-get autoclean; \
  apt-get -y autoremove; \
  rm -rf /var/lib/apt/lists/*

RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd; \
  echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config; \
  locale-gen en_US.UTF-8; \
  mkdir -p /var/lock/apache2 /var/run/apache2 /var/run/sshd /var/log/supervisor

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile; \
  rm -rf /var/lib/mysql/*; /usr/sbin/mysqld --initialize-insecure; \
  sed -i 's/^bind-address/#bind-address/g' /etc/mysql/mysql.conf.d/mysqld.cnf; \
  sed -i "s/Basic Settings/Basic Settings\ndefault-authentication-plugin=mysql_native_password\n/" /etc/mysql/mysql.conf.d/mysqld.cnf

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

ADD https://updates.drupal.org/release-history/drupal/${DRUPALVER} /tmp/latest.xml

RUN cd /var/www/html; \
  git clone --depth 1 --single-branch -b ${DRUPALVER} https://git.drupalcode.org/project/drupal.git web \
  && cd web; composer require drush/drush:~10; composer install  \
  && php --version; composer --version; vendor/bin/drush --version; vendor/bin/drush status \
  && cd /var/www/html; chmod a+w web/sites/default; \
  mkdir web/sites/default/files; chown -R www-data:www-data /var/www/html/; \
  chmod -R ug+w /var/www/html/ ; \
  wget "http://www.adminer.org/latest.php" -O /var/www/html/web/adminer.php

COPY ./files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./files/start.sh /start.sh
COPY ./files/foreground.sh /etc/apache2/foreground.sh

RUN rm /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/*
ADD ./files/000-default.conf /etc/apache2/sites-available/000-default.conf
ADD ./files/xdebug.ini /etc/php/*/mods-available/xdebug.ini
RUN a2ensite 000-default ; a2enmod rewrite vhost_alias

RUN mkdir -p /var/run/mysqld; \
    chown mysql:mysql /var/run/mysqld; \
    chmod 755 /start.sh /etc/apache2/foreground.sh

WORKDIR /var/www/html
EXPOSE 22 80 3306 9000
CMD ["/bin/bash", "/start.sh"]
