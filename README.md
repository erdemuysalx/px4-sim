# PX4-Sim

Fully containerized PX4 Autopilot simulation environment with browser-based GUI access.

## What's Included

- **PX4 Autopilot** (`v1.17.0`) - SITL pre-built in the image; `make px4_sitl gz_<vehicle>` starts right away for every Gazebo vehicle
- **ROS 2 Jazzy** - ROS 2 LTS release
- **Gazebo Harmonic** - Gazebo LTS release
- **ROS Gazebo Bridge** (`ros-jazzy-ros-gz-bridge`) - Bidirectional transport bridge between Gazebo and ROS
- **MAVROS** (`ros-jazzy-mavros`) - PX4 to ROS 2 gateway
- **TigerVNC + NoVNC** - Browser-based desktop access
- **XFCE4 Desktop** - Full desktop environment

## Quick Start

### 1. Build the Images

```bash
# Build everything
./build.sh --all

# Or build step by step
./build.sh --base  # ROS 2 + Gazebo
./build.sh --full  # PX4 Autopilot + MAVROS + NoVNC
```

The PX4 version is pinned by the `PX4_VERSION` build arg in `px4.Dockerfile`. To build another tag, run `docker build -f px4.Dockerfile --build-arg PX4_VERSION=<tag> -t erdemuysalx/px4-sim:<tag> .`
The base image can be swapped with `--build-arg BASE_IMAGE=<image:tag>`.

### 2. Run the Container

```bash
docker-compose up -d
docker exec -it px4-sim bash
```

The container's main process is supervisord, which runs VNC, noVNC, and the MAVROS + ROS-Gazebo bridge (`ros-bridges`); every shell is opened with `docker exec`. Check or restart them with `supervisorctl status` and `supervisorctl restart <name>`. Ports are published on `127.0.0.1` only.

#### What persists

| Path in container | Stored in | Survives `docker-compose down` |
|---|---|---|
| `/root/ros2_ws` | `./ros2_ws` on the host (override with `ROS2_WS=/path/to/ws`) | Yes |
| Everything else, including the PX4 build | Container (PX4 is restored pre-built from the image) | No |

#### Resources

`docker-compose.yml` sets `shm_size: 2gb` for ROS 2 shared-memory transport and Gazebo; lower it on machines with little RAM. On macOS and Windows, the container can only use the memory assigned to Docker Desktop (Settings > Resources), so raise that if Gazebo or `colcon build` run out of memory.

### 3. Access the GUI

You can access GUI applications in different ways depending on your operating system:

#### macOS

You can access the GUI via built-in **noVNC** using your browser:

- Open: http://localhost:6080/vnc.html
- Password: `1234`

#### Linux

You can use **X11 forwarding** by enabling the commented lines in `docker-compose.yml`:

```yaml
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix:rw

    environment:
      - DISPLAY=${DISPLAY}
```

Then allow the container to connect to your X server and recreate it:

```bash
xhost +local:
docker-compose up -d --force-recreate
```

noVNC keeps working alongside X11 forwarding.

#### Remote host

The ports are bound to `127.0.0.1`, so when the container runs on another machine, tunnel noVNC over SSH and open http://localhost:6080/vnc.html locally:

```bash
ssh -L 6080:localhost:6080 user@remote-host
```

Gazebo renders in software inside the VNC desktop. To run the simulation without the Gazebo window, start PX4 with `HEADLESS=1 make px4_sitl gz_x500`.

### 4. Control Interface

You can control your vehicle in simulation using different ways:

#### Connect QGroundControl (optional)

This step is required only if you want to control the vehicle using a graphical user interface.

1. Install **QGroundControl** on your host machine:
   http://qgroundcontrol.com

