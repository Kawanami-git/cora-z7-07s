FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

do_configure:append() {
    PCW="$(find "${B}" -type f -name pcw.dtsi 2>/dev/null | head -n 1)"
    Z7DTSI="$(find "${B}" -type f -name zynq-7000.dtsi 2>/dev/null | head -n 1)"

    # ---- pcw.dtsi: remove cpu1_debug block + fix num_cpus ----
    if [ -n "$PCW" ] && [ -f "$PCW" ]; then
        bbnote "Patching pcw.dtsi: $PCW"
        sed -i -E '/^[[:space:]]*&cpu1_debug[[:space:]]*\{/,/^[[:space:]]*\};[[:space:]]*$/d' "$PCW"
        sed -i -E 's/(^[[:space:]]*num_cpus[[:space:]]*=[[:space:]]*)<2>([[:space:]]*;)/\1<1>\2/' "$PCW"
    else
        bbwarn "pcw.dtsi not found under B=${B}"
    fi

    # ---- zynq-7000.dtsi: drop any node that references CPU1/PTM1 ----
    # if [ -n "$Z7DTSI" ] && [ -f "$Z7DTSI" ]; then
    #     bbnote "Patching zynq-7000.dtsi (drop CPU1/PTM1 related blocks): $Z7DTSI"

    #     awk '
    #     function delta_braces(s,   i,ch,d) {
    #         d=0
    #         for (i=1;i<=length(s);i++) {
    #             ch=substr(s,i,1)
    #             if (ch=="{") d++
    #             else if (ch=="}") d--
    #         }
    #         return d
    #     }

    #     BEGIN { depth=0; inblk=0; drop=0; blk_start_depth=0; }

    #     {
    #         line=$0

    #         # Detect entering a block (first "{" when not already inside)
    #         if (!inblk && line ~ /\{/) {
    #             inblk=1
    #             drop=0
    #             blk_start_depth = depth + delta_braces(line)
    #         }

    #         # If we are inside a block and we see CPU1/PTM1 references, mark whole block for drop
    #         if (inblk) {
    #             if (line ~ /cpu[[:space:]]*=[[:space:]]*<[^>]*&cpu1[^>]*>/) drop=1
    #             if (line ~ /ptm1_out_port/) drop=1
    #             if (line ~ /cpu1_debug/) drop=1
    #             if (line ~ /&cpu1([^0-9_]|$)/) drop=1
    #         }

    #         # Update brace depth
    #         depth += delta_braces(line)

    #         # Print only if we are not dropping this block
    #         if (!(inblk && drop)) print line

    #         # Leave block when we closed it
    #         if (inblk && depth < blk_start_depth) {
    #             inblk=0
    #             drop=0
    #         }
    #     }
    #     ' "$Z7DTSI" > "$Z7DTSI.tmp" && mv "$Z7DTSI.tmp" "$Z7DTSI"

    # else
    #     bbwarn "zynq-7000.dtsi not found under B=${B}"
    # fi
}