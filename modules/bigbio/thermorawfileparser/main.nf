process THERMORAWFILEPARSER {
    tag "$meta.mzml_id"
    label 'process_low'
    label 'process_single'
    label 'error_retry'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/thermorawfileparser:1.4.5--h05cac1d_1' :
        'biocontainers/thermorawfileparser:1.4.5--h05cac1d_1' }"

    /*
     * stageInMode retry strategy rationale:
     * - Attempt 1: Use 'link' for most executors, 'symlink' for AWS Batch (due to file system constraints).
     * - Attempt 2: Use 'symlink' for most executors, 'copy' for AWS Batch (if linking failed).
     * - Attempt 3+: Always use 'copy' to maximize reliability.
     */
    def selectStageInMode(attempt, executor) {
        if (attempt == 1) {
            return executor == "awsbatch" ? 'symlink' : 'link'
        } else if (attempt == 2) {
            return executor == "awsbatch" ? 'copy' : 'symlink'
        } else {
            return 'copy'
        }
    }

    stageInMode { selectStageInMode(task.attempt, task.executor) }
    input:
    tuple val(meta), path(rawfile)

    output:
    tuple val(meta), path("*.{mzML,mgf,parquet}"), emit: convert_files
    path "versions.yml",   emit: versions
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    // Default to indexed mzML format (-f=2) if not specified in args
    def formatArg = args.contains('-f=') ? '' : '-f=2'

    """
    ThermoRawFileParser.sh -i='${rawfile}' ${formatArg} ${args} -o=./ 2>&1 | tee '${rawfile.baseName}_conversion.log'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ThermoRawFileParser: \$(ThermoRawFileParser.sh --version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"
    def args = task.ext.args ?: ''
    // Determine output format from args, default to mzML
    // Format 0 = MGF, formats 1-2 = mzML, format 3 = Parquet, format 4 = None
    def outputExt = (args =~ /-f=0\b/).find() ? 'mgf' : 'mzML'

    """
    touch '${prefix}.${outputExt}'
    touch '${prefix}_conversion.log'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ThermoRawFileParser: \$(ThermoRawFileParser.sh --version)
    END_VERSIONS
    """
}

