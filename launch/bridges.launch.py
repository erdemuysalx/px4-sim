"""Launch MAVROS and the ROS-Gazebo bridge for a manually started PX4 SITL."""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare
from launch_xml.launch_description_sources import XMLLaunchDescriptionSource


def generate_launch_description() -> LaunchDescription:
    """Build the launch description for MAVROS and ros_gz_bridge."""
    fcu_url = LaunchConfiguration("fcu_url")
    bridge_config = LaunchConfiguration("bridge_config")

    mavros = IncludeLaunchDescription(
        XMLLaunchDescriptionSource(
            PathJoinSubstitution([FindPackageShare("mavros"), "launch", "px4.launch"])
        ),
        launch_arguments={"fcu_url": fcu_url}.items(),
    )

    gz_bridge = Node(
        package="ros_gz_bridge",
        executable="parameter_bridge",
        name="ros_gz_bridge",
        parameters=[{"config_file": bridge_config}],
        output="screen",
    )

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "fcu_url",
                default_value="udp://:14540@localhost:14557",
                description="MAVROS connection to PX4's offboard MAVLink link.",
            ),
            DeclareLaunchArgument(
                "bridge_config",
                default_value="/opt/px4-sim/config/bridge.yaml",
                description="ros_gz_bridge YAML topic mapping.",
            ),
            mavros,
            gz_bridge,
        ]
    )
