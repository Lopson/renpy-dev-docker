#!/bin/bash

function test_ubuntu () {
    if [ ! -f "/etc/lsb-release" ]; then
        return 1;
    fi

    local distribution_id;
    distribution_id=$(grep "DISTRIB_ID" "/etc/lsb-release" | cut -d "=" -f 2);

    if [ ! "$distribution_id" = "Ubuntu" ]; then
        return 1;
    fi

    return 0;
}

function check_language_available () {
    local locales;
    mapfile -t locales < <(locale -a | cut -d "." -f 1);

    # Remove locales with @ in it.
    for i in "${!locales[@]}"; do
        locales[i]=$(cut -d "@" -f 1 <<<"${locales[i]}");
    done

    # Remove duplicates.
    mapfile -t locales < <(for i in "${locales[@]}"; do echo "$i"; done | sort -u);    

    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You can only pass one argument" >&2;
        return 3;
    fi

    if [ -z "$1" ]; then
        echo "[ERROR] No locale to search was given" >&2;
        return 2;
    fi

    for locale in "${locales[@]}"; do
        if [ "$1" = "$locale" ]; then
            return 0;
        fi
    done;

    return 1;
}

function check_locale_available () {
    local locales;
    mapfile -t locales < <(locale -a);
    local valid_locales;
    valid_locales=();

    if [ "$#" -gt 2 ] || [ "$#" -lt 1 ]; then
        echo "[ERROR] Invalid number of arguments" >&2;
        return 2;
    fi

    if [ -z "$1" ]; then
        echo "[ERROR] No locale to search was given" >&2;
        return 3;
    fi

    if [ -z "$2" ] && [ "$#" -eq 2 ]; then
        echo "[ERROR] No sublocale to search was given" >&2;
        return 4;
    fi

    local locale_found;
    locale_found=false;
    for locale in "${locales[@]}"; do
        if [ "$(cut -d "_" -f 1 <<<"$locale")" = "$1" ]; then
            locale_found=true;
            locale=$(cut -d "_" -f 2 <<<"$locale");
            valid_locales+=( "$(cut -d "." -f 1 <<<"$locale")" );
        fi
    done

    # Check if language given was found.
    if [ $locale_found = false ]; then
        echo "[ERROR] Locale given $1 not found" >&2;
        return 5;
    fi

    # If all we were looking for was the language, then return.
    if [ $locale_found = true ] && [ "$#" -eq 1 ]; then
        return 0;
    fi

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

function update_locale_gen () {
    if [ ! -f "/etc/locale.gen" ]; then
        echo "[ERROR] File /etc/locale.gen not found" >&2;
        return 1;
    fi
    
    sed -i 's/^#\(en_.*UTF-8\)/\1/' /etc/locale.gen;
    sed -i 's/^#\(ja_JP.*UTF-8\)/\1/' /etc/locale.gen;
    sed -i 's/^#\(zh_.*UTF-8\)/\1/' /etc/locale.gen;

    return 0;
}

function set_locale () {
    local locale;
    locale=$(cut -d "." -f 1 <<<"$1");
    
    local encoding;
    encoding=$(cut -d "." -f 2 <<<"$1");
    
    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You can only pass one argument" >&2;
        return 2;
    fi

    if [ "$locale" != "$encoding" ]; then
        local charmaps;
        mapfile -t charmaps < <(locale -m);

        local charmap_found;
        charmap_found=false;
        for charmap in "${charmaps[@]}"; do
            if [ "$charmap" == "$encoding" ]; then
                charmap_found=true;
                break
            fi
        done

        if [ "$charmap_found" = false ]; then
            echo "[ERROR] Charmap given $encoding not found" >&2;
            return 3;
        fi
    fi

    if ! check_language_available "$locale"; then
        echo "[ERROR] $locale locale not installed" >&2;
        return 1;
    fi

    export LC_ALL="$1";
    export LANG="$1";
    if test_ubuntu && [ "$locale" != "C" ] && [ "$locale" != "POSIX" ]; then
        # Let's handle Chinese-specific edge cases.
        # https://www.gnu.org/software/gettext/manual/gettext.html#Specifying-a-Priority-List-of-Languages
        case $locale in
            "zh_SG")
                LANGUAGE="zh_SG:zh_CN";
                ;;
            "zh_HK")
                LANGUAGE="zh_HK:zh_TW";
                ;;
            "zh_MO")
                LANGUAGE="zh_MO:zh_TW";
                ;;
            *)
                LANGUAGE="$locale";
                ;;
        esac
        export LANGUAGE;

    fi

    if [ -f "/etc/locale.conf" ]; then
        truncate -s 0 /etc/locale.conf;
    else
        touch "/etc/locale.conf";
    fi

    {
        echo "LANG=$LANG"; 
        echo "LC_ALL=$LC_ALL";
        if test_ubuntu; then
            echo "LANGUAGE=$LANGUAGE";
        fi
    } >> /etc/locale.conf;

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

    if ! check_locale_available "zh" "$1"; then
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

    if ! check_locale_available "en" "$1"; then
        echo "[ERROR] English sublocale specified doesn't exist: $1" >&2;
        return 3;
    fi

    set_locale "en_$1.UTF-8";
    return $?;
}

function dockerfile_set_locale () {
    if [ "$1" == "jp" ] && [ "$#" -ne 1 ]; then
        echo "[ERROR] Invalid number of arguments" >&2;
        return 10;
    fi
    
    if [ "$1" == "en" ] || [ "$1" == "zh" ] && [ "$#" -ne 2 ]; then
        echo "[ERROR] Invalid number of arguments" >&2;
        return 10;
    fi

    case "$1" in
        "en")
            set_en_locale "$2";
            ;;
        "jp")
            set_jp_locale;
            ;;
        "zh")
            set_zh_locale "$2";
            ;;
        "C")
            set_locale "C.UTF-8";
            ;;
        "POSIX")
            set_locale "POSIX";
            ;;
        *)
            echo "[ERROR] Invalid language given" >&2;
            return 11;
            ;;
    esac

    return $?;
}
