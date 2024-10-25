#!/bin/bash
MOVE_TARGET=$(realpath $2)
cd $(dirname $1)
zig build -Doptimize=ReleaseFast && mv zig-out/lib/libzip8.a "$MOVE_TARGET"
