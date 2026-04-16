# CI checks container: builds + unit tests + matrix compile + integration regressions.
# Uses Mesa llvmpipe for headless rendering (no GPU required).
#
# Build from the tram-ci-cd/ root so linux/ is in the context:
#     docker build -f integrations/Dockerfile -t tram-ci-cd-integrations .
FROM fedora:43

COPY linux/deps.sh        /opt/linux/deps.sh
COPY integrations/deps.sh /opt/integrations/deps.sh
RUN bash /opt/integrations/deps.sh && dnf clean all

COPY linux/build.sh    /opt/linux/build.sh
COPY integrations/     /opt/integrations/
RUN find /opt -name '*.sh' -exec chmod +x {} \;

ENV TRAM_ROOT=/projects
ENV DISPLAY=:99
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV GALLIUM_DRIVER=llvmpipe
WORKDIR /projects

CMD ["bash", "/opt/integrations/run-tests.sh"]
