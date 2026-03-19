process THERMORAWFILEPARSER {
    tag "$meta.id"
    label 'process_low'
    label 'process_single'
    label 'error_retry'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/thermorawfileparser:1.4.5--h05cac1d_1' :
        'biocontainers/thermorawfileparser:1.4.5--h05cac1d_1' }"

    input:
    tuple val(meta), path(raw)

    output:
    tuple val(meta), path("*.{mzML,mzML.gz,mgf,mgf.gz,parquet,parquet.gz}"), emit: spectra
    tuple val("${task.process}"), val('thermorawfileparser'), eval("ThermoRawFileParser.sh --version"), emit: versions_thermorawfileparser, topic: versions
    path "*.log",   emit: log
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // Default to indexed mzML format (-f=2) if not specified in args
    def formatArg = args.contains('-f=') ? '' : '-f=2'
    def prefix = task.ext.prefix ?: "${meta.id}"
    def suffix = args.contains("--format 0") || args.contains("-f 0") ? "mgf" :
                args.contains("--format 1") || args.contains("-f 1") ? "mzML" :
                args.contains("--format 2") || args.contains("-f 2") ? "mzML" :
                args.contains("--format 3") || args.contains("-f 3") ? "parquet" :
                "mzML"
    suffix = args.contains("--gzip")? "${suffix}.gz" : "${suffix}"

    """
    ThermoRawFileParser.sh \\
        -i='${raw}' \\
        ${formatArg} \\
        ${args} \\
        -o=./ 2>&1 | tee '${prefix}_conversion.log'
    """

    stub:
    def args = task.ext.args ?: ''
    def formatArg = args.contains('-f=') ? '' : '-f=2'
    def prefix = task.ext.prefix ?: "${meta.id}"
    def suffix = args.contains("--format 0") || args.contains("-f 0") ? "mgf" :
                args.contains("--format 1") || args.contains("-f 1") ? "mzML" :
                args.contains("--format 2") || args.contains("-f 2") ? "mzML" :
                args.contains("--format 3") || args.contains("-f 3") ? "parquet" :
                "mzML"
    suffix = args.contains("--gzip")? "${suffix}.gz" : "${suffix}"

    """
    touch '${prefix}.${suffix}'
    touch '${prefix}_conversion.log'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ThermoRawFileParser: \$(ThermoRawFileParser.sh --version)
    END_VERSIONS
    """
}
