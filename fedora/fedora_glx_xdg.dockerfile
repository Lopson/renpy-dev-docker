FROM fedora:latest
RUN dnf install glx-utils xdg-utils libXrender libICE libSM libXi libXmu \
libXt langpacks-ja langpacks-zh_CN  glibc-locale-source glibc-langpack-en \
nano -y
COPY ./common /etc/profile.d/
