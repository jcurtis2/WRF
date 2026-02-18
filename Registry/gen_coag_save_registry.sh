#!/bin/bash
#
# Generates registry.chem_coag_save.generated
# Creates chem_bcg (before coagulation) and chem_acg (after coagulation)
# 4D arrays that mirror the chem array for chem_opt==10
#
# Usage: bash gen_coag_save_registry.sh

REGISTRY_CHEM="$(dirname "$0")/registry.chem"
OUTFILE="$(dirname "$0")/registry.chem_coag_save.generated"

# Extract species list from cbmz_mosaic_8bin_aq package (chem_opt==10)
SPECIES_LINE=$(grep 'chem_opt==10' "$REGISTRY_CHEM" | head -1)
# Get everything after "chem:" and split by comma
SPECIES_STR=$(echo "$SPECIES_LINE" | sed 's/.*chem://')
IFS=',' read -ra SPECIES <<< "$SPECIES_STR"

echo "Found ${#SPECIES[@]} species for chem_opt==10"

# Build a lookup of species -> units from registry.chem state entries
declare -A UNITS
while IFS= read -r line; do
    # Extract variable name and units from state entries
    varname=$(echo "$line" | awk '{print $3}')
    # Extract the last quoted string (units)
    units=$(echo "$line" | grep -oP '"[^"]*"' | tail -1 | tr -d '"')
    if [ -n "$varname" ] && [ -n "$units" ]; then
        UNITS["$varname"]="$units"
    fi
done < <(grep 'ikjftb   chem ' "$REGISTRY_CHEM" | grep -v '^\s*#' | grep -v 'state.*-.*ikjftb')

# IO flag for output (h = history file)
IO_FLAG="h"

{
    echo "# Auto-generated registry entries for before/after coagulation fields"
    echo "# Source: cbmz_mosaic_8bin_aq package (chem_opt==10), ${#SPECIES[@]} species"
    echo "#"
    echo "# 4D table definitions (like chem has in registry.chem)"
    echo "state   real    -              ikjf   chem_bcg    1         -     -    -"
    echo "state   real    -              ikjf   chem_acg    1         -     -    -"
    echo "#"
    echo "# State entries for chem_bcg (before coagulation)"
    echo "#"

    for sp in "${SPECIES[@]}"; do
        sp=$(echo "$sp" | tr -d '[:space:]')
        unit="${UNITS[$sp]:-unknown}"
        printf "state   real   %-20s ikjf   chem_bcg    1    -    %s    \"%s_bcg\"    \"%s before coag\"    \"%s\"\n" \
            "${sp}_bcg" "$IO_FLAG" "$sp" "$sp" "$unit"
    done

    echo ""
    echo "#"
    echo "# State entries for chem_acg (after coagulation)"
    echo "#"

    for sp in "${SPECIES[@]}"; do
        sp=$(echo "$sp" | tr -d '[:space:]')
        unit="${UNITS[$sp]:-unknown}"
        printf "state   real   %-20s ikjf   chem_acg    1    -    %s    \"%s_acg\"    \"%s after coag\"    \"%s\"\n" \
            "${sp}_acg" "$IO_FLAG" "$sp" "$sp" "$unit"
    done

    echo ""
    echo "#"
    echo "# Package lines"
    echo "#"

    # Build bcg package species list
    BCG_LIST=""
    for sp in "${SPECIES[@]}"; do
        sp=$(echo "$sp" | tr -d '[:space:]')
        if [ -n "$BCG_LIST" ]; then BCG_LIST="${BCG_LIST},"; fi
        BCG_LIST="${BCG_LIST}${sp}_bcg"
    done

    # Build acg package species list
    ACG_LIST=""
    for sp in "${SPECIES[@]}"; do
        sp=$(echo "$sp" | tr -d '[:space:]')
        if [ -n "$ACG_LIST" ]; then ACG_LIST="${ACG_LIST},"; fi
        ACG_LIST="${ACG_LIST}${sp}_acg"
    done

    echo "package   cbmz_mosaic_8bin_aq_bcg  chem_opt==10  -  chem_bcg:${BCG_LIST}"
    echo "package   cbmz_mosaic_8bin_aq_acg  chem_opt==10  -  chem_acg:${ACG_LIST}"

} > "$OUTFILE"

echo "Written to $OUTFILE"
echo "Lines: $(wc -l < "$OUTFILE")"
