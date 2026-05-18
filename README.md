# container-mod-nf

A Nextflow DSL2 pipeline that installs Apptainer/Singularity containers onto an HPC module space using [`container-mod`](https://github.com/biocorecrg/container-mod). It resolves Docker image URIs by querying three sources in order — the [BioContainers API](https://api.biocontainers.pro), the [quay.io](https://quay.io) biocontainers registry, and Docker Hub — then calls `container-mod pipe` to pull and register them as environment modules.

Built for the BRC module space on the Hazel HPC cluster at NC State.

---

## Usage

```bash
# Install a single container (latest version)
nextflow run download_container.nf --container samtools --log_dir logs/

# Install a single container at a pinned version
nextflow run download_container.nf --container samtools --version 1.17 --log_dir logs/

# Install a batch of containers from a file (one name per line)
nextflow run download_container.nf --container containers.txt --file --log_dir logs/

# Resolve URIs only — skip image download, just log what was found
nextflow run download_container.nf --container samtools --uri_only --log_dir logs/
```

### Parameters

| Parameter     | Required | Description                                                                 |
|---------------|----------|-----------------------------------------------------------------------------|
| `--container` | Yes      | Container name (e.g. `samtools`) or path to a file listing containers       |
| `--log_dir`   | Yes      | Directory where success/error log files will be written                     |
| `--version`   | No       | Pin a specific tool version (default: latest available)                     |
| `--profile`   | No       | `container-mod` profile to use (default: `brc`)                             |
| `--file`      | No       | Flag — treat `--container` as a file path rather than a container name      |
| `--uri_only`  | No       | Flag — resolve URIs only; skip image download and log resolved URIs instead |
| `--help`      | No       | Print usage and exit                                                        |

### Output

Two timestamped log files are written to `--log_dir` after the run:

- `success.<timestamp>.log` — one line per successfully installed or already-existing container; in `--uri_only` mode, entries appear as `[OK] URI resolved: docker://...`
- `error.<timestamp>.log` — one line per failed container, including the error message

A summary (count of successes and errors) is also printed to the terminal.

---

## Pipeline Architecture

```
download_container.nf
  ├── GET_URI
  │     bin/get_container_uri.sh  →  bin/parse_biocontainer.py
  │     Queries BioContainers API, then quay.io, then Docker Hub; returns a docker:// URI
  │     [ERR] lines (not found in any source) bypass BUILD_CONTAINER entirely
  │
  ├── BUILD_CONTAINER  (skipped when --uri_only is set)
  │     bin/make_module.sh
  │     Calls `container-mod pipe` to pull the image and register it as a module
  │
  └── SUMMARIZE
        Creates summary log files
        Prints summary statistics to terminal
```

---

## Developer Notes

### Hidden config file: `scripts/config_mm.sh`

`make_module.sh` sources `scripts/config_mm.sh` at runtime. If running on a different system, you must create / alter it before running the pipeline.


### Script reference

| Script                        | Purpose                                                                                      |
|-------------------------------|----------------------------------------------------------------------------------------------|
| `bin/get_container_uri.sh`    | Queries BioContainers API, then quay.io, then Docker Hub in order; pipes JSON to `parse_biocontainer.py` |
| `bin/parse_biocontainer.py`   | Parses the API response; handles both old (`_cvN`) and new (`--hash`) tag formats; returns the best-matching `docker://` URI |
| `bin/make_module.sh`          | Sources `config_mm.sh`, checks if the `.sif` already exists, then calls `container-mod pipe` |

### Requirements

- Nextflow ≥ 23.x with DSL2
- `apptainer` module available on the compute node
- `container-mod` installed and accessible (path set in `config_mm.sh`)
- Python 3 (for `parse_biocontainer.py`)
- Internet access from nodes to `api.biocontainers.pro`, `quay.io`, and `hub.docker.com`
