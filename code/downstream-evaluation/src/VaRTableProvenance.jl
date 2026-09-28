# Table rendering may use the frozen pooled run after the R10 Kupiec-only fix.
# Calibration/resumption retains script 13's strict original-source check.
using SHA, TOML

function validate_var_table_sources(root, output, manifest)
    file_hash(path) = open(io -> bytes2hex(sha256(io)), path)
    for (path, recorded_hash) in manifest["hashes"]
        current_hash = file_hash(joinpath(root, path))
        current_hash == recorded_hash && continue
        path == "src/VaRBacktest.jl" || error("Pooled VaR input/source changed: $path")
        directory = joinpath(output, "source-corrections")
        record = TOML.parsefile(joinpath(directory, "R10.toml"))
        record["schema_version"] == 1 &&
            record["original_signature"] == manifest["signature"] &&
            record["original_sha256"] == recorded_hash &&
            record["corrected_sha256"] == current_hash &&
            file_hash(joinpath(directory, "VaRBacktest.before-R10.jl")) == recorded_hash ||
            error("Unverified R10 source correction for pooled VaR tables")
    end
    return true
end
