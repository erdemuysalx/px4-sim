# PX4 Autopilot with TigerVNC and NoVNC
ARG BASE_IMAGE=erdemuysalx/ros2-jazzy-gazebo-harmonic:latest
FROM ${BASE_IMAGE}

# Metadata
LABEL description="ROS 2 Jazzy with Gazebo Harmonic, PX4 Autopilot, MAVROS, and NoVNC"
LABEL version="1.0"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# PX4 git tag to build; changing it changes the autopilot every result is produced with
ARG PX4_VERSION=v1.17.0

# ============================================================================
# Install PX4 Autopilot dependencies (mirrors Tools/setup/ubuntu.sh for 24.04)
# ============================================================================
# Python packages from apt satisfy PX4's requirements.txt, so pip does not
# shadow the numpy/matplotlib builds that ROS 2 is linked against.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    make \
    ninja-build \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-jinja2 \
    python3-empy \
    python3-toml \
    python3-numpy \
    python3-yaml \
    python3-packaging \
    python3-matplotlib \
    python3-pandas \
    python3-sympy \
    python3-psutil \
    python3-serial \
    python3-requests \
    python3-lxml \
    python3-jsonschema \
    astyle \
    exiftool \
    genromfs \
    kconfig-frontends \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libeigen3-dev \
    libopencv-dev \
    libunwind-dev \
    cppzmq-dev \
    libxml2-utils \
    pkg-config \
    protobuf-compiler \
    geographiclib-tools \
    rsync \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Install MAVROS
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-jazzy-mavros \
    && rm -rf /var/lib/apt/lists/*

# GeographicLib datasets required by MAVROS (same set as mavros' install_geographiclib_datasets.sh)
RUN geographiclib-get-geoids egm96-5 \
    && geographiclib-get-gravity egm96 \
    && geographiclib-get-magnetic emm2015

# ============================================================================
# Install TigerVNC and NoVNC
# ============================================================================
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-terminal \
    dbus-x11 \
    supervisor \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

# Setup VNC
RUN mkdir -p /root/.vnc \
    && echo "1234" | vncpasswd -f > /root/.vnc/passwd \
    && chmod 600 /root/.vnc/passwd

# Create VNC xstartup script
RUN echo '#!/bin/sh\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
exec startxfce4' > /root/.vnc/xstartup \
    && chmod +x /root/.vnc/xstartup

# ============================================================================
# Setup environment and directories
# ============================================================================
ENV DISPLAY=:1
RUN mkdir -p /var/log/supervisor /root/ros2_ws/src

# ============================================================================
# Clone and build PX4 Autopilot
# ============================================================================
WORKDIR /root
RUN git clone --branch ${PX4_VERSION} --depth 1 --recursive --shallow-submodules \
    https://github.com/PX4/PX4-Autopilot.git

RUN pip3 install --no-cache-dir --break-system-packages \
    -r /root/PX4-Autopilot/Tools/setup/requirements.txt

# Build-only target (px4 + Gazebo plugins); gz_<model> targets always launch PX4 and would hang the build.
# One px4_sitl build serves every gz_* vehicle; the model is only chosen at startup.
WORKDIR /root/PX4-Autopilot
RUN make px4_sitl
WORKDIR /root

# ============================================================================
# VirtualGL: GPU rendering for Gazebo inside the VNC desktop (NVIDIA hosts)
# ============================================================================
# Installed after the PX4 build so it does not invalidate the PX4 build layer
ARG VIRTUALGL_VERSION=3.1.5
RUN curl -fsSL -o /tmp/virtualgl.deb \
    "https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_$(dpkg --print-architecture).deb" \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/virtualgl.deb \
    && rm -rf /tmp/virtualgl.deb /var/lib/apt/lists/*

# ============================================================================
# Setup environment variables and shell banner
# ============================================================================
ENV PX4_DIR=/root/PX4-Autopilot
ENV GZ_SIM_RESOURCE_PATH=/root/PX4-Autopilot/Tools/simulation/gz/models

COPY ./px4_banner.sh /usr/local/bin/px4_banner.sh
RUN echo '[ -t 1 ] && /usr/local/bin/px4_banner.sh' >> /root/.bashrc

# ============================================================================
# Supervisord services (VNC, noVNC, MAVROS + ros_gz_bridge)
# ============================================================================
# Copied after the PX4 build so editing them does not invalidate the PX4 build layer
ENV ROS_BRIDGES_AUTOSTART=true
COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./launch/bridges.launch.py /opt/px4-sim/launch/bridges.launch.py
COPY ./config/bridge.yaml /opt/px4-sim/config/bridge.yaml

# ============================================================================
# Expose ports
# ============================================================================
EXPOSE 5901
EXPOSE 6080
EXPOSE 18570/udp

# Setup entrypoint
COPY ./px4_entrypoint.sh /
ENTRYPOINT ["/px4_entrypoint.sh"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1
