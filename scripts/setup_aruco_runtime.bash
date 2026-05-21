#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script is meant to be sourced:" >&2
  echo "  source scripts/setup_aruco_runtime.bash" >&2
  exit 1
fi

PX4_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAZEBO_WS="/home/zz/catkin_ws"
ARUCO_WS="/home/zz/ros_gazebo_px4_sim_ws-master"
XTDRONE_MODELS="/home/zz/XTDrone/sitl_config/models"
TMP_HOME="/tmp/px4_aruco_home"

mkdir -p "${TMP_HOME}/.ros" "${TMP_HOME}/.gazebo"

export HOME="${TMP_HOME}"
export ROS_HOME="${TMP_HOME}/.ros"

source /opt/ros/noetic/setup.bash
source "${GAZEBO_WS}/devel/setup.bash"
source "${ARUCO_WS}/devel/setup.bash"
source "${PX4_DIR}/Tools/setup_gazebo.bash" "${PX4_DIR}" "${PX4_DIR}/build/px4_sitl_default"

export ROS_PACKAGE_PATH="${PX4_DIR}:${PX4_DIR}/Tools/sitl_gazebo:${ROS_PACKAGE_PATH}"

MAXI_PKG_DIR="$(rospack find maxi_aruco_det_pkg 2>/dev/null || true)"
if [[ -n "${MAXI_PKG_DIR}" ]]; then
  export GAZEBO_MODEL_PATH="${GAZEBO_MODEL_PATH}:${MAXI_PKG_DIR}/models:${MAXI_PKG_DIR}/models_for_worlds"
fi

if [[ -d "${XTDRONE_MODELS}" ]]; then
  export GAZEBO_MODEL_PATH="${GAZEBO_MODEL_PATH}:${XTDRONE_MODELS}"
fi

# Gazebo looks at HOME for logs; the temp HOME above keeps sandbox writes local.
export GAZEBO_MASTER_URI="${GAZEBO_MASTER_URI:-http://127.0.0.1:11345}"
