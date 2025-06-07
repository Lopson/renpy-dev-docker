FROM fedora:latest
RUN dnf install glx-utils xdg-utils libXrender libICE libSM libXi libXmu \
libXt langpacks-ja langpacks-zh_CN  glibc-locale-source glibc-langpack-en \
nano python3 -y
ARG DESIRED_RENPY_SDK
RUN curl ${DESIRED_RENPY_SDK} -o renpy.tar.bz2 --no-verbose && tar -xjf renpy.tar.bz2 && rm renpy.tar.bz2 && mkdir -p /opt && mv renpy-* /opt/renpy
ENV PATH="$PATH:/opt/renpy"
COPY ./common /etc/profile.d/
SHELL ["/bin/bash", "-c"]
ARG DESIRED_LOCALE
ARG DESIRED_SUBLOCALE
RUN source /etc/profile; dockerfile_set_locale ${DESIRED_LOCALE} ${DESIRED_SUBLOCALE}
