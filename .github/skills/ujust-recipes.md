# ujust Recipe Authoring — Lessons Learned

> Accumulated from real failures. Read before writing or editing
> `files/just-overrides/default.just`.

---

## just 1.47.1 heredoc tokenizer — CRITICAL

just 1.47.1 aggressively tokenizes heredoc content inside shebang recipes,
rejecting constructs that look like syntax. Affected patterns:

- Lines starting with `-` (treated as error-ignore modifier)
- `...` (three dots — unknown token)
- `$(uname -m)` — the `-m` flag inside `$(...)` at certain column positions
- `(1/5/15 min)` — `(` followed by digit parsed as an expression
- `<<-EOF` heredocs with tab-indented content (mixed whitespace)

**Fix:** Replace all heredocs with `printf '%s\n'` per line.

```bash
# ❌ BAD — just tokenizes this
cat <<SUMMARY
- Kernel: ${KERNEL_VER}
* Load average (1/5/15 min): ${LOAD_AVG}
SUMMARY

# ✅ GOOD — just never sees these strings
printf '* Kernel: %s\n' "${KERNEL_VER}"
printf '* Load avg 1m/5m/15m: %s\n' "${LOAD_AVG}"
```

Pre-compute all command substitutions with flags (`uname -m`, `uname -r`) into
variables **before** any printf block.

---

## gum spin + output capture

`gum spin -- command` suppresses stdout. To capture output while showing a
spinner, route through a temp file:

```bash
GIST_OUT=$(mktemp); SCRIPT=$(mktemp)
printf '#!/bin/bash\ngh gist create ... > "%s"\n' "$GIST_OUT" > "$SCRIPT"
chmod +x "$SCRIPT"
gum spin --spinner pulse --title "Uploading..." -- bash "$SCRIPT"
GIST_URL=$(cat "$GIST_OUT")
rm -f "$GIST_OUT" "$SCRIPT"
```

To collect multiple variables while showing a spinner, write to a temp file and
`source` it after:

```bash
COLLECTION_OUT=$(mktemp)
gum spin --title "Collecting..." -- bash -c "
  VAL1=\$(command1)
  VAL2=\$(command2)
  printf 'VAR1=%q\nVAR2=%q\n' \"\$VAL1\" \"\$VAL2\" > '$COLLECTION_OUT'
"
source "$COLLECTION_OUT"
rm -f "$COLLECTION_OUT"
```

---

## ujust vs just — never confuse them

| Command | Where defined | Who uses it |
|---------|--------------|-------------|
| `just <recipe>` | `Justfile` (repo root) | Developers, CI |
| `ujust <recipe>` | `files/just-overrides/default.just` | End users inside the running image |

Changes to `files/just-overrides/default.just` require a BST element rebuild to
land in the image. The element is `elements/bluefin/just-overrides.bst`.

---

## GitHub issue form URL prefill

The `id` field in a GitHub issue template YAML maps directly to the URL query
parameter. Use it to pre-fill fields:

```
https://github.com/org/repo/issues/new?template=bug-report.yml&report-link=<encoded>
```

Encode reliably with Python:

```bash
python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$URL"
```

Fall back to `sed 's/ /%20/g; s/:/%3A/g; s|/|%2F|g'` for systems without Python.

---

## Lore

Raptors travel in **kettles**, not packs. Use "kettle" in all raptor-related
spinner messages and flavor text.
