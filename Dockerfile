FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ARG RAVE_COMMIT=ec22ecfaf006688cbc5ee0fdd8fa05d2c5676d37
ARG OSG_COMMIT=1f89e6eb1087add6cd9c743ab07a5bce53b2f480
ENV QT_X11_NO_MITSHM=1
ENV OPENRAVE_PLUGINS=/usr/local/lib/openrave0.149-plugins
ENV LC_ALL=C.UTF-8
ENV PYTHONPATH=/usr/local/lib/python3/dist-packages:${PYTHONPATH}

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Enable universe and multiverse repos (ubuntu:22.04 only has main by default)
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y universe && \
    add-apt-repository -y multiverse && \
    apt-get update

# System dependencies - Python 3.10 (system default on 22.04)
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    build-essential \
    git \
    cmake \
    python3 \
    python3-dev \
    python3-pip \
    coreutils \
    nano \
    vim \
    tmux \
    ipython3 \
    minizip \
    wget

# C++ build dependencies
RUN apt-get install -q -y --no-install-recommends \
    libassimp-dev \
    libavcodec-dev \
    libavformat-dev \
    libboost-all-dev \
    libboost-date-time-dev \
    libboost-python-dev \
    libbullet-dev \
    libglew-dev \
    libgsm1-dev \
    liblapack-dev \
    liblog4cxx-dev \
    libmpfr-dev \
    libode-dev \
    libogg-dev \
    libpcrecpp0v5 \
    libpcre3-dev \
    libqhull-dev \
    libswscale-dev \
    libvorbis-dev \
    libx264-dev \
    libxml2-dev \
    libxvidcore-dev \
    libbz2-dev \
    libtinyxml-dev \
    libmpfi-dev \
    libfreetype6-dev \
    libflann-dev \
    libeigen3-dev \
    libann-dev \
    ann-tools \
    libccd-dev \
    octomap-tools \
    libminizip-dev \
    libcollada-dom2.4-dp-dev \
    liblapacke-dev \
    libgsl-dev \
    libcairo2-dev \
    libpoppler-glib-dev \
    libsdl2-dev \
    libtiff5-dev \
    libxrandr-dev \
    libyaml-cpp-dev \
    pybind11-dev \
    rapidjson-dev \
    qtbase5-dev \
    libqt5opengl5-dev

# Install collada-dom
RUN mkdir -p ~/git; cd ~/git && \
    git clone https://github.com/rdiankov/collada-dom.git && \
    cd collada-dom && mkdir build && cd build && \
    cmake .. && \
    make -j $(nproc) && \
    make install

# Install OpenSceneGraph
RUN mkdir -p ~/git; cd ~/git && \
    git clone https://github.com/openscenegraph/OpenSceneGraph.git && \
    cd OpenSceneGraph && git reset --hard ${OSG_COMMIT} && \
    mkdir build && cd build && \
    cmake -DDESIRED_QT_VERSION=5 .. && \
    make -j $(nproc) && make install && make install_ld_conf

# Install FCL 0.5.0
RUN mkdir -p ~/git; cd ~/git && \
    git clone https://github.com/flexible-collision-library/fcl && \
    cd fcl && git reset --hard 0.5.0 && \
    mkdir build && cd build && \
    cmake .. && \
    make -j $(nproc) && \
    make install

# Install newer RapidJSON (system 1.1.0 lacks copyConstStrings needed by OpenRAVE master)
RUN mkdir -p ~/git; cd ~/git && \
    git clone https://github.com/Tencent/rapidjson.git && \
    cd rapidjson && mkdir build && cd build && \
    cmake -DRAPIDJSON_BUILD_DOC=OFF -DRAPIDJSON_BUILD_EXAMPLES=OFF -DRAPIDJSON_BUILD_TESTS=OFF .. && \
    make install

# Install OpenRAVE with Python 3.10 pybind11 bindings
RUN pip3 install --upgrade pip setuptools wheel && \
    pip3 install sympy "numpy<2" "pybind11>=2.9.2,<3"
RUN mkdir -p ~/git; cd ~/git && \
    git clone https://github.com/rdiankov/openrave.git && \
    cd openrave && git reset --hard ${RAVE_COMMIT} && \
    mkdir build && cd build && \
    cmake -DODE_USE_MULTITHREAD=ON \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_CXX_FLAGS="-Wno-error=narrowing -fpermissive" \
          -DOPT_PYTHON=OFF \
          -DOPT_PYTHON3=ON \
          -DOPT_FCL_COLLISION=OFF \
          -DOPT_MSGPACK=OFF \
          -DOPT_ENCRYPTION=OFF \
          -DBoost_NO_BOOST_CMAKE=TRUE \
          -DBoost_NO_SYSTEM_PATHS=FALSE \
          -DOSG_DIR=/usr/local \
          -DCMAKE_LIBRARY_PATH=/usr/local/lib64 \
          -Dpybind11_DIR=$(python3 -m pybind11 --cmakedir) .. && \
    make -j $(nproc) && \
    make install

# Configure locale and shared library cache
RUN apt-get update && apt-get install -y --no-install-recommends locales && \
    locale-gen en_US.UTF-8 && \
    echo "/usr/local/lib64" > /etc/ld.so.conf.d/local-lib64.conf && \
    ldconfig

# installing trac_ik with python bindings
RUN apt update && apt install -y -q --no-install-recommends \
    ibboost-all-dev \
    libeigen3-dev \
    liborocos-kdl-dev \
    libnlopt-dev \
    libnlopt-cxx-dev

RUN pip3 install pytracik

# Install Python dependencies
WORKDIR /workspaces/
COPY requirements.txt .
RUN pip3 install -r /workspaces/requirements.txt
RUN rm -rf /workspaces/requirements.txt

# Verify openravepy loads correctly
# X11, OpenGL, and Qt5 XCB runtime support for OpenRAVE viewer
RUN apt-get update && apt-get install -y \
    xauth xorg openbox htop openssh-client \
    libxcb-xinerama0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
    libxcb-render-util0 libxcb-xinput0 libxcb-xkb1 libxcb-cursor0 \
    libxkbcommon-x11-0 \
    libgl1-mesa-dri libgl1-mesa-glx libegl-mesa0 libgbm1 \
    dbus-x11 libdbus-1-3
# DBus machine-id needed by Qt5
RUN dbus-uuidgen > /etc/machine-id 2>/dev/null || true
