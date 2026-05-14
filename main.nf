#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process GET_URI {
    input:
    val names // these can be used as CLI args with "${val_name}"
    val version // package version can be specified, if not, latest is chosen

    output:
    stdout

    script:
    """
    get_container_uri.sh "${names}" "${version}"
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

process SUMMARIZE {
    input:
    val results

    script:
    """
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    LOG_DIR="${params.log_dir}"
    mkdir -p "\$LOG_DIR"
    touch "\${LOG_DIR}/success.\${TIMESTAMP}.log" "\${LOG_DIR}/error.\${TIMESTAMP}.log"

    while read -r line; do
        case "\$line" in
            \\[OK\\]*|\\[Already*)  echo "\$line" >> "\${LOG_DIR}/success.\${TIMESTAMP}.log" ;;
            \\[ERR\\]*)             echo "\$line" >> "\${LOG_DIR}/error.\${TIMESTAMP}.log"   ;;
        esac
    done <<< ${results.join('\n')}

    echo "=== DONE ==="
    echo "Successes: \$(wc -l < "\${LOG_DIR}/success.\${TIMESTAMP}.log")"
    echo "Errors:    \$(wc -l < "\${LOG_DIR}/error.\${TIMESTAMP}.log")"
    """
}

workflow {
    // check for a non-empty "container" parameter
    if (!params.container) {
        error "Please provide --input <container_name or file_path>"
    } else if (!params.log_dir) {
        error "Please provide log file directory: --log_dir <path/to/dir>"
    }

    // if --file, treat the "container" parameter as an file with a list of containers
    if (params.file) {
        names_ch = channel
            .fromPath(params.container)
            .splitText()
            .map { row -> row.trim() }
            .filter { row -> row }
    } else {
        names_ch = channel.value(params.container)
    }

    //Add options
    version_ch = channel.value(params.version)
    profile_ch = channel.value(params.profile)
    config_ch  = channel.fromPath("${projectDir}/scripts/config_mm.sh")

    // Chain the processes
    uri_ch  = GET_URI(names_ch, version_ch).map { row -> row.trim() }
    status_ch = BUILD_CONTAINER(uri_ch, profile_ch, config_ch).map { row -> row.trim() }
    SUMMARIZE(status_ch.collect())
}