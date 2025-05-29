FROM manjarolinux/base:latest
RUN pacman -Sy --noconfirm
RUN pacman -Sy nano libice  libsm  libx11  libxau  libxcb  libxdmcp \
libxext  libxfixes  libxi  libxmu  libxrender  libxt xcb-proto \
xorgproto glew glibc-locales --noconfirm
RUN sed -i 's/^#\(en_.*UTF-8\)/\1/' /etc/locale.gen
RUN sed -i 's/^#\(ja_JP.*UTF-8\)/\1/' /etc/locale.gen
RUN sed -i 's/^#\(zh_.*UTF-8\)/\1/' /etc/locale.gen
RUN locale-gen
COPY ./common /etc/profile.d/
SHELL ["/bin/bash", "-c"]
ARG DESIRED_LOCALE
ARG DESIRED_SUBLOCALE
RUN source /etc/profile; dockerfile_set_locale ${DESIRED_LOCALE} ${DESIRED_SUBLOCALE}
