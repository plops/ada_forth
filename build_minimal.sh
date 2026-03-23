#!/bin/bash
# Script to build an ULTRA minimal Linux binary of the Forth interpreter
# Targeted size: < 30KB (Currently ~23KB)
# Strategy: Bypasses GNAT startup/runtime by using a direct C entry point and minimal I/O.

set -e

BUILD_DIR="minimal_build"
TARGET="forth-mini"

echo "=== Preparing ultra-minimal build environment ==="
mkdir -p $BUILD_DIR/obj

# 1. Copy essential sources
cp src/bounded_stacks.ads $BUILD_DIR/
cp src/bounded_stacks.adb $BUILD_DIR/
cp src/forth_vm.ads $BUILD_DIR/
cp src/forth_vm.adb $BUILD_DIR/
cp src/forth_interpreter.ads $BUILD_DIR/
cp src/forth_interpreter.adb $BUILD_DIR/
cp src/mini_io.ads $BUILD_DIR/
cp src/mini_io.adb $BUILD_DIR/
cp src/mini_main.adb $BUILD_DIR/mini_main.adb
cp gnat.adc $BUILD_DIR/

# 2. Patch forth_vm.adb to use Mini_IO instead of Ada.Text_IO
sed -i 's/with Ada.Text_IO;/with Mini_IO;/' $BUILD_DIR/forth_vm.adb
sed -i 's/Ada.Text_IO.Put (Integer\x27Image (V) \& " ");/Mini_IO.Put_Int (V); Mini_IO.Put (" ");/' $BUILD_DIR/forth_vm.adb

# 3. Create the minimal C entry point to bypass GNAT runtime initialization
cat <<EOF > $BUILD_DIR/entry.c
extern void _ada_mini_main();
int main() {
    _ada_mini_main();
    return 0;
}
EOF

echo "=== Compiling objects with aggressive size optimization ==="
cd $BUILD_DIR

# Compile Ada units to objects
# -Os: Optimize for size
# -gnatp: Suppress all runtime checks
# -ffunction-sections & -fdata-sections: Allow linker to remove unused code
# -gnat2012: Language standard
# -gnatn: Enable inlining
# -gnatec: Use our restriction file
COMMON_FLAGS="-Os -gnatp -ffunction-sections -fdata-sections -gnat2012 -gnatn -gnatec=gnat.adc"

gcc -c $COMMON_FLAGS bounded_stacks.adb
gcc -c $COMMON_FLAGS forth_vm.adb
gcc -c $COMMON_FLAGS forth_interpreter.adb
gcc -c $COMMON_FLAGS mini_io.adb
gcc -c $COMMON_FLAGS mini_main.adb

# Compile the C entry point
gcc -c -Os -ffunction-sections -fdata-sections entry.c

echo "=== Linking ultra-minimal binary (bypassing gnatlink) ==="
# Link everything directly using gcc to avoid gnatlink overhead
# -Wl,--gc-sections: Garbage collect unused functions
# -Wl,--strip-all: Strip all symbols
# -static-libgcc: Avoid dynamic dependency on libgcc_s
gcc -o ../$TARGET *.o -lc -Os -ffunction-sections -fdata-sections \
    -Wl,--gc-sections -Wl,--strip-all -static-libgcc

cd ..

echo "=== Build complete ==="
RESULT_SIZE=$(ls -lh $TARGET | awk '{print $5}')
RESULT_BYTES=$(du -b $TARGET | awk '{print $1}')
echo "Final binary size: $RESULT_SIZE ($RESULT_BYTES bytes)"
file $TARGET

echo "=== Sanity check ==="
echo "1 2 + ." | ./$TARGET | grep -q "3" && echo "Test passed: 1 2 + . => 3" || echo "Test failed!"

# 4. Clean up temporary build files
rm -rf $BUILD_DIR
