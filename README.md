# container-mod-nf

A Nextflow DSL2 pipeline that installs Apptainer/Singularity containers onto an HPC module space using [`container-mod`](https://github.com/biocorecrg/container-mod). It resolves Docker image URIs from the [BioContainers API](https://api.biocontainers.pro) and calls `container-mod pipe` to pull and register them as environment modules.

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
```

### Parameters

| Parameter     | Required | Description                                                                 |
|---------------|----------|-----------------------------------------------------------------------------|
| `--container` | Yes      | Container name (e.g. `samtools`) or path to a file listing containers       |
| `--log_dir`   | Yes      | Directory where success/error log files will be written                     |
| `--version`   | No       | Pin a specific tool version (default: latest available)                     |
| `--profile`   | No       | `container-mod` profile to use (default: `brc`)                             |
| `--file`      | No       | Flag — treat `--container` as a file path rather than a container name      |
| `--help`      | No       | Print usage and exit                                                        |

### Output

Two timestamped log files are written to `--log_dir` after the run:

- `success.<timestamp>.log` — one line per successfully installed or already-existing container
- `error.<timestamp>.log` — one line per failed container, including the error message

A summary (count of successes and errors) is also printed to the terminal.

---

## Pipeline Architecture

```
download_container.nf
  ├── GET_URI
  │     bin/get_container_uri.sh  →  bin/parse_biocontainer.py
  │     Queries the BioContainers REST API and returns a docker:// URI
  │
  └── BUILD_CONTAINER
        bin/make_module.sh
        Calls `container-mod pipe` to pull the image and register it as a module
```

---

## Developer Notes

### Hidden config file: `scripts/config_mm.sh`

`make_module.sh` sources `scripts/config_mm.sh` at runtime. This file is **not committed** to the repository because the paths it contains are specific to each HPC system. You must create it before running the pipeline.

**Template:**

```bash
# scripts/config_mm.sh

# Path to the container-mod executable
CONTAINER_MOD="/path/to/container-mod"

# Path to GNU parallel
PARALLEL="/path/to/parallel"

# container-mod profile (must match a profile defined in your container-mod installation)
MY_PROFILE="brc"

# Directory where .sif image files are stored (checked before pulling to avoid re-downloads)
IMAGE_PATH="/path/to/images"

# Base directory for container-mod log output
LOG_PATH="/path/to/logs"
```

On Hazel (BRC), the production values are:

| Variable        | Path                                                                                  |
|-----------------|---------------------------------------------------------------------------------------|
| `CONTAINER_MOD` | `/rs1/shares/brc/admin/tools/container-mod_v1/container-mod`                         |
| `PARALLEL`      | `/rs1/shares/brc/admin/tools/parallel-20250922/bin/parallel`                         |
| `IMAGE_PATH`    | `/rs1/shares/brc/admin/containers/images`                                             |
| `LOG_PATH`      | `/rs1/shares/brc/admin/containers/add_module/make_module/container-mod_logs`          |

### Script reference

| Script                        | Purpose                                                                                      |
|-------------------------------|----------------------------------------------------------------------------------------------|
| `bin/get_container_uri.sh`    | Queries the BioContainers REST API; pipes JSON response to `parse_biocontainer.py`           |
| `bin/parse_biocontainer.py`   | Parses the API response; handles both old (`_cvN`) and new (`--hash`) tag formats; returns the best-matching `docker://` URI |
| `bin/make_module.sh`          | Sources `config_mm.sh`, checks if the `.sif` already exists, then calls `container-mod pipe` |

### Requirements

- Nextflow ≥ 23.x with DSL2
- `apptainer` module available on the compute node
- GNU `parallel` (path set in `config_mm.sh`)
- `container-mod` installed and accessible (path set in `config_mm.sh`)
- Python 3 (for `parse_biocontainer.py`)
- Internet access from compute nodes to `api.biocontainers.pro`
