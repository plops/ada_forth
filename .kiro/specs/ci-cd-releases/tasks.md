# Implementation Plan: CI/CD Releases

## Overview

Add CI/CD pipelines and binary release automation to the Ada/SPARK Forth interpreter. Implementation proceeds from version embedding in Ada code, through GPR project changes, to GitHub Actions workflows and release documentation. Each step builds on the previous, ensuring no orphaned code.

## Tasks

- [x] 1. Create Version package and add --version flag
  - [x] 1.1 Create `src/version.ads` with default "dev" version
    - Create the Version package spec with `Name => "ada-forth"` and `Value => "dev"`
    - Use `SPARK_Mode => Off` to exclude from formal verification
    - _Requirements: 1.1, 1.3, 1.4_

  - [x] 1.2 Modify `src/main.adb` to handle `--version` flag
    - Add `with Ada.Command_Line; with Version;` context clauses
    - Before the REPL loop, check if first argument is `--version`
    - If so, print `Version.Name & " " & Version.Value` and return
    - If no arguments or other arguments, enter REPL unchanged
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 1.3 Update `forth_interpreter.gpr` to set executable name
    - Add `for Executable ("main.adb") use "ada-forth";` in the Builder package
    - Binary will be produced at `obj/ada-forth`
    - _Requirements: 3.1, 3.2_

- [x] 2. Checkpoint - Verify version embedding and binary naming
  - Build with `gprbuild -P forth_interpreter.gpr -j0` and verify `./obj/ada-forth --version` prints `ada-forth dev`
  - Verify `./obj/ada-forth` enters REPL normally when run without arguments
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Create CI workflow
  - [x] 3.1 Create `.github/workflows/ci.yml`
    - Define push and pull_request triggers with `branches-ignore: ['**sandbox**']`
    - Add build job: `actions/checkout@v4`, `alire-project/setup-alire@v2`, `gprbuild -P forth_interpreter.gpr -j0`
    - Add test step: `gprbuild -P test_integration.gpr -j0` then `./obj/test_integration`
    - Add GNATprove step: `gnatprove -P forth_interpreter.gpr --level=2 --prover=alt-ergo -j0`
    - Add SARIF upload step: `github/codeql-action/upload-sarif@v3`
    - Add proof cache step: `actions/cache@v4` for `obj/gnatprove/` directory
    - Ensure SARIF upload runs even if GNATprove step fails (use `if: always()`)
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 9.1_

- [x] 4. Create Release workflow
  - [x] 4.1 Create `.github/workflows/release.yml` with version extraction and platform matrix
    - Trigger on `tags: ['v*']` push
    - Extract version: `VERSION="${GITHUB_REF_NAME#v}"`
    - Generate `src/version.ads` with extracted version string
    - Define platform matrix with linux-amd64 active, other platforms commented out
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 7.1, 7.2, 7.3_

  - [x] 4.2 Add build, packaging, and release steps to release workflow
    - Install toolchain via `alire-project/setup-alire@v2`
    - Build with `gprbuild -P forth_interpreter.gpr -j0`
    - Create staging directory `ada-forth-{version}/` with binary and README.md
    - Package as `.tar.gz` for Linux/macOS, `.zip` for Windows
    - Name archives `ada-forth-{version}-{platform}.{ext}`
    - Create GitHub Release via `softprops/action-gh-release@v2` and upload assets
    - Use `fail-fast: false` so platform jobs run independently
    - Use `needs:` to prevent release creation if any build fails
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 9.2, 9.3_

- [x] 5. Checkpoint - Review workflow files
  - Verify YAML syntax of both workflow files
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Create release documentation
  - [x] 6.1 Create `doc/release_process.md`
    - Document complete release workflow: commit, tag with `v` prefix, push tag, verify in GitHub Actions, download from GitHub Releases
    - Document how to verify release binary with `ada-forth --version`
    - Document local development build process (gprbuild with default "dev" version)
    - _Requirements: 8.1, 8.2, 8.3_

- [x] 7. Final checkpoint - Ensure all files are consistent
  - Verify `src/version.ads` compiles, `--version` flag works, GPR produces `ada-forth` binary
  - Review workflow files reference correct paths and action versions
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- The design uses Ada, so all code is in Ada 2012
- No property-based tests are applicable — CI/CD configuration files are not amenable to PBT, and SPARK formal verification (424 VCs) covers the Ada code
- Only linux-amd64 is active in the platform matrix; other platforms are commented out and ready to enable
- All gprbuild and gnatprove commands use `-j0` for parallel execution
- Checkpoints ensure incremental validation throughout implementation
