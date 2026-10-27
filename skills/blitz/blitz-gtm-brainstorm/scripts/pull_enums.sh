#!/usr/bin/env bash
# Pull Blitz's canonical, case-sensitive enum values LIVE from the OpenAPI spec, and search them
# without dumping the whole list (the `industry` enum alone is 535 values — a context bomb).
#
# This mirrors how the official Blitz JS SDK generates its enums
# (https://github.com/api-blitz/blitz-api-js/blob/main/scripts/gen-enums.ts): it reads the live
# spec at /openapi, walks the REQUEST BODIES (response schemas such as the /changelog `type` enum
# are skipped — they share property names with request filters and would look like a divergent
# enum), maps each `type:"string"` + `enum` array to a class by its owning request property,
# collapses the 6-12 identical occurrences, de-dupes values (order preserved), and emits a
# structured JSON artifact. Same guardrails as the SDK: it ERRORS on a divergent or missing enum
# (an upstream restructure a human should look at) and WARNS on unmapped ones.
#
# Why pull live every time: these values are case-sensitive and exact-match ("SaaS" != "Software
# Development"), and the dataset changes. The API rejects an unknown value with a 422 that names the
# field and suggests the closest value (no records spent); this script lets you get it right before
# the call. Why enums are precision knobs rather than the search backbone: strategy.md.
# Watch near-duplicates — pick the exact one the dataset uses:
#   "Hospital and Health Care" vs "Hospitals and Health Care";
#   "Airlines and Aviation" vs "Airlines/Aviation"; "E-learning" vs "E-Learning Providers".
# The spec stores one industry with a backslash-escaped apostrophe (Women\\'s Handbag
# Manufacturing); the script emits the plain apostrophe, which the API accepts.
#
# Needs: curl + jq (jq is already required by probe_volume.sh). fzf is optional — if it's
# installed and stdout is a terminal, `get` opens an interactive picker; agents get plain lines.
#
# Usage:
#   bash pull_enums.sh list                       # enum names + counts + spec version (cheap)
#   bash pull_enums.sh search industry "health"   # exact values matching a regex, within one enum
#   bash pull_enums.sh search "venture"           # search across ALL enums -> "Enum<TAB>value"
#   bash pull_enums.sh get job_level              # every value of one enum, one per line
#   bash pull_enums.sh save <path>                # write the full JSON artifact to <path>
#   bash pull_enums.sh json                       # print the full JSON artifact to stdout
#
# Enum names are case-insensitive and accept the request property or the SDK class, e.g.
#   industry | Industry, type | company_type | CompanyType, employee_range | headcount | size,
#   continent, sales_region | region, job_function | function, job_level | level,
#   last_funding_type | funding, mx_provider | provider | mx,
#   seniority (a JOB POSTING's years-of-experience band — not job_level), employment_type,
#   work_arrangement, country_code | country.
#
# Validating several values in one brief? Fetch once, then point the others at it (skips re-fetch):
#   bash pull_enums.sh save /tmp/blitz-enums.json
#   BLITZ_ENUMS_CACHE=/tmp/blitz-enums.json bash pull_enums.sh search industry "fintech"
set -uo pipefail

SPEC_URL="${BLITZ_OPENAPI_URL:-https://api.blitz-api.ai/openapi}"   # override for a staging spec
FETCH_TIMEOUT=15
FETCH_RETRIES=3

# country_code is NOT a spec enum — the API takes free ISO 3166-1 alpha-2 codes, unchecked (a wrong
# one such as "USA" returns 0, not a 422) — so it can't be pulled. This common subset is served
# (clearly marked static) so every enum shares one search UX; the full accepted list is the
# Geography page (/guide/reference/normalization/geography) in the Blitz docs.
# "WORLD" is the global selector for Waterfall ICP / Employee Finder.
COUNTRY_CODES='["US","GB","FR","CA","DE","AU","NL","ES","IT","IN","BR","SG","SE","CH","BE","DK","NO","FI","PL","IL","JP","KR","CN","MX","AR","CL","CO","ZA","AE","SA","WORLD"]'

