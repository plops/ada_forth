#!/bin/bash

# Script to collect all source code, documentation, specs, and scripts into one file
# Output will be saved to /dev/shm/ada_forth_context.txt

set -e

OUTPUT_FILE="/dev/shm/ada_forth_context.txt"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Clear or create the output file
> "$OUTPUT_FILE"

# Function to append file with header
append_file() {
    local file_path="$1"
    local description="$2"
    
    if [[ -f "$file_path" ]]; then
        echo "" >> "$OUTPUT_FILE"
        echo "=================================================================" >> "$OUTPUT_FILE"
        echo "FILE: $file_path" >> "$OUTPUT_FILE"
        echo "DESCRIPTION: $description" >> "$OUTPUT_FILE"
        echo "=================================================================" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        cat "$file_path" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
}

# Function to recursively collect files from a directory
collect_directory() {
    local dir_path="$1"
    local description="$2"
    local pattern="$3"
    
    if [[ -d "$dir_path" ]]; then
        while IFS= read -r -d '' file; do
            local relative_path="${file#$PROJECT_DIR/}"
            append_file "$file" "$description - $relative_path"
        done < <(find "$dir_path" -type f -name "$pattern" -print0 | sort -z)
    fi
}

echo "Collecting project context for AI analysis..."
echo "Output file: $OUTPUT_FILE"

# Start with README and main project files
append_file "$PROJECT_DIR/README.md" "Main project documentation"
append_file "$PROJECT_DIR/forth_interpreter.gpr" "GNAT project file"
append_file "$PROJECT_DIR/test_integration.gpr" "Integration test project file"
append_file "$PROJECT_DIR/gnat.adc" "GNAT configuration file"

# Collect source files in logical order
echo "Collecting source files..."

# Package specifications first (in alphabetical order)
collect_directory "$PROJECT_DIR/src" "Ada package specification" "*.ads"

# Then package bodies (in alphabetical order)
collect_directory "$PROJECT_DIR/src" "Ada package body" "*.adb"

# Collect documentation files
echo "Collecting documentation..."
collect_directory "$PROJECT_DIR/doc" "Documentation" "*.md"

# Collect specification files from .kiro
echo "Collecting specifications..."
collect_directory "$PROJECT_DIR/.kiro" "Project specification" "*.md"
collect_directory "$PROJECT_DIR/.kiro" "Project specification" "*.txt"

# Recursively collect all files in .kiro subdirectories
if [[ -d "$PROJECT_DIR/.kiro" ]]; then
    while IFS= read -r -d '' file; do
        relative_path="${file#$PROJECT_DIR/}"
        append_file "$file" "Project specification - $relative_path"
    done < <(find "$PROJECT_DIR/.kiro" -type f -print0 | sort -z)
fi

# Collect build scripts
echo "Collecting scripts..."
append_file "$PROJECT_DIR/build.sh" "Build script"
append_file "$PROJECT_DIR/build_minimal.sh" "Minimal build script"

# Collect SPARK proof and analysis files from obj/
echo "Collecting SPARK proof files..."
if [[ -d "$PROJECT_DIR/obj" ]]; then
    # Collect SPARK proof files (.cswi, .bexch)
    while IFS= read -r -d '' file; do
        relative_path="${file#$PROJECT_DIR/}"
        append_file "$file" "SPARK proof file - $relative_path"
    done < <(find "$PROJECT_DIR/obj" -type f \( -name "*.cswi" -o -name "*.bexch" \) -print0 | sort -z)
    
    # Collect build output files (.stderr, .stdout) if they contain content
    while IFS= read -r -d '' file; do
        if [[ -s "$file" ]]; then  # Only include non-empty files
            relative_path="${file#$PROJECT_DIR/}"
            append_file "$file" "Build output - $relative_path"
        fi
    done < <(find "$PROJECT_DIR/obj" -type f \( -name "*.stderr" -o -name "*.stdout" \) -print0 | sort -z)
fi

# Add final summary
echo "" >> "$OUTPUT_FILE"
echo "=================================================================" >> "$OUTPUT_FILE"
echo "CONTEXT COLLECTION SUMMARY" >> "$OUTPUT_FILE"
echo "=================================================================" >> "$OUTPUT_FILE"
echo "Project: Ada Forth Interpreter" >> "$OUTPUT_FILE"
echo "Collection date: $(date)" >> "$OUTPUT_FILE"
echo "Total lines: $(wc -l < "$OUTPUT_FILE")" >> "$OUTPUT_FILE"
echo "Output file size: $(du -h "$OUTPUT_FILE" | cut -f1)" >> "$OUTPUT_FILE"

echo "Context collection completed!"
echo "File saved to: $OUTPUT_FILE"
echo "File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo "Total lines: $(wc -l < "$OUTPUT_FILE")"
