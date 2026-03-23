#!/bin/bash
# Script to build the conventional (full) Forth interpreter binary
# This build includes the complete Ada runtime and standard features.

set -e

PROJECT_FILE="forth_interpreter.gpr"
TARGET="obj/ada-forth"

echo "=== Building conventional Forth interpreter ==="
gprbuild -p -P $PROJECT_FILE

echo "=== Build complete ==="
RESULT_SIZE=$(ls -lh $TARGET | awk '{print $5}')
echo "Binary size: $RESULT_SIZE"
file $TARGET

echo "=== Sanity check ==="
echo "1 2 + ." | ./$TARGET | grep -q "3" && echo "Test passed: 1 2 + . => 3" || echo "Test failed!"
