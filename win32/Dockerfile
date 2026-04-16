# Cross-compilation container: Linux host → Windows i686 (XP) target.
FROM fedora:43

COPY deps.sh /tmp/deps.sh
RUN bash /tmp/deps.sh && dnf clean all && rm /tmp/deps.sh

COPY build.sh /opt/build.sh
RUN chmod +x /opt/build.sh

ENV TRAM_ROOT=/projects
ENV OUT_DIR=/out
WORKDIR /projects
RUN mkdir -p /out

CMD ["bash", "/opt/build.sh"]
