"""Import the real, externally built TP3 bitstream and bind its provenance/profile."""

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

SOFTWARE = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bitstream", type=Path)
    parser.add_argument(
        "--source-revision", required=True, help="Revisión Git completa del RTL sintetizado."
    )
    parser.add_argument(
        "--expected-sha256", required=True, help="Huella registrada por quien generó el bitstream."
    )
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_revision):
        parser.error("La revisión debe ser un SHA Git completo de 40 caracteres.")
    digest = hashlib.sha256(args.bitstream.read_bytes()).hexdigest()
    if args.bitstream.stat().st_size == 0 or digest != args.expected_sha256:
        parser.error("La huella no coincide con el bitstream generado.")
    profile = json.loads((SOFTWARE / "resources/content/processor_profile.json").read_text())
    value = {
        "schema_version": 1,
        "board": "basys3",
        "source_revision": args.source_revision,
        "processor_profile": {
            key: profile[key] for key in ("profile_id", "revision", "memory_profile")
        },
        "sha256": digest,
    }
    destination = SOFTWARE / "resources/hardware"
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.bitstream, destination / "processor.bit")
    (destination / "processor.json").write_text(json.dumps(value, indent=2) + "\n")
    print("Bitstream incorporado con perfil y huella; la aceptación física continúa pendiente.")


if __name__ == "__main__":
    main()
