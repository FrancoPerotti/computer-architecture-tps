"""Loop-owned record writers; disk writes use the shared prioritized storage worker."""

import asyncio
from copy import deepcopy

from software.viewrv.core.records import warning


class RecordWriter:
    def __init__(self, session_id, queue, storage, enabled, changed=lambda: None):
        self.session_id, self.queue, self.storage = session_id, queue, storage
        self.status = "writing" if enabled else "disabled"
        self.limitations = []
        self.tail = None
        self.changed = changed

    def append(self, kind, value):
        if self.status in {"disabled", "failed", "complete"}:
            return
        unit = {
            "schema_version": 1,
            "session_id": self.session_id,
            "record_type": kind,
            "data": deepcopy(value),
        }
        previous = self.tail

        async def write():
            if previous:
                await asyncio.shield(previous)
            if self.status == "failed":
                return
            try:
                await self.queue.submit(
                    lambda: (self.storage.append_record, (unit,)),
                    priority=1,
                    keys=(f"record:{self.session_id}",),
                )
            except Exception as error:
                self.status = "failed"
                self.limitations.append(
                    warning(
                        "RECORD_WRITE_FAILED",
                        "record",
                        f"No se pudo conservar el registro: {error}",
                    )
                )
            else:
                if kind == "end":
                    self.status = "complete"
            self.changed()

        self.tail = asyncio.create_task(write())

    async def finish(self):
        if self.tail:
            await asyncio.shield(self.tail)
