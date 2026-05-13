#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process GET_URI {
    input:
    val names_ch // these can be used as CLI args with "${val_name}"

    script:
    """
    bash ${projectDir}/scripts/run_get_container_uri.sh "${names_ch}"
    """
}

process PYTHON_STEP {
    input:
    path step1_result

    output:
    path "step2_output.txt"

    script:
    """
    python3 ${projectDir}/scripts/process.py "${step1_result}" > step2_output.txt
    """
}

process BASH_STEP_2 {
    input:
    path step2_result
    val output_dir

    output:
    path "final_output.txt"

    script:
    """
    bash ${projectDir}/scripts/step2.sh "${step2_result}" "${output_dir}" > final_output.txt
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
    step1_out  = GET_URI(names_ch)
    step2_out  = PYTHON_STEP(step1_out)
    BASH_STEP_2(step2_out, outdir_ch)
}