# ---- jq: shared defs (the STRUCTURAL skip-set + PROPERTY_TO_CLASS map from gen-enums.ts) --------
JQ_DEFS='
def structural: {
  "items":1,"include":1,"exclude":1,"properties":1,"schema":1,"content":1,
  "requestBody":1,"parameters":1,"get":1,"post":1,"put":1,"patch":1,"delete":1,
  "anyOf":1,"allOf":1,"oneOf":1,
  "application/json":1,"application/x-www-form-urlencoded":1,"multipart/form-data":1
};
def prop_to_class: {
  "industry":"Industry","type":"CompanyType","employee_range":"EmployeeRange",
  "size":"EmployeeRange",
  "continent":"Continent","sales_region":"SalesRegion","job_function":"JobFunction",
  "job_level":"JobLevel","last_funding_type":"LastFundingType","provider":"MxProvider",
  "seniority":"Seniority","employment_type":"EmploymentType","work_arrangement":"WorkArrangement"
};
def class_order: ["Industry","CompanyType","EmployeeRange","Continent","SalesRegion","JobFunction","JobLevel","LastFundingType","MxProvider","Seniority","EmploymentType","WorkArrangement"];
# Drop exact-duplicate values, preserving first-seen order (matches the SDK dedupeValues).
def dedupe: reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);
# Collapse a backslash-escaped apostrophe (the spec escapes one in a Women handbag industry) to a plain one.
def unescape: ([39] | implode) as $a | gsub("\\\\+" + $a; $a);
# The mapped enum hits: nearest non-structural ancestor key -> class, values de-duped. Request
# bodies only — a response schema can reuse a property name (the /changelog `type` enum).
def hits:
  [ paths(objects) as $p
    | select($p[0]=="paths" and ($p | index("requestBody")) != null)
    | getpath($p) as $v
    | select((($v|type)=="object") and ($v.type=="string")
             and (($v.enum|type)=="array") and (all($v.enum[]; type=="string")))
    | ([ $p[] | select(type=="string") ] | map(select(structural[.] | not)) | last) as $owner
    | { owner: $owner, class: (prop_to_class[$owner] // null),
        values: ($v.enum | map(unescape) | dedupe), path: ($p | map(tostring) | join(".")) } ];
# Case-insensitive enum-name resolution: request property OR SDK class, punctuation-insensitive.
def aliases: {
  "industry":"Industry","industries":"Industry",
  "type":"CompanyType","companytype":"CompanyType","company":"CompanyType",
  "employeerange":"EmployeeRange","employees":"EmployeeRange","headcount":"EmployeeRange","size":"EmployeeRange",
  "continent":"Continent",
  "salesregion":"SalesRegion","region":"SalesRegion",
  "jobfunction":"JobFunction","function":"JobFunction",
  "joblevel":"JobLevel","level":"JobLevel",
  "lastfundingtype":"LastFundingType","funding":"LastFundingType",
  "mxprovider":"MxProvider","provider":"MxProvider","mx":"MxProvider",
  "employmenttype":"EmploymentType","workarrangement":"WorkArrangement",
  "countrycode":"CountryCode","country":"CountryCode","countries":"CountryCode"
};
def resolve($name):
  ($name | ascii_downcase | gsub("[ _-]"; "")) as $k
  | ([ (aliases[$k] // empty),
       (.enums | keys[] | select((ascii_downcase | gsub("[ _-]"; "")) == $k)) ] | unique) as $m
  | if ($m | length) == 0 then error("UNKNOWN_ENUM:\($name)") else $m[0] end;
'

# ---- jq: build the artifact from the live spec (port of extractEnums + buildArtifact) ----------
# Adds the static CountryCode list last so it shares the search UX. ERRORs on divergent/missing.
JQ_EXTRACT='
(.info.version) as $version
| hits as $hits
| ($hits | map(select(.class != null)) | group_by(.class)) as $groups
| ($groups | map(select((map(.values | tojson) | unique | length) > 1))) as $divergent
| (if ($divergent | length) > 0
   then error("DIVERGENT_ENUM:" + ($divergent | map(.[0].class) | join(", "))) else . end)
| (class_order - ($groups | map(.[0].class))) as $missing
| (if ($missing | length) > 0
   then error("MISSING_ENUM:" + ($missing | join(", "))) else . end)
| ($groups | map({ (.[0].class): (.[0].values) }) | add) as $byclass
| (reduce class_order[] as $c ({}; . + { ($c): $byclass[$c] })) as $enums
| {
    _comment: "Enum value lists pulled from the Blitz OpenAPI spec and de-duplicated. Generated by pull_enums.sh from \($src) — do not hand-edit; re-run to refresh. Each enum is inlined and repeated across endpoints/content-types in the spec; identical occurrences are collapsed and values kept byte-for-byte. CountryCode is NOT a spec enum (free ISO 3166-1 codes) — it is a static subset from the script.",
    _source_url: $src,
    spec_version: (if ($version|type)=="string" then $version else "unknown" end),
    enums: ($enums + { "CountryCode": $cc })
  }
'
# Unmapped string enums (owner present, no class) — flagged so a new upstream enum gets mapped.
JQ_WARN='hits | map(select(.owner != null and .class == null) | .owner) | unique | .[]'

die() { echo "$*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required (brew install jq)"

# Translate jq's guardrail errors into a clear message + exit.
explain_jq_error() {
  local err="$1"
  case "$err" in
    *DIVERGENT_ENUM:*) echo "ERROR: an enum has divergent definitions across the spec (${err#*DIVERGENT_ENUM:}). An upstream restructure needs a human — inspect the spec, do not auto-regenerate." >&2 ;;
    *MISSING_ENUM:*)   echo "ERROR: the spec is missing expected enum(s) (${err#*MISSING_ENUM:}). A mapped request property was renamed/removed upstream — refusing to silently drop an enum." >&2 ;;
    *UNKNOWN_ENUM:*)   echo "ERROR: unknown enum '${err#*UNKNOWN_ENUM:}'. Run 'pull_enums.sh list' for valid names." >&2 ;;
    *)                 echo "$err" >&2 ;;
  esac
}

