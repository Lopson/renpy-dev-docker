FROM ubuntu:latest
RUN apt-get update
RUN apt-get install nano x11-apps libglew-dev locales language-pack-ja \
language-pack-zh-hans language-pack-zh-hant language-pack-en -y
COPY ./common /etc/profile.d/
SHELL ["/bin/bash", "-c"]
ARG DESIRED_LOCALE
ARG DESIRED_SUBLOCALE
RUN source /etc/profile; dockerfile_set_locale ${DESIRED_LOCALE} ${DESIRED_SUBLOCALE}
