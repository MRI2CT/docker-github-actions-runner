#!/usr/bin/dumb-init /bin/bash
# shellcheck shell=bash
#
# Fleet entrypoint wrapper: lets multiple runner replicas scale from a single
# Compose service (RUNNER_REPLICAS / `docker compose up --scale runner=N`)
# while keeping RUNNER_WORKDIR host-path identity intact for sibling
# container actions.
#
# RUNNER_WORKDIR must point at ONE shared parent directory, bind-mounted at
# the same host and container path across every replica. Each replica carves
# out its own uniquely-named subdirectory (named after its own container
# hostname, which Docker assigns uniquely per replica) so concurrent jobs on
# different replicas never collide, with no per-replica Compose config.
set -euo pipefail

if [[ -n "${RUNNER_WORKDIR:-}" ]]; then
  _replica_workdir="${RUNNER_WORKDIR%/}/$(hostname)"
  export RUNNER_WORKDIR="${_replica_workdir}"
  mkdir -p "${RUNNER_WORKDIR}"
fi

# Hand off to the real entrypoint by naming the interpreter explicitly
# (rather than `exec /entrypoint.sh`) so its own dumb-init shebang doesn't
# spawn a second, nested dumb-init layer.
exec /bin/bash /entrypoint.sh "$@"
