#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process GET_URI {
    input:
    tuple val(name), val(version)

    output:
    stdout

    script:
    """
    get_container_uri.sh "${name}" "${version}"
    """
}

process BUILD_CONTAINER {
    input:
    val uri
    val profile
    path config_file

    output:
    stdout

    script:
    """
    make_module.sh "${uri}" "${profile}"
    """
}

process PATCH_LOG_HOOK {
    input:
    val result

    output:
    stdout

    script:
    """
    patch_log_hook.sh "${result}"
    """
}

process SUMMARIZE {
    publishDir params.log_dir, mode: 'copy'

    input:
    val results

    output:
    path "*.log"
    stdout emit: summary

    script:
    """
    TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
    touch "success.\${TIMESTAMP}.log" "error.\${TIMESTAMP}.log"

    while read -r line; do
        case "\$line" in
            \\[OK\\]*|\\[Already*)  echo "\$line" >> "success.\${TIMESTAMP}.log" ;;
            \\[ERR\\]*)             echo "\$line" >> "error.\${TIMESTAMP}.log"   ;;
        esac
    done <<'RESULTS_EOF'
${results.join('\n')}
RESULTS_EOF

    echo "=== DONE ==="
    echo "Successes: \$(wc -l < "success.\${TIMESTAMP}.log")"
    echo "Errors:    \$(wc -l < "error.\${TIMESTAMP}.log")"
    """
}

workflow {
    if (params.help) {
        log.info """
        |==================================================
        | container-mod_nf  --  BRC Container Installer
        |==================================================
        |
        | USAGE:
        |   nextflow run download_container.nf [options]
        |
        | REQUIRED:
        |   --container  <name|file>   Container name (e.g. samtools) or path to a
        |                              file listing containers (one per line)
        |   --log_dir   <path>         Directory to write success/error log files
        |
        | OPTIONAL:
        |   --version   <string>       Pin a specific tool version (default: latest)
        |                              Not compatible with --file; use per-line versions instead
        |   --profile   <string>       container-mod profile to use (default: brc)
        |   --file                     Treat --container as a file path (flag, no value)
        |                              Each line: container name, optionally followed by a
        |                              whitespace-delimited version (e.g. "samtools 1.17")
        |   --uri_only                 Resolve URIs only; skip image download (flag, no value)
        |   --from_uri                 Treat --container as a pre-formatted URI or file of URIs;
        |                              skip GET_URI (flag, no value)
        |   --help                     Show this message and exit
        |
        | EXAMPLES:
        |   nextflow run download_container.nf --container samtools --log_dir logs/
        |   nextflow run download_container.nf --container samtools --version 1.17 --log_dir logs/
        |   nextflow run download_container.nf --container containers.txt --file --log_dir logs/
        |   # containers.txt can include per-line versions: "samtools 1.17"
        |==================================================
        """.stripMargin()
        exit 0
    }

    // Required parameter checks
    if (!params.container) {
        error "Please provide --container <container_name or file_path>\nUse: nextflow run download_container.nf --help"
    } else if (!params.log_dir) {
        error "Please provide log file directory: --log_dir <path/to/dir>"
    }

    // Incompatible flag checks
    if (params.from_uri && params.uri_only) {
        error "Incompatible options: --from_uri and --uri_only cannot be used together"
    }
    if (params.from_uri && params.version) {
        error "Incompatible options: --from_uri and --version cannot be used together (version is already encoded in the URI)"
    }
    if (params.file && params.version) {
        error "Incompatible options: --file and --version cannot be used together. To pin a version in batch mode, add it after the container name in the file (e.g. 'samtools 1.17')"
    }

    // Input channel — always [name, version] tuples
    // File mode: version parsed from each line ("samtools 1.17" → ["samtools", "1.17"])
    // Single mode: version from --version flag (or empty string for latest)
    if (params.file) {
        names_ch = channel
            .fromPath(params.container)
            .splitText()
            .map { line ->
                def parts = line.trim().split(/\s+/)
                [parts[0], parts.size() > 1 ? parts[1] : '']
            }
            .filter { it[0] }
    } else {
        names_ch = channel.value([params.container, params.version ?: ''])
    }

    profile_ch = channel.value(params.profile)
    config_ch  = channel.value(file("${projectDir}/scripts/config_mm.sh"))

    // Phase 1: URI resolution
    if (params.from_uri) {
        // input is already a docker:// URI — strip version tuple, pass URIs straight through
        uri_valid_ch = names_ch.map { it[0] }
        uri_err_ch   = Channel.empty()
    } else {
        GET_URI(names_ch)
            .map { it.trim() }
            .branch {
                err:   it.startsWith('[ERR]')
                valid: true
            }
            .set { uri_ch }
        uri_valid_ch = uri_ch.valid
        uri_err_ch   = uri_ch.err
    }

    // Phase 2: build or log-only
    if (params.uri_only) {
        result_ch = uri_valid_ch.map { "[OK] URI resolved: ${it}" }
    } else {
        result_ch = BUILD_CONTAINER(uri_valid_ch, profile_ch, config_ch).map { it.trim() }
        PATCH_LOG_HOOK(result_ch).filter { it.trim() }.view()
    }

    SUMMARIZE(result_ch.mix(uri_err_ch).collect()).summary.view()
}
