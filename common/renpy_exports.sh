#!/bin/bash

XDG_RUNTIME_DIR=/run/user/$(id -u)
export XDG_RUNTIME_DIR

DISPLAY=host.docker.internal:0.0
export DISPLAY

RENPY_SDK="/opt/renpy"
export RENPY_SDK

TESTING_MOUNT="/mnt/testing"
export TESTING_MOUNT

function test_renpy_installed() {
    if [ ! -d "$RENPY_SDK" ]; then
        return 1
    fi

    return 0
}

function test_renpy_in_path() {
    if [[ ! ":$PATH:" == *":/opt/renpy:"* ]]; then
        return 1
    fi

    return 0
}

function add_renpy_to_path() {
    if ! test_renpy_installed; then
        return 1
    fi

    if ! test_renpy_in_path; then
        # shellcheck disable=SC2123
        PATH="${PATH:+${PATH}:}/opt/renpy" # Appending
        # PATH="/opt/renpy${PATH:+:${PATH}}" # Prepending
        export PATH
    fi

    return 0
}

add_renpy_to_path