# Produce the artifact JSON to stdout. Live by default; BLITZ_ENUMS_CACHE reuses a saved artifact.
build_artifact() {
  # Opt-in reuse of a previously-saved artifact (skips the network for batch validation).
  if [ -n "${BLITZ_ENUMS_CACHE:-}" ] && [ -f "${BLITZ_ENUMS_CACHE}" ]; then
    cat "${BLITZ_ENUMS_CACHE}"; return 0
  fi

  local spec err artifact
  spec="$(curl -fsSL --max-time "$FETCH_TIMEOUT" --retry "$FETCH_RETRIES" --retry-delay 1 \
            -H 'accept: application/json' "$SPEC_URL" 2>/dev/null)"
  if [ -n "$spec" ]; then
    # Surface any unmapped enums (maintenance signal), then build the artifact.
    local unmapped
    unmapped="$(printf '%s' "$spec" | jq -r "$JQ_DEFS $JQ_WARN" 2>/dev/null)"
    [ -n "$unmapped" ] && echo "[pull_enums] WARN: unmapped enum owner(s) in spec: $(echo "$unmapped" | paste -sd, -). Add to prop_to_class if they should be generated." >&2

    if artifact="$(printf '%s' "$spec" \
        | jq --arg src "$SPEC_URL" --argjson cc "$COUNTRY_CODES" "$JQ_DEFS $JQ_EXTRACT" 2>/tmp/.pull_enums_err)"; then
      printf '%s\n' "$artifact"; return 0
    else
      explain_jq_error "$(cat /tmp/.pull_enums_err 2>/dev/null)"; rm -f /tmp/.pull_enums_err; return 1
    fi
  fi

  die "Could not fetch the spec (${SPEC_URL}). Re-run when online, or read the values on the Blitz docs normalization pages (https://docs.blitz-api.ai/guide/reference/normalization)."
}

