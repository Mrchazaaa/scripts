# scripts

[![Tests](https://github.com/Mrchazaaa/scripts/actions/workflows/tests.yml/badge.svg)](https://github.com/Mrchazaaa/scripts/actions/workflows/tests.yml)

Personal development scripts for my own setup and day-to-day use.

This repo is intended to be run by piping scripts from `curl` into `bash`.
You can either run the main launcher:

```sh
curl -fsSL https://raw.githubusercontent.com/Mrchazaaa/scripts/main/main.sh | bash
```

Or run an individual script from `src`:

```sh
curl -fsSL https://raw.githubusercontent.com/Mrchazaaa/scripts/main/src/install-git.sh | bash
```

`main.sh` provides an interactive terminal prompt for selecting which scripts
from `src` should be executed.

## Tests

The test suite uses [bats-core](https://github.com/bats-core/bats-core).
On Debian/Ubuntu, install it with:

```sh
sudo apt-get update
sudo apt-get install -y bats
```

Then run:

```sh
bats tests
```
