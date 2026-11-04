"""Storage scheduling on the application loop, with exactly one I/O worker."""

import asyncio
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from itertools import count


@dataclass
class StorageJob:
    order: int
    priority: int
    keys: frozenset
    prepare: object
    future: asyncio.Future


class StorageQueue:
    def __init__(self):
        self.executor = None
        self.pending = []
        self.runner = None
        self.sequence = count()
        self.closed = False

    def submit(self, prepare, *, priority=1, keys=()):
        if self.closed:
            raise RuntimeError("Storage is closed")
        loop = asyncio.get_running_loop()
        future = loop.create_future()
        self.pending.append(
            StorageJob(next(self.sequence), priority, frozenset(keys), prepare, future)
        )
        if self.runner is None:
            self.runner = asyncio.create_task(self._drain())
        return future

    async def _drain(self):
        if self.executor is None:
            self.executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="viewrv-storage")
        try:
            while self.pending:
                # Priority never bypasses an earlier operation on the same file.
                job = next(
                    candidate
                    for candidate in sorted(
                        self.pending, key=lambda item: (item.priority, item.order)
                    )
                    if not any(
                        earlier.order < candidate.order and earlier.keys & candidate.keys
                        for earlier in self.pending
                    )
                )
                self.pending.remove(job)
                try:
                    operation, args = job.prepare()
                    value = await asyncio.get_running_loop().run_in_executor(
                        self.executor, operation, *args
                    )
                    if not job.future.done():
                        job.future.set_result(value)
                except Exception as error:
                    if not job.future.done():
                        job.future.set_exception(error)
        finally:
            self.runner = None

    async def close(self):
        if self.runner:
            await asyncio.shield(self.runner)
        self.closed = True
        if self.executor:
            self.executor.shutdown(wait=True)