# Print one enum's values, optionally through fzf for interactive humans (agents get plain lines).
emit_values() {
  if [ -t 1 ] && command -v fzf >/dev/null 2>&1 && [ "${BLITZ_ENUMS_NO_FZF:-}" != "1" ]; then
    fzf --multi --prompt="enum value> " --height=80% || true
  else
    cat
  fi
}

usage() {
  # Print the header comment block (everything from line 2 up to the first non-comment line).
  awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"
}

cmd="${1:-list}"
case "$cmd" in
  -h|--help|help) usage; exit 0 ;;

  list)
    art="$(build_artifact)" || exit 1
    printf '%s\n' "$art" | jq -r '
      "spec_version=\(.spec_version)  source=\(._source_url)",
      "",
      (.enums | to_entries[] | "  \(.key) (\(.value|length))")'
    echo
    echo "Search an enum: pull_enums.sh search <enum> \"<regex>\"   (e.g. search industry \"health\")"
    ;;

  get)
    name="${2:-}"; [ -n "$name" ] || die "usage: pull_enums.sh get <enum>"
    art="$(build_artifact)" || exit 1
    if ! out="$(printf '%s' "$art" | jq -r --arg name "$name" "$JQ_DEFS"' resolve($name) as $c | .enums[$c][]' 2>/tmp/.pull_enums_err)"; then
      explain_jq_error "$(cat /tmp/.pull_enums_err)"; rm -f /tmp/.pull_enums_err; exit 1
    fi
    n="$(printf '%s\n' "$out" | grep -c . || true)"
    [ "$n" -gt 80 ] && echo "[pull_enums] $n values — narrow with: pull_enums.sh search $name \"<regex>\"" >&2
    printf '%s\n' "$out" | emit_values
    ;;

  search)
    art="$(build_artifact)" || exit 1
    if [ "$#" -ge 3 ]; then
      # search <enum> <regex>: matches within one enum
      name="$2"; q="$3"
      if ! printf '%s' "$art" | jq -r --arg name "$name" --arg q "$q" \
            "$JQ_DEFS"' resolve($name) as $c | .enums[$c][] | select(test($q;"i"))' 2>/tmp/.pull_enums_err; then
        explain_jq_error "$(cat /tmp/.pull_enums_err)"; rm -f /tmp/.pull_enums_err; exit 1
      fi
    elif [ "$#" -eq 2 ]; then
      # search <regex>: across all enums, prefixed with the enum name
      q="$2"
      printf '%s' "$art" | jq -r --arg q "$q" \
        '.enums | to_entries[] | .key as $c | .value[] | select(test($q;"i")) | "\($c)\t\(.)"'
    else
      die "usage: pull_enums.sh search <enum> \"<regex>\"   |   pull_enums.sh search \"<regex>\""
    fi
    ;;

  json)
    build_artifact || exit 1
    ;;

  save)
    dest="${2:-}"; [ -n "$dest" ] || die "usage: pull_enums.sh save <path>"
    art="$(build_artifact)" || exit 1
    printf '%s\n' "$art" > "$dest" || die "could not write $dest"
    echo "[pull_enums] wrote $(printf '%s' "$art" | jq -r '.enums | keys | length') enums to $dest (spec_version=$(printf '%s' "$art" | jq -r '.spec_version'))" >&2
    ;;

  *)
    die "unknown command '$cmd'. Run: pull_enums.sh --help"
    ;;
esac
