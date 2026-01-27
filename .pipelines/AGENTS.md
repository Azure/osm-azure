# OSM Arc Extension Pipeline Definitions

This directory contains the ADO pipeline definitions for running CI/CD for the OSM Arc Extension. The runners that these pipelines run on only have the following tools installed:

- Ant
- Azure CLI
- CMake
- Docker
- Dotnet 8.0
- Git
- Google Chrome
- Helm
- Homebrew
- JQ
- KubeCTL
- Make
- OpenSSL
- Powershell
- Ruby
- SQLite

If you need a different tool, install it. The runners run on Azure Linux 3 so use the appropriate package manager.
