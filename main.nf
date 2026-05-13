#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process GET_URI {
    input:
    val names_ch // these can be used as CLI args with "${val_name}"

    output:
    stdout

    script:
    """
    bash ${projectDir}/scripts/get_container_uri.sh "${names_ch}"
    """
}

process BUILD_CONTAINER {
    input:
    val uri

    output:
    stdout

    script:
    """
    bash ${projectDir}/scripts/make_module.sh "${uri}" > final_output.txt
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

    // Chain the processes
    uri_ch  = GET_URI(names_ch).map { it.trim() }
    BUILD_CONTAINER(uri_ch)
}