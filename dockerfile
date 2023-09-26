FROM ubuntu:23.04
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends file git cmake ninja-build pkg-config clang clang-format build-essential curl ccache git zsh
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libxdamage-dev libspeexdsp-dev libva-dev libasio-dev libwebsocketpp-dev libqrcodegencpp1 libqrcodegencpp-dev nlohmann-json3-dev libasound2-dev libv4l-dev libvlc-dev libpulse-dev libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev libavutil-dev libswresample-dev libswscale-dev libx264-dev libcurl4-openssl-dev libmbedtls-dev libgl1-mesa-dev libjansson-dev libluajit-5.1-dev python3-dev libx11-dev libxcb-randr0-dev libxcb-shm0-dev libxcb-xinerama0-dev libxcb-composite0-dev libxcomposite-dev libxinerama-dev libxcb1-dev libx11-xcb-dev libxcb-xfixes0-dev swig libcmocka-dev libxss-dev libglvnd-dev libgles2-mesa libgles2-mesa-dev libwayland-dev librist-dev libsrt-openssl-dev libpci-dev libpipewire-0.3-dev libqrcodegencpp-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libatk-bridge2.0-0 libatspi2.0-dev libnss3 qtbase5-dev qtbase5-private-dev libqt5svg5-dev qtwayland5
COPY . .
RUN cmake -S . -B ./build -G Ninja \
	-DCMAKE_BUILD_TYPE=Debug \
	-DOBS_VERSION_OVERRIDE="29.1.3"\
	-DCEF_ROOT_DIR="./plugins/cef" \
	-DENABLE_PIPEWIRE=OFF \
	-DENABLE_BROWSER=ON \
	-DENABLE_AJA=0 \
        -DENABLE_WEBRTC=0 \
	-DQT_VERSION=6 
RUN cmake --build ./build
RUN cmake --build ./build --target package
RUN apt install -y  --allow-change-held-packages ./build/Capturehelper-29.1.3-1-Linux.deb
