#! /usr/bin/env bash
# Generates the egg YAML file from the .template.yaml by replacing the install
# script with the contents of the `install.sh`

OUTPUT_FILE=egg-valheim-bep-in-ex.yaml
TEMPLATE_FILE=egg-valheim-bep-in-ex.template.yaml

# Magic trick to replace the template with a multiline string from a variable.
#
# - The first sed applies 6 spaces of indentation on each line for proper YAML
#   formatting.
# - The second sed searches for "##SCRIPT_PLACEHOLDER##" from the template file
#   and dumps the contents of the stdin to replace it (z clears the placeholder
#   from the pattern space and r appends the stdin to its place. The indented
#   script is then read from stdin received from the first sed).
# - The second sed works, but leaves one extra empty space to the beginning of
#   the script string in the YAML, and I can't be bothered to figure out why
#   exactly it does that. Therefore, invoke sed third time and just kill all the
#   lines that are completely empty.
# - Then, just take anything the abhorrent pipe vomits out, and write it out to
#   the output YAML file.
cat install.sh \
	| sed 's/^/      /g' \
	| sed -e \
		$'/##SCRIPT_PLACEHOLDER##/{;z;r/dev/stdin\n}' \
		$TEMPLATE_FILE \
	| sed -e '/^$/d' \
	> $OUTPUT_FILE
