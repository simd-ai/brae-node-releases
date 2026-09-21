# brae-node releases

Prebuilt binaries and the installer for **brae-node**, the provider agent for the [Brae](https://brae.sh)
GPU network. This repository is public so that anyone lending a GPU can fetch and verify the agent. The
agent's source lives in a private repository.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/simd-ai/brae-node-releases/main/install.sh | sh
```

It downloads the binary for your architecture, **verifies it against the published SHA-256**, and installs it
to `/usr/local/bin/brae-node`. It registers nothing and starts no service.

Then:

```bash
brae-node init                     # look at this machine, create its identity — no network calls
brae-node join --token <TOKEN>     # join, with the token from https://app.brae.sh
```

## What is published

| file | |
|---|---|
| `brae-node-x86_64-unknown-linux-gnu` | Linux, Intel/AMD |
| `brae-node-aarch64-unknown-linux-gnu` | Linux, ARM (GB10, Grace, Jetson-class hosts) |
| `SHA256SUMS` | checksums for both, used by the installer |

Built against glibc 2.31, so they run on Ubuntu 20.04, Debian 11, RHEL 9 and newer. NVML is loaded at run
time from the NVIDIA driver, so no CUDA toolkit is needed to run the agent.

## Verifying by hand

```bash
curl -fsSLO https://github.com/simd-ai/brae-node-releases/releases/latest/download/SHA256SUMS
curl -fsSLO https://github.com/simd-ai/brae-node-releases/releases/latest/download/brae-node-x86_64-unknown-linux-gnu
sha256sum -c --ignore-missing SHA256SUMS
```

## Requirements

Linux with systemd, an NVIDIA GPU of compute capability 8.0 or newer (Ampere and later), and a driver
supporting CUDA 12.4+. `brae-node init` checks all of this and explains what is missing.
