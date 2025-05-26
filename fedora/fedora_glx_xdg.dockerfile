FROM fedora:latest
RUN dnf install glx-utils xdg-utils libXrender libICE libSM libXi libXmu \
libXt langpacks-ja langpacks-zh_CN  glibc-locale-source glibc-langpack-en \
nano -y
COPY ./common /etc/profile.d/
SHELL ["/bin/bash", "-c"]
ARG DESIRED_LOCALE
ARG DESIRED_SUBLOCALE
RUN source /etc/profile; dockerfile_set_locale ${DESIRED_LOCALE} ${DESIRED_SUBLOCALE}
