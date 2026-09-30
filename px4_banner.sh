#!/bin/bash
# Usage banner printed by /root/.bashrc for interactive shells.

echo ""
cat << 'EOF'
████████    ██      ██  ██    ██              ████████  ██████  ██      ██
██      ██    ██  ██    ██    ██            ██            ██    ████  ████
████████        ██      ████████  ████████    ██████      ██    ██  ██  ██
██            ██  ██          ██                    ██    ██    ██      ██
██          ██      ██        ██            ████████    ██████  ██      ██
EOF
echo ""
echo "==============================================================="
echo "  ROS 2 Jazzy + Gazebo Harmonic + PX4 + Mavros + NoVNC"
echo "==============================================================="
echo "  PX4 GCS link listens on UDP 18570 inside the container"
echo "  QGroundControl: add a UDP link to server 127.0.0.1:18570"
echo ""
echo "  VNC Access: http://localhost:6080/vnc.html"
echo "  VNC Password: 1234"
echo ""
echo "  Start PX4 SITL (camera topics in config/bridge.yaml need gz_x500_depth):"
echo "    cd /root/PX4-Autopilot"
echo "    make px4_sitl gz_x500_depth"
echo ""
echo "  Different vehicle models to start:"
echo "    - x500 Quadrotor: make px4_sitl gz_x500"
echo "    - X500 Quadrotor with Depth Camera (Front-facing): make px4_sitl gz_x500_depth"
echo "    - X500 Quadrotor with Vision Odometry: make px4_sitl gz_x500_vision"
echo "    - X500 Quadrotor with 1D LIDAR (Down-facing): make px4_sitl gz_x500_lidar_down"
echo "    - X500 Quadrotor with 2D LIDAR: make px4_sitl gz_x500_lidar_2d"
echo "    - X500 Quadrotor with 1D LIDAR (Front-facing): make px4_sitl gz_x500_lidar_front"
echo "    - X500 Quadrotor with gimbal (Front-facing) in Gazebo: make px4_sitl gz_x500_gimbal"
echo ""
echo "  MAVROS + ROS Gazebo Bridge (started automatically):"
echo "    supervisorctl status ros-bridges"
echo "    supervisorctl restart ros-bridges   # after editing config/bridge.yaml"
echo "    Topic mapping: /opt/px4-sim/config/bridge.yaml (mounted from ./config)"
echo "==============================================================="
