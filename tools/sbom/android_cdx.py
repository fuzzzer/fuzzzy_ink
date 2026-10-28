"""CycloneDX SBOM of the Android app's native (Maven) dependencies.

Reads Gradle's resolved dependency tree on stdin (`gradlew :app:dependencies
--configuration productionReleaseRuntimeClasspath`) and writes a CycloneDX 1.5
JSON document to stdout: every Maven component that ships in the production
release, at the version Gradle resolved, sorted, with no timestamp, so the
output only changes when a dependency does. Called by `./sbom.sh android`.
"""

import json
import re
import sys

LINE = re.compile(
    r"^[\s|\\+`-]*"  # tree drawing
    r"(?P<group>[A-Za-z0-9_.\-]+):(?P<name>[A-Za-z0-9_.\-]+)"
    r"(?::(?P<version>[A-Za-z0-9_.+\-]+))?"
    r"(?: -> (?P<resolved>[A-Za-z0-9_.+\-]+))?"
    r"(?P<marks>(?: \([a-z*]\))*)\s*$"
)


def components(tree):
    found = {}
    for line in tree.splitlines():
        match = LINE.match(line)
        if not match or "(c)" in match["marks"] or "(n)" in match["marks"]:
            continue
        version = match["resolved"] or match["version"]
        if not version:
            continue
        key = (match["group"], match["name"], version)
        found[key] = {
            "type": "library",
            "group": match["group"],
            "name": match["name"],
            "version": version,
            "purl": f"pkg:maven/{match['group']}/{match['name']}@{version}",
            "bom-ref": f"pkg:maven/{match['group']}/{match['name']}@{version}",
        }
    return [found[key] for key in sorted(found)]


def main():
    found = components(sys.stdin.read())
    if not found:
        sys.exit("android_cdx.py: no dependencies in the Gradle output")
    json.dump(
        {
            "bomFormat": "CycloneDX",
            "specVersion": "1.5",
            "version": 1,
            "metadata": {
                "component": {
                    "type": "application",
                    "name": "fuzzzy_ink android (productionReleaseRuntimeClasspath)",
                    "bom-ref": "fuzzzy_ink-android",
                }
            },
            "components": found,
        },
        sys.stdout,
        indent=2,
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
