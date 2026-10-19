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

FROM ubuntu:24.04@sha256:a2d43bffc46670d7108bb3c0468c67c5557c4c92e83e1e34cbff1322ad1b94dc AS runtime

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
RUN set -eu; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      bash coreutils findutils grep sed \
      libbz2-1.0 libreadline8t64 libstdc++6 zlib1g; \
    mkdir -p /usr/local/share/tp3-dev; \
    dpkg-query -W -f='${binary:Package}\t${Version}\n' > /usr/local/share/tp3-dev/runtime-packages.txt; \
    rm -rf /var/lib/apt/lists/*

# Incluye también ivl, ivlpp, targets, módulos VPI y archivos de soporte.
COPY --from=build /opt/iverilog /opt/iverilog
ENV PATH="/opt/iverilog/bin:$PATH"

LABEL org.opencontainers.image.title="TP3 development environment" \
      org.opencontainers.image.description="Ubuntu 24.04, Icarus Verilog 13.0, Bash y utilidades GNU para TP3" \
      org.opencontainers.image.source="https://github.com/FrancoPerotti/computer-architecture-tps" \
      org.opencontainers.image.version="ubuntu24.04-iverilog13.0" \
      io.github.francoperotti.tp3.iverilog.revision="dfeee909ed9f20b4870dd93423156c0170c0e1ff"

RUN iverilog -V && vvp -V
WORKDIR /workspace/tp3
CMD ["bash"]
