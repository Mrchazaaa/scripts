# scripts

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
