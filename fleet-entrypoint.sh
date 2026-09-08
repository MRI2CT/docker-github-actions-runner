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
#
# Each replica also registers one extra label, `replica-<hostname>`, unique to
# it. Because the workdir above is per-replica, a workflow whose jobs hand
# filesystem state to each other (build something, then test it) needs them all
# on the SAME replica -- and a shared label like `mri2ct-ci-fleet`, or even a
# per-host one like `dv2`, only narrows the choice to a pool, not to one runner.
# With a unique label per replica, such a workflow can have its first job report
# this label as an output and the rest target it via
# `runs-on: ${{ fromJSON(needs.<job>.outputs.runs_on) }}`, pinning one run to one
# replica while still letting different runs use the whole fleet. Workflows whose
# jobs are independent should keep using the shared label and ignore this.
set -euo pipefail

_replica_id="$(hostname)"

if [[ -n "${RUNNER_WORKDIR:-}" ]]; then
  _replica_workdir="${RUNNER_WORKDIR%/}/${_replica_id}"
  export RUNNER_WORKDIR="${_replica_workdir}"
  mkdir -p "${RUNNER_WORKDIR}"
fi

# entrypoint.sh prefers RUNNER_LABELS and falls back to the legacy LABELS, so
# base the append on whichever is actually in play -- writing RUNNER_LABELS
# unconditionally would silently discard a LABELS-only configuration.
_base_labels="${RUNNER_LABELS:-${LABELS:-}}"
if [[ -n "${_base_labels}" ]]; then
  export RUNNER_LABELS="${_base_labels},replica-${_replica_id}"
else
  export RUNNER_LABELS="replica-${_replica_id}"
fi

# Hand off to the real entrypoint by naming the interpreter explicitly
# (rather than `exec /entrypoint.sh`) so its own dumb-init shebang doesn't
# spawn a second, nested dumb-init layer.
exec /bin/bash /entrypoint.sh "$@"
