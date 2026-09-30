#!/bin/bash
# Adds OCI labels with the exact ROS 2, Gazebo and PX4 versions found inside the built images.
# Usage: add_version_labels.sh <base-image> <px4-image>
# Single-quoted query strings are expanded inside the container, not on the host.
# shellcheck disable=SC2016
set -euo pipefail

base_image="$1"
px4_image="$2"
source_url="https://github.com/erdemuysalx/px4-sim"
prefix="io.github.erdemuysalx.px4-sim"

query() {
    docker run --rm --entrypoint bash "$1" -c "$2"
}

# Relabels an image in place; LABEL only changes image metadata, not its layers
relabel() {
    local image="$1"
    shift
    printf 'FROM %s\n' "${image}" | docker build --quiet "$@" --tag "${image}" - > /dev/null
}

ubuntu_version=$(query "${base_image}" '. /etc/os-release && echo "${VERSION_ID}"')
ros_distro=$(query "${base_image}" 'echo "${ROS_DISTRO}"')
ros_version=$(query "${base_image}" 'dpkg-query -W -f="\${Version}" "ros-${ROS_DISTRO}-desktop"')
gz_sim_version=$(query "${base_image}" 'gz sim --versions | head -n 1 | tr -d " "')
px4_version=$(query "${px4_image}" 'git -C /root/PX4-Autopilot describe --tags')
mavros_version=$(query "${px4_image}" 'dpkg-query -W -f="\${Version}" "ros-${ROS_DISTRO}-mavros"')

echo "ubuntu=${ubuntu_version} ros=${ros_distro} ${ros_version} gz-sim=${gz_sim_version}"
echo "px4=${px4_version} mavros=${mavros_version}"

common=(
    --label "org.opencontainers.image.source=${source_url}"
    --label "${prefix}.ubuntu=${ubuntu_version}"
    --label "${prefix}.ros-distro=${ros_distro}"
    --label "${prefix}.ros-desktop=${ros_version}"
    --label "${prefix}.gz-sim=${gz_sim_version}"
)

relabel "${base_image}" "${common[@]}"
relabel "${px4_image}" "${common[@]}" \
    --label "${prefix}.px4=${px4_version}" \
    --label "${prefix}.mavros=${mavros_version}"
