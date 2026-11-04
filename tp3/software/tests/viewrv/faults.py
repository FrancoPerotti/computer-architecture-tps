"""Fault-controlled file adapter for real GUI tests; not part of the product."""

import os
import time
from pathlib import Path

from software.tests.viewrv.controlled import ControlledAssembler
from software.viewrv.adapters.files import FileStorage


class FaultStorage(FileStorage):
    def write_recovery(self, snapshot):
        marker = os.environ.get("VIEWRV_TEST_RECOVERY_FAILURE")
        if marker and Path(marker).exists():
            raise PermissionError("No se pudo conservar la recuperación (fallo controlado).")
        return super().write_recovery(snapshot)


class DelayedAssembler(ControlledAssembler):
    def assemble(self, text):
        marker = os.environ.get("VIEWRV_TEST_ASSEMBLY_GATE")
        deadline = time.monotonic() + 15
        while marker and Path(marker).exists():
            if time.monotonic() >= deadline:
                raise TimeoutError("Controlled assembly gate timed out")
            time.sleep(0.025)
        return super().assemble(text)
