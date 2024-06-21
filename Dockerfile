### ---------------------------base--------------------------------------
# Specify the base image
FROM debian:bookworm-slim

# Default ENV variables.
ENV DEBIAN_FRONTEND noninteractive TERM=dumb PAGER=cat
ARG PHP_VERSION
ENV PHP_DEFAULT_VERSION=$PHP_VERSION
ENV PHP_VERSIONS="php8.0 php8.1 php8.2 php8.3"
ENV PHP_INI=/etc/php/$PHP_DEFAULT_VERSION/fpm/php.ini
ENV NODE_VERSION=20
ENV YARN_VERSION=1.22.19
ENV COMPOSER_VERSION=2.5.1
# composer normally screams about running as root, we don't need that.
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_PROCESS_TIMEOUT 2000

# TARGETPLATFORM is Docker buildx's target platform (e.g. linux/arm64), while
# BUILDPLATFORM is the platform of the build host (e.g. linux/amd64)
ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN apt-get -qq update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y \
    apt-transport-https \
    build-essential \
    bzip2 \
    ca-certificates \
    coreutils \
    curl \
    dialog apt-utils \
    jq \
    git \
    gnupg \
    gzip \
    less \
    lsb-release \
    patch \
    procps \
    openssh-client \
    tree \
    tzdata \
    unzip \
    vim \
    wget \
    xz-utils \
    zip

# Node install.
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
      x86_64) NODE_ARCH="x64";; \
      aarch64) NODE_ARCH="arm64";; \
      *) echo "Unsupported architecture: $ARCH"; exit 1;; \
    esac; \
    curl -sSL "https://raw.githubusercontent.com/CircleCI-Public/cimg-node/main/ALIASES" -o nodeAliases.txt; \
    NODE_VERSION=$(grep "lts" ./nodeAliases.txt | cut -d "=" -f 2-); \
    NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"; \
    echo "Downloading Node.js from ${NODE_URL}"; \
    curl -L -o node.tar.xz "${NODE_URL}"; \
    tar -xJf node.tar.xz -C /usr/local --strip-components=1; \
    rm node.tar.xz; \
    ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
    echo "Node.js installed at $(which node)"; \
    echo "npm installed at $(which npm)"; \
    rm nodeAliases.txt

# Yarn install.
RUN curl -L -o yarn.tar.gz "https://yarnpkg.com/downloads/${YARN_VERSION}/yarn-v${YARN_VERSION}.tar.gz" && \
	tar -xzf yarn.tar.gz -C /opt/ && \
	rm yarn.tar.gz && \
	ln -s /opt/yarn-v${YARN_VERSION}/bin/yarn /usr/local/bin/yarn && \
	ln -s /opt/yarn-v${YARN_VERSION}/bin/yarnpkg /usr/local/bin/yarnpkg
# Install mariadb_repo_setup to get mariadb-client from them directly
RUN curl -LsSf https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-10.11"

RUN curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb && \
    dpkg -i /tmp/debsuryorg-archive-keyring.deb && rm -f /tmp/debsuryorg-archive-keyring.deb && \
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && apt-get update

RUN npm install --unsafe-perm=true --global gulp-cli

SHELL ["/bin/bash", "-c"]

