# Release Process

## Creating a Release

1. Ensure all changes are committed and pushed to `main`.

2. Create a version tag with the `v` prefix:

   ```bash
   git tag v1.0.0
   ```

3. Push the tag to GitHub:

   ```bash
   git push origin v1.0.0
   ```

   Or push all tags at once:

   ```bash
   git push origin main --tags
   ```

4. The **Release** workflow (`.github/workflows/release.yml`) triggers automatically when the tag is pushed. It will:
   - Extract the version from the tag (e.g., `v1.0.0` → `1.0.0`)
   - Generate `src/version.ads` with the extracted version
   - Build the binary for each active platform
   - Package the binary and `README.md` into an archive
   - Create a GitHub Release and upload the archives

5. Monitor progress in the **Actions** tab of the GitHub repository.

6. Once the workflow completes, download the release archive from the **Releases** page.

## Verifying a Release Binary

After downloading a release archive (e.g., `ada-forth-1.0.0-linux-amd64.tar.gz`):

```bash
tar xzf ada-forth-1.0.0-linux-amd64.tar.gz
./ada-forth-1.0.0/ada-forth --version
```

Expected output:

```
ada-forth 1.0.0
```

The version should match the tag you pushed (without the `v` prefix).

## Local Development Build

For local development, the default version is `"dev"` (defined in `src/version.ads`).

Build the project:

```bash
gprbuild -P forth_interpreter.gpr -j0
```

The binary is produced at `obj/ada-forth`. Verify with:

```bash
./obj/ada-forth --version
```

Expected output:

```
ada-forth dev
```

Run the integration tests:

```bash
gprbuild -P test_integration.gpr -j0
./obj/test_integration
```
