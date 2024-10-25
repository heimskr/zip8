#!/bin/bash
MOVE_TARGET=$(realpath $2)
cd $(dirname $1)
zig build && mv zig-out/lib/libzip8.a "$MOVE_TARGET"
