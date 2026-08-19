#!/usr/bin/env bash
# Render README.md to build/zehnder-hrv-ha-guide.pdf
#
# Needs:
#   - node/npx (for the markdown -> HTML step, via `marked`)
#   - a Chromium-based browser for the HTML -> PDF step
#
# If no Chromium browser is found the script still writes build/guide.html.
# Open that in any browser and use Print -> Save as PDF.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/build"
HTML="$OUT/guide.html"
PDF="$OUT/zehnder-hrv-ha-guide.pdf"
REPO_URL="https://github.com/hbhrugubanda/zehnder-hrv-ha-guide"

mkdir -p "$OUT"

echo "==> Rendering markdown"
BODY="$(npx --yes marked@12 --gfm < "$ROOT/README.md")"

echo "==> Writing $HTML"
cat > "$HTML" <<HTMLEOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Zehnder ComfoAir Q + Home Assistant</title>
<style>
  @page { size: A4; margin: 18mm 16mm 20mm; }

  :root {
    --ink:       #14181c;
    --ink-soft:  #4b555f;
    --ink-faint: #79838d;
    --line:      #d5dbe1;
    --line-soft: #e6eaee;
    --accent:    #1b5b76;
    --surface:   #f5f7f9;
    --warn-bg:   #fbf1ec;
    --warn-line: #8e3216;
    --serif: "Iowan Old Style", "Palatino Linotype", Palatino, Georgia, serif;
    --sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    --mono: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  }

  * { box-sizing: border-box; }

  body {
    margin: 0 auto;
    max-width: 46em;
    padding: 2rem 1.25rem 4rem;
    background: #fff;
    color: var(--ink);
    font-family: var(--sans);
    font-size: 10.5pt;
    line-height: 1.6;
    -webkit-font-smoothing: antialiased;
  }

  h1, h2, h3 { font-family: var(--serif); font-weight: 600; text-wrap: balance; letter-spacing: -.01em; }

  h1 {
    font-size: 24pt;
    line-height: 1.12;
    margin: 0 0 .35em;
  }
  h2 {
    font-size: 15pt;
    margin: 2.2em 0 .7em;
    padding-bottom: .3em;
    border-bottom: 1px solid var(--line);
    break-after: avoid;
  }
  h3 {
    font-size: 11.5pt;
    margin: 1.6em 0 .5em;
    break-after: avoid;
  }

  p, ul, ol { margin: 0 0 .85em; }
  ul, ol { padding-left: 1.3em; }
  li { margin-bottom: .25em; }
  li::marker { color: var(--ink-faint); }

  a { color: var(--accent); word-break: break-word; }

  strong { font-weight: 650; }

  hr {
    border: 0;
    border-top: 1px solid var(--line-soft);
    margin: 2.2em 0;
  }

  code {
    font-family: var(--mono);
    font-size: .86em;
    background: var(--surface);
    border: 1px solid var(--line-soft);
    border-radius: 2px;
    padding: .08em .32em;
  }

  pre {
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 3px;
    padding: .8em .9em;
    overflow-x: auto;
    font-size: 8.6pt;
    line-height: 1.55;
    break-inside: avoid;
    margin: 0 0 1em;
  }
  pre code { background: none; border: 0; padding: 0; font-size: inherit; }

  blockquote {
    margin: 0 0 1em;
    padding: .75em 1em;
    background: var(--surface);
    border-left: 3px solid var(--accent);
    border-radius: 0 3px 3px 0;
    color: var(--ink-soft);
    break-inside: avoid;
  }
  blockquote p:last-child { margin-bottom: 0; }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 9pt;
    margin: 0 0 1.2em;
    font-variant-numeric: tabular-nums;
    break-inside: auto;
  }
  th, td {
    text-align: left;
    padding: .45em .6em;
    border-bottom: 1px solid var(--line-soft);
    vertical-align: top;
  }
  thead th {
    font-family: var(--mono);
    font-size: 7.5pt;
    letter-spacing: .08em;
    text-transform: uppercase;
    color: var(--ink-faint);
    background: var(--surface);
    border-bottom: 1px solid var(--line);
    font-weight: 500;
  }
  thead { display: table-header-group; }
  tr { break-inside: avoid; }
  td code { white-space: nowrap; font-size: .8em; }

  .doc-meta {
    margin: 0 0 2.5em;
    padding: .9em 1.05em;
    border: 1px solid var(--line);
    border-radius: 3px;
    font-size: 8.5pt;
    color: var(--ink-soft);
    line-height: 1.55;
  }
  .doc-meta span { font-family: var(--mono); font-size: 7.5pt; letter-spacing: .1em; text-transform: uppercase; color: var(--accent); display: block; margin-bottom: .3em; }

  em { color: var(--ink-soft); }

  @media print {
    body { padding: 0; max-width: none; }
    a { text-decoration: none; }
  }
</style>
</head>
<body>
<div class="doc-meta">
  <span>Source and updates</span>
  This guide is maintained at <a href="$REPO_URL">$REPO_URL</a>.
  Corrections and validation results are welcome as issues or pull requests — the ComfoConnect Pro section in particular is waiting on someone with the hardware.
</div>
$BODY
</body>
</html>
HTMLEOF

find_chromium() {
  local c
  for c in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
    "/Applications/Arc.app/Contents/MacOS/Arc" \
    "$(command -v chromium || true)" \
    "$(command -v google-chrome || true)"
  do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

if BROWSER="$(find_chromium)"; then
  echo "==> Printing PDF with $(basename "$BROWSER")"
  "$BROWSER" \
    --headless \
    --disable-gpu \
    --no-pdf-header-footer \
    --user-data-dir="$(mktemp -d)" \
    --print-to-pdf="$PDF" \
    "file://$HTML" 2>/dev/null || true

  if [ -s "$PDF" ]; then
    echo "==> Done: $PDF"
    exit 0
  fi
  echo "!! Headless print produced nothing usable."
fi

echo
echo "No usable Chromium print step. HTML is ready instead:"
echo "  $HTML"
echo "Open it in any browser and choose Print -> Save as PDF (A4, margins set by the page)."