2. Create a custom communication link (Application Settings > Comm Links > Add):

   * Type: UDP
   * Port: `15871` (any free local port)
   * Server Address: `127.0.0.1:18570` (Don't use `0.0.0.0`: the container port is published on `127.0.0.1` only, and macOS cannot send to `0.0.0.0`.)

3. Start PX4 first, then select the link under Comm Links and click **Connect** (or enable "Automatically Connect on Start").

PX4 locks its GCS link to the first client that sends to it and ignores every other client until PX4 restarts. If QGroundControl does not connect, stop PX4 (`shutdown` in the `pxh>` console) and start it again before connecting.

#### Offboard mode (alternative)

Alternatively, you can control the vehicle in **offboard mode**. This mode bypasses certain PX4 safety constraints in **PX4 Autopilot** when running in SITL.

Run the following commands in the PX4 SITL console:

```bash
param set COM_ARM_WO_GPS 1
param set COM_RC_IN_MODE 4
param set NAV_DLL_ACT 0
param set NAV_RCL_ACT 0
param set COM_OBL_ACT 0
```

### 5. Run the Simulation

MAVROS and the ROS-Gazebo bridge start automatically with the container and wait for PX4 and Gazebo. You only start PX4, which keeps its interactive `pxh>` console:

```bash
docker exec -it px4-sim bash
cd /root/PX4-Autopilot
make px4_sitl gz_x500_depth
```

You will see:
- Gazebo simulation with a quadcopter
- PX4 console showing startup messages
- MAVROS connecting (`ros2 topic echo /mavros/state` shows `connected: true`)
- Camera topics under `/camera/...` (`ros2 topic list`)

#### MAVROS and ROS-Gazebo bridge

Both run as the supervisord program `ros-bridges` (`launch/bridges.launch.py`):

- **MAVROS** connects to PX4's offboard link with `fcu_url:=udp://:14540@localhost:14557`.
- **ros_gz_bridge** maps Gazebo topics to ROS topics as listed in [`config/bridge.yaml`](config/bridge.yaml). The default mapping is the `x500_depth` camera. `config/` is mounted into the container, so to bridge other sensors, edit the file and restart the bridge; no rebuild needed.

```bash
supervisorctl status ros-bridges     # running?
supervisorctl restart ros-bridges    # after editing config/bridge.yaml
docker-compose logs -f               # MAVROS and bridge output (on the host)
```

To start them manually instead, set `ROS_BRIDGES_AUTOSTART=false` in `docker-compose.yml`, recreate the container, and run:

```bash
ros2 launch /opt/px4-sim/launch/bridges.launch.py
```

### 6. Your ROS 2 Workspace

`/root/ros2_ws` is a ROS 2 (colcon) workspace for your own packages, such as navigation or computer vision nodes. It is bind-mounted from `./ros2_ws` on the host, so you can edit code with your host IDE and it survives container removal. To use another host directory:

```bash
ROS2_WS=/path/to/my_ws docker-compose up -d
```

Put packages in `src/`, then build and source them inside the container:

```bash
docker exec -it px4-sim bash
cd /root/ros2_ws
colcon build
source install/setup.bash
```

The container runs as root, so on Linux hosts the `build/`, `install/` and `log/` directories that `colcon build` creates are owned by root on the host.

## Usage Examples

### Start/Stop

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# View logs
docker-compose logs -f
```

### Multiple Terminal Windows

```bash
# Start container
docker-compose up -d

# Terminal 1: Run PX4 (MAVROS and the bridge are already running)
docker exec -it px4-sim bash
cd /root/PX4-Autopilot
make px4_sitl gz_x500_depth

# Terminal 2: Monitor ROS topics
docker exec -it px4-sim bash
ros2 topic list
ros2 topic echo /mavros/altitude

# Terminal 3: Build custom packages
docker exec -it px4-sim bash
cd /root/ros2_ws
colcon build
```

### Try Different Vehicles

See full list of vehicles [here](https://docs.px4.io/main/en/sim_gazebo_gz/vehicles).

```bash
# X500 Quadcopter
make px4_sitl gz_x500

# RC Cessna
make px4_sitl gz_rc_cessna

# Ackermann Rover
make px4_sitl gz_rover_ackermann
```

## Network Ports

| Port | Service |
|------|---------|
| 5901 | VNC server |
| 6080 | NoVNC web interface |
| 18570/udp | PX4 GCS MAVLink link (QGroundControl sends here first; PX4 replies to the sender) |

## Acknowledgement

- [PX4 Autopilot Documentation](https://docs.px4.io/)
- [ROS 2 Jazzy Documentation](https://docs.ros.org/en/jazzy/)
- [Gazebo Harmonic Documentation](https://gazebosim.org/docs/harmonic/)
- [ROS Gazebo Bridge](https://github.com/gazebosim/ros_gz/tree/ros2/ros_gz_bridge)
- [MAVROS](https://github.com/mavlink/mavros)
- [QGroundControl](http://qgroundcontrol.com)
- [TigerVNC Documentation](https://tigervnc.org/)


**Happy Simulating!** 🚁