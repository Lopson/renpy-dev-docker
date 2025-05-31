#!/bin/bash

XDG_RUNTIME_DIR=/run/user/$(id -u);
export XDG_RUNTIME_DIR;

DISPLAY=host.docker.internal:0.0;
export DISPLAY;
