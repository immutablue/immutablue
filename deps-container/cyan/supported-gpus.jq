# The proprietary driver supports some open-capable GPUs, but not Blackwell.
# NVIDIA marks those GPUs with gsp_proprietary_supported in its own table.
.chips |= map(select((.legacybranch | not) and
    ((.features // []) as $features |
        if $branch == "open" then
            ($features | index("kernelopen")) != null
        else
            ($features | index("kernelopen")) == null or
            ($features | index("gsp_proprietary_supported")) != null
        end))) |
if (.chips | length) > 0 then . else error("No supported GPUs") end
