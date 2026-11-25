"""Verify DOM delivery and native menu fallback from the foreground AppKit probe."""
import re
import sys
from pathlib import Path

log = Path(sys.argv[1]).read_text()
cases = re.split(r"CASE=(\d) active=1 key=1\n", log)[1:]
expected = [
    ("0", "0101", "11"),    # stock WKWebView
    ("1", "", "0101"),      # Wry child
    ("2", "0101", ""),      # Wry child, no menu key equivalent
    ("3", "0101", "11"),    # Wry child + workbench key routing
]
observed = [
    (tag, "".join(re.findall(r"^DOM (\d):true$", body, re.M)),
     "".join(re.findall(r"^menu key=(\d) ", body, re.M)))
    for tag, body in zip(cases[::2], cases[1::2])
]
if observed != expected or not log.rstrip().endswith("done"):
    sys.exit(f"unexpected key delivery: {observed!r}")
print("four foreground cases passed")
