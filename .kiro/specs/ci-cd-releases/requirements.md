# Requirements Document

## Introduction

This document defines the requirements for adding a GitHub Actions CI/CD pipeline and binary release system to the Ada/SPARK Forth interpreter project. The pipeline provides automated building, testing, SPARK formal verification, and pre-built binary distribution via GitHub Releases. Version information is embedded at build time through a generated Ada spec file, and a `--version` flag is supported by the main binary.

## Glossary

- **CI_Workflow**: The GitHub Actions workflow (`.github/workflows/ci.yml`) that runs on every push and pull request to build, test, and formally verify the project.
- **Release_Workflow**: The GitHub Actions workflow (`.github/workflows/release.yml`) that triggers on `v*` tag pushes to build and publish binary releases.
- **Version_Package**: The Ada package `Version` (`src/version.ads`) that provides compile-time version string constants (`Name` and `Value`).
- **Binary**: The compiled executable `ada-forth` (or `ada-forth.exe` on Windows) produced by `gprbuild` from the GPR project file.
- **Platform_Matrix**: The set of target platform configurations (OS, architecture, runner, archive format) defined in the release workflow.
- **SARIF**: Static Analysis Results Interchange Format, used to upload GNATprove proof results to the GitHub Security tab.
- **Proof_Cache**: The `actions/cache` storage of GNATprove proof session files (`obj/gnatprove/`) to accelerate subsequent verification runs.
- **Release_Archive**: A `.tar.gz` or `.zip` file containing the built binary and README.md, uploaded as a GitHub Release asset.
- **Sandbox_Branch**: Any git branch whose name contains the substring `sandbox`, excluded from CI triggers.
- **Tag_Version**: A git tag matching the pattern `v<major>.<minor>.<patch>` (e.g., `v1.0.0`) that triggers the Release_Workflow.

## Requirements

### Requirement 1: Version Package

**User Story:** As a developer, I want the binary to contain an embedded version string, so that users can identify which release they are running.

#### Acceptance Criteria

1. THE Version_Package SHALL provide a constant `Name` with the value `"ada-forth"` and a constant `Value` defaulting to `"dev"`
2. WHEN the Release_Workflow generates `src/version.ads` from a Tag_Version `vX.Y.Z`, THE Version_Package SHALL contain a `Value` constant equal to `"X.Y.Z"` (the tag with the leading `v` stripped)
3. THE Version_Package SHALL use `SPARK_Mode => Off` so that it does not affect any SPARK-verified code paths
4. WHEN a developer builds the project locally without CI, THE Version_Package SHALL compile successfully with its default `"dev"` value

### Requirement 2: Command-Line Version Flag

**User Story:** As a user, I want to run `ada-forth --version` to see the program name and version, so that I can verify which build I have.

#### Acceptance Criteria

1. WHEN the user passes `--version` as the first command-line argument, THE Binary SHALL print `"ada-forth <version>"` to standard output and exit without entering the REPL
2. WHEN the user passes no arguments, THE Binary SHALL enter the REPL as before with no behavioral change
3. WHEN the user passes arguments other than `--version`, THE Binary SHALL enter the REPL as before with no behavioral change

### Requirement 3: Binary Naming

**User Story:** As a developer, I want the compiled executable to be named `ada-forth`, so that release archives and version output use a consistent name.

#### Acceptance Criteria

1. THE GPR project file SHALL map `main.adb` to the executable name `ada-forth` via an `Executable` attribute
2. WHEN `gprbuild` completes, THE Binary SHALL be located at `obj/ada-forth` (or `obj/ada-forth.exe` on Windows)

### Requirement 4: CI Workflow

**User Story:** As a developer, I want every push and pull request to trigger automated build, test, and formal verification, so that regressions are caught before merging.

#### Acceptance Criteria

