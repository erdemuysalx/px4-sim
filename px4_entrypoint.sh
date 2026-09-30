#!/bin/bash
set -e

# Source ROS 2 environment
source /opt/ros/jazzy/setup.bash

# Run supervisord (vncserver, noVNC, ros-bridges) as PID 1; open shells with `docker exec -it px4-sim bash`
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
