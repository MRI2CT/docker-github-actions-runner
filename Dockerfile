FROM alpine:3.21 AS ca-certs

FROM ubuntu:focal
LABEL maintainer="myoung34@my.apsu.edu"

# Bootstrap HTTPS apt access before Ubuntu installs its own ca-certificates package.
COPY --from=ca-certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
ENV DEBIAN_FRONTEND=noninteractive
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.333.1"

ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY build/ /opt/build/
RUN bash /opt/build/install_base.sh \
  && rm -rf /opt/build

WORKDIR /actions-runner
COPY install_actions.sh /actions-runner

RUN bash /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

COPY token.sh entrypoint.sh app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
