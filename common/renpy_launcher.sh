#!/bin/bash

function set_renpy_projects_folder() {
    if ! test_renpy_installed; then
        echo "[ERROR] Renpy SDK not installed" >&2
        return 1
    fi

    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You can only pass one argument" >&2
        return 4
    fi

    if [ ! -d "$1" ]; then
        echo "[ERROR] Directory given doesn't exist $1" >&2
        return 2
    fi

    local current_dir
    current_dir=$(pwd)
    cd "$RENPY_SDK" || {
        echo "[ERROR] Ren'Py SDK not found" >&2
        return 3
    }
    ./renpy.sh launcher set_projects_directory "$1"
    cd "$current_dir" || {
        echo "[ERROR] Couldn't return to original folder"
        return 3
    }

    return 0
}

function set_renpy_project() {
    if ! test_renpy_installed; then
        echo "[ERROR] Renpy SDK not installed" >&2
        return 1
    fi

    if [ "$#" -ne 1 ]; then
        echo "[ERROR] You can only pass one argument" >&2
        return 3
    fi

    local current_dir
    current_dir=$(pwd)
    cd "$RENPY_SDK" || {
        echo "[ERROR] Ren'Py SDK not found" >&2
        return 2
    }

    local projects_dir
    projects_dir=$(./renpy.sh launcher get_projects_directory)
    if [ -z "$projects_dir" ] || [ ! -d "$projects_dir" ]; then
        echo "[ERROR] Projects directory is invalid $projects_dir"
        return 4
    fi

    local projects_available
    mapfile -t projects_available < <(ls "$projects_dir")
    local project_found
    project_found=1
    for project in "${projects_available[@]}"; do
        if [ "$project" == "$1" ]; then
            project_found=0
        fi
    done
    if [ $project_found -eq 1 ]; then
        echo "[ERROR] Project given $1 doesn't exist in $projects_dir"
        return 5
    fi

    ./renpy.sh launcher set_project "$1"
    cd "$current_dir" || {
        echo "[ERROR] Couldn't return to original folder"
        return 2
    }

    return 0
}
