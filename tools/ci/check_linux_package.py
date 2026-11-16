"""Validate SwiftPM's evaluated Linux graph, not source-code conditionals."""
import json
import subprocess
from pathlib import Path
package = Path(__file__).resolve().parents[2] / "Packages/LyricClipsKit"
graph = json.loads(subprocess.check_output(["swift", "package", "dump-package"], cwd=package))
expected = {"LCCore", "LCText", "LCAlign", "LCTiming", "LCTemplates", "LCSubtitles", "LCModelStore", "LCCoreTests"}
assert {t["name"] for t in graph["targets"]} == expected
assert all(t["type"] != "binary" for t in graph["targets"])
assert graph["dependencies"] == [], "No external dependencies are approved in T1-1/T1-2"
print("PASS: seven pure Swift targets; no Apple or external dependencies")
