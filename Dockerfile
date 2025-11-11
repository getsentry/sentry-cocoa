# ================================================================================================================
# Downloader
# ================================================================================================================  

FROM debian:latest AS downloader
RUN apt-get update && apt-get install -y wget && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN wget -O mupdf-1.26.11-source.tar.gz https://casper.mupdf.com/downloads/archive/mupdf-1.26.11-source.tar.gz && \
    tar -xzf mupdf-1.26.11-source.tar.gz && \
    mv mupdf-1.26.11-source mupdf

# ================================================================================================================
# Builder
# ================================================================================================================

FROM debian:latest AS builder
RUN apt-get update && apt-get install -y gcc g++ make pkg-config && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=downloader /tmp/mupdf /tmp/mupdf
WORKDIR /tmp/mupdf
RUN make

# ================================================================================================================
# Release
# ================================================================================================================

FROM debian:latest AS release
RUN apt-get update && apt-get install -y make && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/mupdf /tmp/mupdf
RUN cd /tmp/mupdf && make install && rm -rf /tmp/mupdf
