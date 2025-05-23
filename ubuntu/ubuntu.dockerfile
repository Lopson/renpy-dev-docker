FROM ubuntu:latest
RUN apt-get update
RUN apt-get install nano x11-apps libglew-dev -y
COPY ./common /etc/profile.d/