# Normal user needs to be able to write to php sessions
RUN set -eu -o pipefail && LATEST=$(curl -L --fail --silent "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | jq -r .tag_name) && curl --fail -sL https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST}/install.sh -o /usr/local/bin/install_nvm.sh && chmod +x /usr/local/bin/install_nvm.sh

# Install remaining packages.
RUN apt-get -qq update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y \
    file \
    ghostscript \
    imagemagick \
    gunicorn \
    graphicsmagick \
    jq \
    mariadb-client \
    msmtp \
    postgresql-client \
    sqlite3

# Build PHP CI.
# The number of permutations of php packages available on each architecture because
# too much to handle, so has been codified here instead of in obscure logic
# As of php8.0 json is now part of core package and xmlrpc has been removed from PECL
ENV php80_amd64="apcu bcmath bz2 curl cli common fpm gd imagick intl ldap mbstring memcached mysql opcache pgsql readline redis soap sqlite3 uploadprogress xhprof xml xmlrpc zip"
ENV php80_arm64=$php80_amd64

ENV php81_amd64=$php80_amd64
ENV php81_arm64=$php81_amd64
ENV php82_amd64=$php81_amd64
ENV php82_arm64=$php82_amd64
ENV php83_amd64=$php82_amd64
ENV php83_arm64=$php83_amd64

RUN for v in $PHP_VERSIONS; do \
    targetarch=${TARGETPLATFORM#linux/}; \
    pkgvar=${v//.}_${targetarch}; \
    pkgs=$(echo ${!pkgvar} | awk -v v="$v" ' BEGIN {RS=" "; }  { printf "%s-%s ",v,$0 ; }' ); \
    [[ ${pkgs// } != "" ]] && (apt-get -qq install --no-install-recommends --no-install-suggests -y $pkgs || exit $?) \
done

RUN phpdismod xhprof
RUN apt-get -qq autoremove -y

RUN touch /var/log/php-fpm.log && \
    chmod ugo+rw /var/log/php-fpm.log && \
    chmod ugo+rwx /var/run && \
    chmod ugo+rx /usr/local/bin/* && \
    ln -sf /usr/sbin/php-fpm${PHP_DEFAULT_VERSION} /usr/sbin/php-fpm

COPY php-files /php-files
RUN apt-get -qq autoremove && apt-get -qq clean -y && rm -rf /var/lib/apt/lists/* /tmp/*

# Set default PHP version.
RUN ln -sf /usr/bin/php${PHP_DEFAULT_VERSION} /etc/alternatives/php && \
    update-alternatives --install /usr/bin/php php /usr/bin/php${PHP_DEFAULT_VERSION} 1 && \
    update-alternatives --set php /usr/bin/php${PHP_DEFAULT_VERSION}

# Avoid git errors with safe.directory as user root.
RUN git config --global --add safe.directory '*'

# Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --version=$COMPOSER_VERSION --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    composer --version
#RUN curl -L --fail -o /usr/local/bin/composer -sSL https://getcomposer.org/composer-stable.phar && chmod ugo+wx /usr/local/bin/composer

# Drush
RUN mkdir -p /usr/local/share/drush
RUN /usr/bin/env composer -n --working-dir=/usr/local/share/drush require drush/drush "^10"
RUN ln -fs /usr/local/share/drush/vendor/drush/drush/drush /usr/local/bin/drush
RUN chmod +x /usr/local/bin/drush

# YQ
RUN url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${TARGETPLATFORM#linux/}"; wget ${url} -O /usr/bin/yq && chmod +x /usr/bin/yq

# Install terminus
RUN curl -L https://github.com/pantheon-systems/terminus/releases/download/3.4.0/terminus.phar -o /usr/local/bin/terminus && \
    chmod +x /usr/local/bin/terminus
RUN terminus self:update

############################################
# Install build tools things
# Compatibility with Pantheon environments.
##############################################
# Copy the current directory contents into the container at /build-tools-ci
COPY build-tools-ci /build-tools-ci

# Create an unpriviliged test user
# Group 999 already exists on base image (docker).
RUN useradd -r -m -u 999 -g 999 tester && \
    adduser tester sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R tester /usr/local && \
    chown -R tester /build-tools-ci
USER tester

RUN composer selfupdate --2

# Avoid git errors with safe.directory as user root.
RUN git config --global --add safe.directory '*'
# Add a collection of useful Terminus plugins.
RUN terminus self:plugin:add terminus-build-tools-plugin
RUN terminus self:plugin:add terminus-clu-plugin
RUN terminus self:plugin:add terminus-secrets-plugin
RUN terminus self:plugin:add terminus-rsync-plugin
RUN terminus self:plugin:add terminus-quicksilver-plugin
RUN terminus self:plugin:add terminus-composer-plugin
RUN terminus self:plugin:add terminus-drupal-console-plugin
RUN terminus self:plugin:add terminus-mass-update
RUN terminus self:plugin:add terminus-site-clone-plugin

ENV TERMINUS_PLUGINS_DIR=/home/tester/.terminus/plugins-3.x
ENV TERMINUS_DEPENDENCIES_BASE_DIR=/home/tester/.terminus/terminus-dependencies

# Add phpcs for use in checking code style
RUN mkdir ~/phpcs && cd ~/phpcs && COMPOSER_BIN_DIR=/usr/local/bin composer require squizlabs/php_codesniffer:^2.7

# Composer-lock-updater
RUN mkdir -p /usr/local/share/clu
RUN /usr/bin/env COMPOSER_BIN_DIR=/usr/local/bin composer -n --working-dir=/usr/local/share/clu require danielbachhuber/composer-lock-updater:^0.8.2

# Add phpunit for unit testing
RUN mkdir ~/phpunit && cd ~/phpunit && COMPOSER_BIN_DIR=/usr/local/bin composer require phpunit/phpunit

# Add Behat for more functional testing
RUN mkdir ~/behat && \
    cd ~/behat && \
    COMPOSER_BIN_DIR=/usr/local/bin \
    composer require \
        "behat/behat:^3.5" \
        "behat/mink:*" \
        "behat/mink-extension:^2.2" \
        "behat/mink-goutte-driver:^1.2" \
        "drupal/drupal-extension:*"
