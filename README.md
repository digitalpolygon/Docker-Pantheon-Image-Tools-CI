# Docker Image Tools CI

Dockerfile image specially for [Drupal](https://drupal.org) and [Pantheon](https://pantheon.io) environments. It contains just basic and important packages to configure and build Drupal projects compatible with Pantheon on Bitbucket pipelines or local environments.

Images can be pulled from [digitalpolygon/docker-pantheon-image-tools-ci](https://github.com/digitalpolygon/docker-pantheon-image-tools-ci/pkgs/container/docker-pantheon-image-tools-ci).

## Image Contents

- [Debian official base image](https://hub.docker.com/_/debian/)
- PHP 8.x (8.0, 8.1, 8.2, 8.3)
- Node.js v20
- Yarn v1.22
- Composer v2
- [Pantheon build-tools-ci scripts](https://github.com/pantheon-systems/docker-build-tools-ci/tree/8.x/scripts)
- [Terminus](https://github.com/pantheon-systems/terminus)
- Terminus plugins
  - [Terminus Build Tools Plugin](https://github.com/pantheon-systems/terminus-build-tools-plugin)
  - [Terminus Secrets Plugin](https://github.com/pantheon-systems/terminus-secrets-plugin)
  - [Terminus Rsync Plugin](https://github.com/pantheon-systems/terminus-rsync-plugin)
  - [Terminus Quicksilver Plugin](https://github.com/pantheon-systems/terminus-quicksilver-plugin)
  - [Terminus Composer Plugin](https://github.com/pantheon-systems/terminus-composer-plugin)
  - [Terminus Drupal Console Plugin](https://github.com/pantheon-systems/terminus-drupal-console-plugin)
  - [Terminus Mass Update Plugin](https://github.com/pantheon-systems/terminus-mass-update)
  - [Terminus Aliases Plugin](https://github.com/pantheon-systems/terminus-aliases-plugin)
  - [Terminus CLU Plugin](https://github.com/pantheon-systems/terminus-clu-plugin)
- Test tools
  - phpunit
  - behat
  - php_codesniffer
- Test scripts

## Branches

- 8.x: Use a Docker official base image with Node JS, composer 2 and Terminus 3. Produces 8.x-php8.0, 8.x-php8.1 and 8.x-php8.2 image tags.

## 8.x Docker images

### Building the image

From project root:

```
# PHP_VERSION could be 8.0, 8.1, 8.2 or 8.3.
PHP_VERSION=8.1
docker build --build-arg PHP_VERSION=PHP_VERSION -t ghcr.io/digitalpolygon/docker-pantheon-image-tools-ci:8.x-php${PHP_VERSION} .
```

### Using the image

#### Image name and tags
https://github.com/digitalpolygon/docker-pantheon-image-tools-ci/pkgs/container/docker-pantheon-image-tools-ci/
