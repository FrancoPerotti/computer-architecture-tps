# Contexto de construcción: tp3/docker. Plataforma acordada: linux/amd64.
# Ubuntu 24.04, manifiesto específico de amd64 fijado por digest.
FROM ubuntu:24.04@sha256:a2d43bffc46670d7108bb3c0468c67c5557c4c92e83e1e34cbff1322ad1b94dc AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources

# La base mínima no trae certificados. Docker descarga este paquete por HTTPS;
# su contenido verificado permite arrancar APT contra el snapshot por HTTPS.
ADD https://snapshot.ubuntu.com/ubuntu/20261018T000000Z/pool/main/c/ca-certificates/ca-certificates_20240203_all.deb /tmp/ca-certificates.deb
RUN set -eu; \
    echo "641de77d8f142cfd62a1a6f964ba67b20754d3337c480efb529d086075a06c9a  /tmp/ca-certificates.deb" | sha256sum --check -; \
    dpkg-deb --extract /tmp/ca-certificates.deb /tmp/bootstrap-ca; \
    mkdir -p /etc/ssl/certs; \
    cat /tmp/bootstrap-ca/usr/share/ca-certificates/mozilla/*.crt > /etc/ssl/certs/ca-certificates.crt; \
    test "$(dpkg --print-architecture)" = amd64; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      autoconf bison build-essential ca-certificates flex gperf \
      libbz2-dev libreadline-dev zlib1g-dev; \
    rm -rf /var/lib/apt/lists/* /tmp/bootstrap-ca /tmp/ca-certificates.deb

# Commit al que apunta el tag v13_0; no se sigue una rama mutable.
ADD https://codeload.github.com/steveicarus/iverilog/tar.gz/dfeee909ed9f20b4870dd93423156c0170c0e1ff /tmp/iverilog-source.tar.gz
RUN set -eu; \
    echo "c3a18398dd25073845550af2f35926193f4d3aa7cd7080122bdc501f59717c00  /tmp/iverilog-source.tar.gz" | sha256sum --check -; \
    mkdir -p /build/iverilog; \
    tar --extract --gzip --file=/tmp/iverilog-source.tar.gz --directory=/build/iverilog --strip-components=1; \
    cd /build/iverilog; \
    sh autoconf.sh; \
    ./configure --prefix=/opt/iverilog; \
    make -j2; \
    make install INSTALL_PROGRAM="install --strip"; \
    install -D -m644 COPYING /opt/iverilog/share/licenses/iverilog/COPYING; \
    install -D -m644 /tmp/iverilog-source.tar.gz /opt/iverilog/share/tp3-dev/iverilog-source.tar.gz; \
    dpkg-query -W -f='${binary:Package}\t${Version}\n' > /opt/iverilog/share/tp3-dev/build-packages.txt

FROM ubuntu:24.04@sha256:a2d43bffc46670d7108bb3c0468c67c5557c4c92e83e1e34cbff1322ad1b94dc AS validator

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
RUN set -eu; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      python3-pip python3-venv; \
    rm -rf /var/lib/apt/lists/*

COPY check-jsonschema.requirements.txt /tmp/check-jsonschema.requirements.txt
RUN set -eu; \
    python3 -m venv --without-pip /opt/check-jsonschema; \
    PIP_DISABLE_PIP_VERSION_CHECK=1 python3 -m pip \
      --python /opt/check-jsonschema/bin/python install \
      --index-url https://pypi.org/simple \
      --require-hashes --only-binary=:all: --no-cache-dir --no-compile \
      --requirement /tmp/check-jsonschema.requirements.txt; \
    install -D -m644 /tmp/check-jsonschema.requirements.txt \
      /opt/check-jsonschema/share/requirements.txt

# Binarios oficiales fijados; solo lint/formato y sus licencias pasan a runtime.
FROM build AS quality
ADD https://github.com/chipsalliance/verible/releases/download/v0.0-4296-g0f262651/verible-v0.0-4296-g0f262651-linux-static-x86_64.tar.gz /tmp/verible.tar.gz
ADD https://github.com/astral-sh/ruff/releases/download/0.17.1/ruff-x86_64-unknown-linux-gnu.tar.gz /tmp/ruff.tar.gz
ADD https://raw.githubusercontent.com/chipsalliance/verible/v0.0-4296-g0f262651/LICENSE /tmp/verible-LICENSE
ADD https://raw.githubusercontent.com/astral-sh/ruff/0.17.1/LICENSE /tmp/ruff-LICENSE
RUN set -eu; \
    echo "2cf0a64c57f5e72fc377e2db383e89658785686a0fcde9c24b0c6a4f405934e1  /tmp/verible-LICENSE" | sha256sum --check -; \
    echo "2597d854122b77ddc71971564ca2350a37608575ce324adc5650a2b2051c8f18  /tmp/ruff-LICENSE" | sha256sum --check -; \
    echo "8569defb891d2316067613ea00442af28a7a09d405d95b54c0c91f9942d26635  /tmp/verible.tar.gz" | sha256sum --check -; \
    echo "a293ac937715ae6fb6b64da86761598379e6149f40fbc00fde9ba8a2a562ac65  /tmp/ruff.tar.gz" | sha256sum --check -; \
    mkdir -p /tmp/verible /tmp/ruff /opt/quality/bin /opt/quality/share/licenses; \
    tar -xzf /tmp/verible.tar.gz -C /tmp/verible --strip-components=1; \
    tar -xzf /tmp/ruff.tar.gz -C /tmp/ruff --strip-components=1; \
    install /tmp/verible/bin/verible-verilog-lint /tmp/verible/bin/verible-verilog-format /tmp/ruff/ruff /opt/quality/bin/; \
    install -m644 /tmp/verible-LICENSE /tmp/ruff-LICENSE /opt/quality/share/licenses/

FROM ubuntu:24.04@sha256:a2d43bffc46670d7108bb3c0468c67c5557c4c92e83e1e34cbff1322ad1b94dc AS runtime

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
RUN set -eu; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      bash coreutils findutils grep sed python3 \
      make=4.3-4.1build2 verilator=5.020-1 shellcheck=0.9.0-1 shfmt=3.8.0-1 \
      libbz2-1.0 libreadline8t64 libstdc++6 zlib1g; \
    mkdir -p /usr/local/share/tp3-dev; \
    dpkg-query -W -f='${binary:Package}\t${Version}\n' > /usr/local/share/tp3-dev/runtime-packages.txt; \
    rm -rf /var/lib/apt/lists/*

# Incluye también ivl, ivlpp, targets, módulos VPI y archivos de soporte.
COPY --from=build /opt/iverilog /opt/iverilog
COPY --from=validator /opt/check-jsonschema /opt/check-jsonschema
COPY --from=quality /opt/quality /opt/quality
ENV PATH="/opt/quality/bin:/opt/check-jsonschema/bin:/opt/iverilog/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1

LABEL org.opencontainers.image.title="TP3 development environment" \
      org.opencontainers.image.description="Compilación, simulación, validación, formato y lint de TP3" \
      org.opencontainers.image.source="https://github.com/FrancoPerotti/computer-architecture-tps" \
      org.opencontainers.image.version="ubuntu24.04-iverilog13.0" \
      io.github.francoperotti.tp3.iverilog.revision="dfeee909ed9f20b4870dd93423156c0170c0e1ff" \
      io.github.francoperotti.tp3.check-jsonschema.version="0.38.2"

RUN iverilog -V && vvp -V && check-jsonschema --version && \
    make --version && verilator --version && shellcheck --version && shfmt --version && \
    ruff --version && verible-verilog-lint --version && verible-verilog-format --version
WORKDIR /workspace/tp3
CMD ["bash"]
