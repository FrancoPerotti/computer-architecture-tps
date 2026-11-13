"""Composition root for the one-process local core."""

import argparse
import asyncio
import json
import secrets
import socket
import sys
from contextlib import asynccontextmanager
from pathlib import Path
from urllib.parse import urlsplit
from uuid import uuid4

import uvicorn

from software.viewrv.adapters.assembler import PythonAssembler
from software.viewrv.adapters.files import FileStorage
from software.viewrv.adapters.http import create_app
from software.viewrv.adapters.programmer import HardwareAssets, OpenFPGALoader
from software.viewrv.adapters.serial import SerialTransport
from software.viewrv.adapters.usb import enumerate_serial_ports
from software.viewrv.client.platform import InstanceGuard, publish_discovery, runtime_directory
from software.viewrv.client.resources import load_examples, load_profile, resource_root
from software.viewrv.contracts import API_VERSION
from software.viewrv.core.application import Application


def run(
    resources=None,
    dev_origin=None,
    *,
    assembler=None,
    storage=None,
    serial_transport=None,
    programmer=None,
    port_enumerator=None,
):
    guard = InstanceGuard()
    if not guard.acquire():
        return 0  # Another candidate owns the instance; clients wait for its publication.
    path = runtime_directory() / "core.json"
    instance_id = str(uuid4())
    sock = socket.socket()
    try:
        resources = resources or resource_root()
        profile = load_profile(resources)
        examples = load_examples(resources, profile)
        if dev_origin:
            parsed = urlsplit(dev_origin)
            if (
                parsed.scheme != "http"
                or parsed.hostname not in {"127.0.0.1", "localhost"}
                or not parsed.port
                or parsed.path
                or parsed.query
                or parsed.fragment
                or parsed.username
            ):
                raise ValueError("Development origin must be an exact loopback HTTP origin")
        sock.bind(("127.0.0.1", 0))
        discovery = {
            "base_url": f"http://127.0.0.1:{sock.getsockname()[1]}",
            "instance_id": instance_id,
            "api_version": API_VERSION,
            "access_token": secrets.token_urlsafe(32),
        }
        application = Application(instance_id)

        startup_failure = None

        async def publish_when_ready():
            nonlocal startup_failure
            while not server.started and not server.should_exit:
                await asyncio.sleep(0.01)
            if server.started:
                try:
                    publish_discovery(path, discovery)
                except OSError as error:
                    startup_failure = error
                    server.should_exit = True

        @asynccontextmanager
        async def lifespan(app):
            await application.initialize(
                storage or FileStorage(),
                assembler or PythonAssembler(),
                examples,
                resources,
                serial_transport=serial_transport or SerialTransport(profile["memory_profile"]),
                programmer=programmer,
                programmer_factory=lambda queue: OpenFPGALoader(
                    HardwareAssets(resources, profile), queue
                ),
                port_enumerator=port_enumerator or enumerate_serial_ports,
                processor_profile=profile,
            )
            task = asyncio.create_task(publish_when_ready())
            try:
                yield
            finally:
                task.cancel()
                await asyncio.gather(task, return_exceptions=True)
                await application.shutdown()
                for subscription in tuple(application.subscriptions):
                    application.unsubscribe(subscription)

        async def shutdown():
            server.should_exit = True

        app = create_app(application, discovery, profile, shutdown, lifespan, dev_origin)
        server = uvicorn.Server(
            uvicorn.Config(
                app,
                host="127.0.0.1",
                port=0,
                workers=1,
                log_level="warning",
                access_log=False,
                ws="none",
            )
        )
        server.run(sockets=[sock])
        if startup_failure:
            raise startup_failure
        return 0
    finally:
        try:
            if json.loads(path.read_text())["instance_id"] == instance_id:
                path.unlink()
        except (OSError, ValueError, KeyError, TypeError):
            pass
        sock.close()
        guard.release()


def main():
    parser = argparse.ArgumentParser(description="Core local de viewrv")
    parser.add_argument("--resources", type=Path)
    parser.add_argument("--dev-origin")
    args = parser.parse_args()
    try:
        return run(args.resources, args.dev_origin)
    except (OSError, ValueError) as error:
        print(f"No se pudo iniciar el core: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
