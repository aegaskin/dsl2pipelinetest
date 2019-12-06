#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/modulespipelinetest
========================================================================================
 nf-core/modulespipelinetest Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/nf-core/modulespipelinetest
----------------------------------------------------------------------------------------
*/



/*
 * SET UP CONFIGURATION VARIABLES
 */


// Stage config files
ch_multiqc_config = file(params.multiqc_config, checkIfExists: true)
ch_output_docs = file("$baseDir/docs/output.md", checkIfExists: true)

/*
 * Create a channel for input read files
 */
if (params.readPaths) {
    if (params.single_end) {
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [ file(row[1][0], checkIfExists: true) ] ] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into { ch_read_files_fastqc; ch_read_files_trimming }
    } else {
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [ file(row[1][0], checkIfExists: true), file(row[1][1], checkIfExists: true) ] ] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into { ch_read_files_fastqc; ch_read_files_trimming }
    }
} else {
    Channel
        .fromFilePairs(params.reads, size: params.single_end ? 1 : 2)
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nIf this is single-end data, please specify --single_end on the command line." }
        .into { ch_read_files_fastqc; ch_read_files_trimming }
}

// Check the hostnames against configured profiles
checkHostname()

// Import processes from nf-core/modules
params.module_version = '9fd356468d61ef384a02acebc4200d0ce1a08c0a'
local_modules_base = "./modules/"
web_modules_base = "https://raw.githubusercontent.com/nf-core/modules/${params.module_version}/"

try {
    include "${local_modules_base}/tools/fastqc/main.nf" params(params)
    include "${local_modules_base}/tools/trim_galore/main.nf" params(params)
} catch (Exception e) {
    include "${web_modules_base}/tools/fastqc/main.nf" params(params)
    include "${web_modules_base}/tools/trim_galore/main.nf" params(params)
}

/*
 * STEP 2 - MultiQC
 */
process multiqc {
    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    input:
    path 'data*/*'
    path multiqc_config

    output:
    file "*multiqc_report.html" into ch_multiqc_report
    file "*_data"
    file "multiqc_plots"

    script:
    """
    multiqc --config $multiqc_config .
    """
}


// Run the workflow
workflow {
    fastqc(ch_read_files_fastqc)

    trim_galore(ch_read_files_fastqc)

    multiqc(
        fastqc.out.mix(
            trim_galore.out[1]
        ).collect(),
        ch_multiqc_config
    )
}
