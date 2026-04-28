process PRIDEPY_DOWNLOAD {
    tag "${meta.id}"
    label 'process_low'
    label 'process_long'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pridepy:0.0.14--pyhdfd78af_0'
        : 'biocontainers/pridepy:0.0.14--pyhdfd78af_0'}"

    input:
    val(meta)

    output:
    path "output/",      emit: download_dir, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p output
    pridepy ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pridepy: \$(pip show pridepy 2>/dev/null | grep Version | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    """
    mkdir -p output
    touch output/${meta.id}.placeholder

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pridepy: 0.0.14
    END_VERSIONS
    """
}
