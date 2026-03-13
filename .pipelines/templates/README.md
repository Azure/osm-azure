# Pipeline Templates - Dependency Management

This directory contains Azure DevOps pipeline templates that handle tool installation and setup for the OSM Azure Arc extension project.

## Tool Compatibility Changes

The pipeline templates have been updated to address dependency issues with tools that may not be available on all build agents:

### Changes Made

1. **Helm Installation** (`install-helm3.yaml`):
   - Switched from `.zip` download to `.tar.gz` to avoid dependency on `unzip`
   - Added `curl` installation fallback using `tdnf`
   - Uses native `tar` command instead of `unzip`

2. **ORAS Installation** (`install-oras.yaml`):
   - Added tool availability checks for `curl` and `tar`
   - Installs missing tools using `tdnf` package manager
   - Ensures all required tools are present before download

3. **BATS Installation** (`install-bats.yaml`):
   - Same approach as ORAS installation
   - Uses `tdnf` to install missing dependencies

4. **Trivy Installation** (`Makefile`):
   - Replaced `wget` with `curl` for better compatibility
   - Uses `tdnf` to install `curl` if not available

### Package Manager

The templates use `tdnf` (Tiny DNF), which is the package manager for Azure Linux 3:
- Azure DevOps runners use Azure Linux 3
- `tdnf` is a lightweight version of DNF package manager
- Provides access to standard Linux tools and utilities

### Target Platform

These templates are optimized for:
- Microsoft-hosted Azure DevOps agents running Azure Linux 3
- Self-hosted agents using Azure Linux 3
- Any system with `tdnf` package manager available

## Best Practices

When adding new tool dependencies:
1. Check tool availability with `command -v toolname`
2. Provide cross-platform installation fallbacks
3. Use `curl` instead of `wget` when possible
4. Prefer tar archives over zip archives to avoid `unzip` dependency
5. Add informative error messages for unsupported scenarios
