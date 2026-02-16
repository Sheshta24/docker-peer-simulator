#!/usr/bin/env bash
set -euo pipefail

# Official ref: Tailscale Docker env vars used below:
# https://tailscale.com/kb/1282/docker

AUTHKEY="${TS_AUTHKEY:?Set TS_AUTHKEY in your shell first}"
START="${1:-1}"
COUNT="${2:-10}"
PREFIX="${3:-peer}"
TAGS="${TS_TAGS:-}"
RECREATE_EXISTING="${RECREATE_EXISTING:-false}"

START_NUM=$((10#${START}))
COUNT_NUM=$((10#${COUNT}))
END_NUM=$((START_NUM + COUNT_NUM - 1))
PAD_WIDTH="${#END_NUM}"

if [ -n "${TS_EXTRA_ARGS:-}" ]; then
  EXTRA_ARGS="${TS_EXTRA_ARGS}"
elif [ -n "${TAGS}" ]; then
  EXTRA_ARGS="--advertise-tags=${TAGS} --reset"
else
  EXTRA_ARGS="--reset"
fi

echo "Using TS_EXTRA_ARGS: ${EXTRA_ARGS}"
echo "RECREATE_EXISTING=${RECREATE_EXISTING}"

for i in $(seq "${START_NUM}" "${END_NUM}"); do
  idx="$(printf "%0${PAD_WIDTH}d" "${i}")"
  name="${PREFIX}-${idx}"
  volume="${name}-state"

  if docker ps -a --format '{{.Names}}' | grep -Fxq "${name}"; then
    if [ "${RECREATE_EXISTING}" = "true" ]; then
      echo "Recreating ${name}"
      docker rm -f "${name}" >/dev/null
    else
      echo "Skipping ${name} (container already exists)"
      continue
    fi
  fi

  echo "Starting ${name} (volume: ${volume})"

  docker volume create "${volume}" >/dev/null

  docker run -d --name "${name}" \
    -e TS_AUTHKEY="${AUTHKEY}" \
    -e TS_HOSTNAME="${name}" \
    -e TS_STATE_DIR=/var/lib/tailscale \
    -e TS_EXTRA_ARGS="${EXTRA_ARGS}" \
    -e TS_USERSPACE=false \
    -v "${volume}:/var/lib/tailscale" \
    --device /dev/net/tun:/dev/net/tun \
    --cap-add NET_ADMIN \
    --restart unless-stopped \
    tailscale/tailscale:latest >/dev/null
done

echo "Done. Check: docker ps | grep ${PREFIX}-"
