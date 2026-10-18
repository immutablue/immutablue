#!/bin/bash
# drift-report.sh - compare the /immutablue skill baseline with the current pins
#
# Prints, for immutablue itself, every deps/ submodule and cmacs:
#   - the commit the skill was last reviewed against (from SKILL.md)
#   - the commit checked out now
#   - how many commits lie between them, and which doc files changed
#
# Read-only: it runs git log/diff and nothing else.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

SKILL_REL="artifacts/overrides/usr/share/immutablue/skills/immutablue/SKILL.md"

usage () {
	cat <<'EOF'
drift-report.sh - what changed since the /immutablue skill was last reviewed

Usage:
  drift-report.sh [--repo DIR] [--cmacs DIR] [--log] [--docs]
  drift-report.sh -h | --help
  drift-report.sh --license

Options:
  --repo DIR    immutablue checkout (default: the git toplevel of $PWD)
  --cmacs DIR   cmacs checkout (default: <repo>/../cmacs)
  --log         also print `git log --oneline' for every changed component
  --docs        also print `git diff --stat' of docs/*.org/*.md per component
  -h, --help    this help
  --license     print the license

Examples:
  drift-report.sh                      # summary table
  drift-report.sh --log --docs         # everything needed to plan a review
  drift-report.sh --cmacs ~/src/cmacs  # cmacs checked out somewhere else
EOF
}

# Pull the cmacs baseline commit out of the prose under the baseline block:
# the first backticked hex string of 12+ characters after "checked against cmacs".
cmacs_baseline () {
	local skill="${1}"

	tr '\n' ' ' < "${skill}" \
		| grep -oE "checked against cmacs[^\`]*\`[0-9a-f]{12,40}\`" \
		| head -n1 \
		| grep -oE '[0-9a-f]{12,40}' || true
}

# Print one row, and optionally the log and doc diff, for one component.
report_one () {
	if [[ $# -ne 5 ]]
	then
		echo "\`report_one()\` requires 5 positional arguments"
		echo 'report_one <name> <dir> <base> <show_log> <show_docs>'
		exit 1
	fi

	local name="${1}"
	local dir="${2}"
	local base="${3}"
	local show_log="${4}"
	local show_docs="${5}"
	local head
	local count
	local state

	head="$(git -C "${dir}" rev-parse HEAD 2>/dev/null || echo "")"
	if [[ -z "${head}" ]]
	then
		printf '%-20s %-14s base=%.12s head=%s\n' "${name}" "NO CHECKOUT" "${base}" "-"
		return 0
	fi
	if [[ -z "${base}" ]]
	then
		printf '%-20s %-14s base=%s head=%.12s\n' "${name}" "NO BASELINE" "-" "${head}"
		return 0
	fi
	if ! git -C "${dir}" cat-file -e "${base}^{commit}" 2>/dev/null
	then
		printf '%-20s %-14s base=%.12s head=%.12s  (fetch: base not in this clone)\n' \
			"${name}" "UNKNOWN BASE" "${base}" "${head}"
		return 0
	fi

	count="$(git -C "${dir}" rev-list --count "${base}..${head}")"
	if [[ "${count}" -eq 0 ]] && [[ "$(git -C "${dir}" rev-parse "${base}")" == "${head}" ]]
	then
		state="same"
	elif [[ "${count}" -eq 0 ]]
	then
		state="BEHIND"
	else
		state="CHANGED"
	fi
	printf '%-20s %-14s base=%.12s head=%.12s commits=%s\n' \
		"${name}" "${state}" "${base}" "${head}" "${count}"

	if [[ "${state}" == "same" ]]
	then
		return 0
	fi
	if [[ "${show_log}" == "true" ]]
	then
		git -C "${dir}" log --oneline "${base}..${head}" | sed 's/^/    /'
	fi
	if [[ "${show_docs}" == "true" ]]
	then
		git -C "${dir}" diff --stat "${base}..${head}" -- docs doc_org '*.org' '*.md' \
			| sed 's/^/    docs: /'
	fi
}

main () {
	local repo=""
	local cmacs=""
	local show_log="false"
	local show_docs="false"
	local skill
	local name
	local base

	while [[ $# -gt 0 ]]
	do
		case "${1}" in
			--repo)    repo="${2:?--repo needs a directory}"; shift 2 ;;
			--cmacs)   cmacs="${2:?--cmacs needs a directory}"; shift 2 ;;
			--log)     show_log="true"; shift ;;
			--docs)    show_docs="true"; shift ;;
			-h|--help) usage; exit 0 ;;
			--license) echo "AGPL-3.0-or-later: https://www.gnu.org/licenses/agpl-3.0.html"; exit 0 ;;
			*)         echo "unknown argument: ${1}" >&2; usage >&2; exit 1 ;;
		esac
	done

	if [[ -z "${repo}" ]]
	then
		repo="$(git rev-parse --show-toplevel)"
	fi
	if [[ -z "${cmacs}" ]]
	then
		cmacs="${repo}/../cmacs"
	fi
	skill="${repo}/${SKILL_REL}"
	if [[ ! -f "${skill}" ]]
	then
		echo "no skill at ${skill}" >&2
		exit 1
	fi

	# The baseline list is the heredoc between `<<'EOF'` and `EOF` inside the
	# skill-baseline markers: "<name> <commit>" per line.
	while read -r name base
	do
		if [[ "${name}" == "immutablue" ]]
		then
			report_one "${name}" "${repo}" "${base}" "${show_log}" "${show_docs}"
		else
			report_one "${name}" "${repo}/deps/${name}" "${base}" "${show_log}" "${show_docs}"
		fi
	done < <(sed -n '/skill-baseline:start/,/skill-baseline:end/p' "${skill}" \
		| sed -n "/<<'EOF'/,/^EOF/p" | sed '1d;$d')

	# A submodule that exists but has no baseline line yet.
	while read -r name
	do
		if ! sed -n '/skill-baseline:start/,/skill-baseline:end/p' "${skill}" \
			| grep -qE "^${name}[[:space:]]"
		then
			report_one "${name}" "${repo}/deps/${name}" "" "${show_log}" "${show_docs}"
		fi
	done < <(git -C "${repo}" submodule status deps/ | awk '{print $2}' | sed 's|^deps/||')

	report_one "cmacs" "${cmacs}" "$(cmacs_baseline "${skill}")" "${show_log}" "${show_docs}"

	# cmacs bundles its own copies of several deps; their docs are what lands
	# in /usr/share/emacs/*/doc_org/cmacs/deps/, so the pins matter.
	if [[ -d "${cmacs}" ]]
	then
		echo
		echo "cmacs's own submodule pins (its doc_org/cmacs/deps/ follows these):"
		git -C "${cmacs}" submodule status deps/ 2>/dev/null \
			| awk '{sub(/^[-+U ]/, "", $1); printf "    %-20s %.12s\n", $2, $1}' \
			| sed 's|deps/||'
	fi
}

main "$@"
