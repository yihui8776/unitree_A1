#from yihui8776/unitree:v0.1
FROM floodshao/ros-melodic-desktop-vnc:v1.0
# Install ROS dependencies
#
# undocumented dependencies:
# ros-melodic-robot-state-publisher
# ros-melodic-robot
# ros-melodic-joint-state-publisher-gui
# ros-melodic-rviz
USER root

#RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'

RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
		ros-melodic-desktop-full \
		ros-melodic-controller-interface ros-melodic-gazebo-ros-control \
		ros-melodic-joint-state-controller ros-melodic-effort-controllers \
		ros-melodic-joint-trajectory-controller ros-melodic-robot \
		ros-melodic-robot-state-publisher ros-melodic-joint-state-publisher-gui \
		ros-melodic-rviz \
	&& rm -rf /var/lib/apt/lists/*

# Install other dependencies
RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
		curl unzip git \
	&& rm -rf /var/lib/apt/lists/*

# Install LCM
RUN curl -L https://github.com/lcm-proj/lcm/releases/download/v1.4.0/lcm-1.4.0.zip > lcm-1.4.0.zip \
	&& unzip lcm-1.4.0.zip \
	&& cd lcm-1.4.0 \
	&& mkdir build \
	&& cd build \
	&& cmake ../ \
	&& make \
	&& make install \
	&& cd ../../ \
	&& rm -rf lcm-1.4.0 \
	&& rm lcm-1.4.0.zip \
    &&  cp /usr/local/lib/liblcm.so.1 /usr/lib/

# Build unitree_legged_sdk
#WORKDIR /headless
#RUN git clone https://github.com/unitreerobotics/unitree_legged_sdk.git \
COPY unitree_legged_sdk-3.2.zip  /headless/unitree_legged_sdk.zip

RUN  unzip unitree_legged_sdk.zip  \
    && mv unitree_legged_sdk-3.2 unitree_legged_sdk \
	&& cd unitree_legged_sdk \
	&& mkdir build \
	&& cd build \
	&& cmake ../ \
	&& make

# Setup stage 1 entrypoint
RUN echo "#!/bin/bash" > unitree_entrypoint.bash \
	&& echo "set -e\n" >> unitree_entrypoint.bash \
	&& echo "source /opt/ros/melodic/setup.bash" >> unitree_entrypoint.bash \
	&& echo "source /usr/share/gazebo-9/setup.sh" >> unitree_entrypoint.bash \
	&& echo "export ROS_PACKAGE_PATH=/root/catkin_ws:\${ROS_PACKAGE_PATH}" >> unitree_entrypoint.bash \
	&& echo "export GAZEBO_PLUGIN_PATH=/root/catkin_ws/devel/lib:\${GAZEBO_PLUGIN_PATH}" >> unitree_entrypoint.bash \
	&& echo "export LD_LIBRARY_PATH=/root/catkin_ws/devel/lib:/usr/local/lib:/headless/unitree_legged_sdk/include:/headless/unitree_legged_sdk/lib:\${LD_LIBRARY_PATH}" >> unitree_entrypoint.bash \
	&& echo "export UNITREE_SDK_VERSION=3_2" >> unitree_entrypoint.bash \
	&& echo "export UNITREE_LEGGED_SDK_PATH=/headless/unitree_legged_sdk" >> unitree_entrypoint.bash \
	&& echo "export ROS_IP='127.0.0.1'" >> unitree_entrypoint.bash \
	&& case $(uname -m) in \
			x86_64) arch=amd64 ;; \
			aarch64) arch=arm64 ;; \
			arm) arch=arm32 ;; \
			armv7l) arch=arm32 ;; \
		esac \
	&& echo "export UNITREE_PLATFORM='${arch}'" >> unitree_entrypoint.bash \
	&& echo "\nexec \$@" >> unitree_entrypoint.bash \
	&& chmod +x unitree_entrypoint.bash

# Setup workspace and unitree_ros
RUN mkdir -p /root/catkin_ws/src/ \
	&& cd /root/catkin_ws/src/ \
	#&& git clone https://github.com/unitreerobotics/unitree_ros.git \
	&& git clone -b master  https://github.com/yihui8776/unitree_A1.git unitree_ros\
	&& cd unitree_ros \
	&& sed -i "s|/home/[^/]\+/|/root/catkin_ws/|g" unitree_gazebo/worlds/stairs.world \
    #&& /bin/bash -c 'source $HOME/unitree_entrypoint.bash' \
	&& cd /root/catkin_ws \
	#&& catkin_make
#	&& catkin_make
	&& /bin/bash -c 'source  /headless/unitree_entrypoint.bash'  catkin_make

# Setup stage 2 entrypoint
RUN echo "#!/bin/bash" >> /entry2.bash \
	&& echo "source /root/catkin_ws/devel/setup.bash" >> /entry2.bash \
	&& echo "exec \$@" >> /entry2.bash \
	&& chmod +x /entry2.bash

# Setup joint entrypoint
RUN echo "#!/bin/bash" >> /dockerstartup/entrypoint.bash \
	&& echo "exec /dockerstartup/vnc_startup.sh /headless/unitree_entrypoint.bash /entry2.bash \$@" >> /dockerstartup/entrypoint.bash \
	&& chmod +x /dockerstartup/entrypoint.bash

WORKDIR "/root/catkin_ws"

ENTRYPOINT ["/dockerstartup/entrypoint.bash"]

#WORKDIR "/root/catkin_ws"

#CMD ["bash"]
#ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]