1. WHEN a push or pull request occurs on any branch not matching `*sandbox*`, THE CI_Workflow SHALL trigger
2. WHEN a push or pull request occurs on a Sandbox_Branch, THE CI_Workflow SHALL not trigger
3. WHEN the CI_Workflow runs, THE CI_Workflow SHALL install the GNAT toolchain via `alire-project/setup-alire@v2`
4. WHEN the CI_Workflow runs, THE CI_Workflow SHALL build the main project using `gprbuild -P forth_interpreter.gpr -j0`
5. WHEN the CI_Workflow runs, THE CI_Workflow SHALL build and execute the integration test suite using `gprbuild -P test_integration.gpr -j0` followed by `./obj/test_integration`
6. WHEN the CI_Workflow runs, THE CI_Workflow SHALL execute GNATprove formal verification using `gnatprove -P forth_interpreter.gpr --level=2 --prover=alt-ergo -j0`
7. WHEN GNATprove completes, THE CI_Workflow SHALL upload the proof results in SARIF format to the GitHub Security tab via `github/codeql-action/upload-sarif@v3`
8. WHEN the CI_Workflow runs, THE CI_Workflow SHALL cache GNATprove proof sessions in `obj/gnatprove/` using `actions/cache@v4` to accelerate subsequent runs

### Requirement 5: Release Workflow Trigger and Version Extraction

**User Story:** As a maintainer, I want pushing a `v*` tag to automatically build and publish a release, so that the release process is automated and reproducible.

#### Acceptance Criteria

1. WHEN a git tag matching `v*` is pushed, THE Release_Workflow SHALL trigger
2. WHEN the Release_Workflow triggers, THE Release_Workflow SHALL extract the version string by stripping the leading `v` from the tag name (e.g., `v1.0.0` becomes `1.0.0`)
3. WHEN the version is extracted, THE Release_Workflow SHALL generate `src/version.ads` containing the extracted version string as the `Value` constant
4. WHEN the version generation step runs multiple times with the same tag, THE Release_Workflow SHALL produce identical `src/version.ads` content each time

### Requirement 6: Release Build and Packaging

**User Story:** As a maintainer, I want release builds to produce correctly packaged archives for each platform, so that users can download pre-built binaries.

#### Acceptance Criteria

1. WHEN the Release_Workflow builds for a platform, THE Release_Workflow SHALL install the GNAT toolchain via `alire-project/setup-alire@v2` and build using `gprbuild -P forth_interpreter.gpr -j0`
2. WHEN packaging for Linux or macOS, THE Release_Workflow SHALL create a `.tar.gz` archive named `ada-forth-<version>-<platform>.tar.gz`
3. WHEN packaging for Windows, THE Release_Workflow SHALL create a `.zip` archive named `ada-forth-<version>-<platform>.zip`
4. THE Release_Archive SHALL contain the Binary named `ada-forth` (or `ada-forth.exe` on Windows) and `README.md` inside a directory named `ada-forth-<version>`
5. WHEN all platform builds succeed, THE Release_Workflow SHALL create a GitHub Release using `softprops/action-gh-release@v2` and upload all Release_Archives as assets

### Requirement 7: Platform Matrix Configuration

**User Story:** As a maintainer, I want the platform matrix to be easily extensible, so that new platforms can be enabled by uncommenting a single entry.

#### Acceptance Criteria

1. THE Platform_Matrix SHALL define entries for linux-amd64, linux-aarch64, macos-amd64, macos-aarch64, and windows-amd64
2. THE Platform_Matrix SHALL have only the linux-amd64 entry active (uncommented) initially
3. WHEN a commented-out Platform_Matrix entry is uncommented, THE Release_Workflow SHALL build and package for that platform without any other workflow changes

### Requirement 8: Release Documentation

**User Story:** As a maintainer, I want a step-by-step release guide, so that any team member can cut a release following a documented process.

#### Acceptance Criteria

1. THE release documentation at `doc/release_process.md` SHALL describe the complete release workflow: commit changes, create a `v`-prefixed tag, push the tag, verify in GitHub Actions, and download from GitHub Releases
2. THE release documentation SHALL describe how to verify the release binary by running `ada-forth --version`
3. THE release documentation SHALL describe the local build process for development without CI

### Requirement 9: Error Handling

**User Story:** As a maintainer, I want CI and release failures to produce clear diagnostics, so that issues can be identified and resolved quickly.

#### Acceptance Criteria

1. IF GNATprove finds unproved verification conditions, THEN THE CI_Workflow SHALL fail the job and the SARIF upload SHALL still occur so unproved VCs appear in the GitHub Security tab
2. IF a platform build fails in the Release_Workflow, THEN THE Release_Workflow SHALL fail that platform job independently while other platform jobs continue
3. IF any required release job fails, THEN THE Release_Workflow SHALL not create the GitHub Release
