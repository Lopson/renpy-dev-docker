#!/bin/bash

function check_locale_available () {
    local locales;
    locales=$(locale -a);

    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You can only pass one argument";
        return 3;
    fi

    if [ -z "$1" ]; then
        echo "[ERROR] No locale to search was given";
        return 2;
    fi

    for locale in $locales; do
        if [ "$1" = "$locale" ]; then
            return 0;
        fi
    done;

    return 1;
}

function set_locale () {
    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You can only pass one argument";
        return 2;
    fi

    if check_locale_available "$1"; then
        echo "[ERROR] $1 locale not installed";
        return 1;
    fi

    export LC_ALL="$1";
    export LANG="$1";
    
    return 0;
}

function set_jp_locale () {
    set_locale "ja_JP.UTF-8";
    return $?;
}

function set_zh_locale () {
    set_locale "zh_CN.UTF-8";
    return $?;
}
