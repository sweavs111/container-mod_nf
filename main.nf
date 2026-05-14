#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process GET_URI {
    input:
    val names_ch // these can be used as CLI args with "${val_name}"
    val version_ch // package version can be specified, if not, latest is chosen

    output:
    stdout

    script:
    """
    bash ${projectDir}/scripts/get_container_uri.sh "${names_ch}" "${version_ch}"
    """
}

process BUILD_CONTAINER {
    input:
    val uri

    output:
    stdout

    script:
    """
    bash ${projectDir}/scripts/make_module.sh "${uri}"
    """
}

workflow {
    // check for a non-empty "container" parameter
    if (!params.container) {
        error "Please provide --input <container_name or file_path>"
    }

    // if --file, treat the "container" parameter as an file with a list of containers
    if (params.file) {
        names_ch = channel
            .fromPath(params.container)
            .splitText()
            .map { it.trim() }
            .filter { it }
    } else {
        names_ch = channel.value(params.container)
    }
    version_ch = channel.value(params.version)

    // Chain the processes
    uri_ch  = GET_URI(names_ch, version_ch).map { it.trim() }
    BUILD_CONTAINER(uri_ch)
}