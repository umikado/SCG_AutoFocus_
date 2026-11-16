"""Validate SwiftPM's evaluated Linux graph, not source-code conditionals."""
import json
import subprocess
from pathlib import Path
package = Path(__file__).resolve().parents[2] / "Packages/LyricClipsKit"
graph = json.loads(subprocess.check_output(["swift", "package", "dump-package"], cwd=package))
expected = {"LCCore", "LCText", "LCAlign", "LCTiming", "LCTemplates", "LCSubtitles", "LCModelStore", "LCCoreTests"}
assert {t["name"] for t in graph["targets"]} == expected
assert all(t["type"] != "binary" for t in graph["targets"])
dependencies = [item["sourceControl"][0] for item in graph["dependencies"]]
assert len(dependencies) == 1
assert dependencies[0]["identity"] == "swift-crypto"
assert dependencies[0]["requirement"] == {"exact": ["3.3.0"]}
assert dependencies[0]["location"]["remote"][0]["urlString"] == "https://github.com/apple/swift-crypto.git"
resolved = json.loads((package / "Package.resolved").read_text())
assert [(pin["identity"], pin["state"]["version"]) for pin in resolved["pins"]] == [("swift-crypto", "3.3.0")]
print("PASS: seven pure Swift targets; only pinned swift-crypto; no Apple binary targets")
