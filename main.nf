#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process BASH_STEP_1 {
    input:
    val input_file
    val threshold

    output:
    path "step1_output.txt"

    script:
    """
    bash ${projectDir}/scripts/step1.sh "${input_file}" "${threshold}" > step1_output.txt
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
    // Create channels from params
    input_ch = Channel.value(params.input_file)
    thresh_ch = Channel.value(params.threshold)
    outdir_ch = Channel.value(params.output_dir)

    // Chain the processes
    step1_out  = BASH_STEP_1(input_ch, thresh_ch)
    step2_out  = PYTHON_STEP(step1_out)
    BASH_STEP_2(step2_out, outdir_ch)
}