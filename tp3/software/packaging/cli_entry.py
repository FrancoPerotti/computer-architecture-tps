"""Dispatch the public CLI or the private frozen Linux maintenance helper."""

import sys
from pathlib import Path

if sys.platform == "linux" and Path(sys.executable).name == ".viewrv-maintenance-native":
    from software.viewrv.installation.__main__ import main
else:
    from software.viewrv.cli.__main__ import main

raise SystemExit(main())
