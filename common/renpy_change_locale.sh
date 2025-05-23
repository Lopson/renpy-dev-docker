#!/bin/bash

function check_locale_available () {
    local locales;
    locales=$(locale -a);

    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You can only pass one argument" >&2;
        return 3;
    fi

    if [ -z "$1" ]; then
        echo "[ERROR] No locale to search was given" >&2;
        return 2;
    fi

    for locale in $locales; do
        if [ "$1" = "$locale" ]; then
            return 0;
        fi
    done;

    return 1;
}

function check_sublocale_available () {
    local locales;
    mapfile -t locales < <(locale -a);
    local valid_locales;
    valid_locales=();

    if [ "$#" -ne 2 ]; then
        echo "[ERROR] You must pass two arguments" >&2;
        return 3;
    fi

    if [ -z "$1" ]; then
        echo "[ERROR] No locale to search was given" >&2;
        return 2;
    fi

    if [ -z "$2" ]; then
        echo "[ERROR] No sublocale to search was given" >&2;
        return 2;
    fi

    for locale in "${locales[@]}"; do
        if [ "$(cut -d "_" -f 1 <<<"$locale")" = "$1" ]; then
            locale=$(cut -d "_" -f 2 <<<"$locale");
            valid_locales+=( "$(cut -d "." -f 1 <<<"$locale")" );
        fi
    done

    if [ ${#valid_locales[@]} -lt 1 ]; then
        return 1;
    fi

    # Remove sublocales with @ in it.
    for i in "${!valid_locales[@]}"; do
        valid_locales[i]=$(cut -d "@" -f 1 <<<"${valid_locales[i]}");
    done

    # Remove duplicates.
    mapfile -t valid_locales < <(for i in "${valid_locales[@]}"; do echo "$i"; done | sort -u);

    for locale in "${valid_locales[@]}"; do
        if [ "$2" = "$locale" ]; then
            return 0;
        fi
    done

    return 1
}

function set_locale () {
    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You can only pass one argument" >&2;
        return 2;
    fi

    if check_locale_available "$1"; then
        echo "[ERROR] $1 locale not installed" >&2;
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
    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You must pass a sublocale" >&2;
        return 4;
    fi

    if ! check_sublocale_available "zh" "$1"; then
        echo "[ERROR] Chinese sublocale specified doesn't exist: $1" >&2;
        return 3;
    fi

    set_locale "zh_$1.UTF-8";
    return $?;
}

function set_en_locale () {
    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You must pass a sublocale" >&2;
        return 4;
    fi

    if ! check_sublocale_available "en" "$1"; then
        echo "[ERROR] English sublocale specified doesn't exist: $1" >&2;
        return 3;
    fi

    set_locale "en_$1.UTF-8";
    return $?;
}
