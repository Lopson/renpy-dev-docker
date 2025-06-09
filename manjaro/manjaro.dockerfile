FROM manjarolinux/base:latest
RUN pacman -Sy --noconfirm
RUN pacman -Sy nano libice  libsm  libx11  libxau  libxcb  libxdmcp \
libxext  libxfixes  libxi  libxmu  libxrender  libxt xcb-proto \
xorgproto glibc-locales mesa-amber python curl bzip2 --noconfirm
ARG DESIRED_RENPY_SDK
RUN curl ${DESIRED_RENPY_SDK} -o renpy.tar.bz2 --no-verbose && \
tar -xjf renpy.tar.bz2 && rm renpy.tar.bz2 && mkdir -p /opt && \
mv renpy-* /opt/renpy
COPY ./common /etc/profile.d/
SHELL ["/bin/bash", "-c"]
RUN source /etc/profile; update_locale_gen
RUN locale-gen
ARG DESIRED_LOCALE
ARG DESIRED_SUBLOCALE
RUN source /etc/profile; dockerfile_set_locale ${DESIRED_LOCALE} ${DESIRED_SUBLOCALE}
