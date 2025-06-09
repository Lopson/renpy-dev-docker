FROM elestio/languagetool:latest
USER root
RUN apk add --no-cache fasttext
USER languagetool
