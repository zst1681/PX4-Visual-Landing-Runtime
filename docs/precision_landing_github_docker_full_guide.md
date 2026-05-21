# PX4 ArUco 视觉精准降落：GitHub 上传、新设备部署与 Docker 迁移完整教程

这份文档按当前项目实际情况整理，适合第一次使用 GitHub 的流程。本文档重点解决：

- 第一次把项目上传到自己的 GitHub，具体每一步怎么做。
- 新设备使用 `git clone https://...` 克隆，不依赖你的个人 SSH 密钥。
- 只上传单码/嵌套码、有 PID/无 PID 视觉降落必需文件，不上传测试脚本和实验结果。
- 避免项目过大导致上传中断。
- 给出新设备原生环境安装命令。
- 给出 Docker 容器迁移方案。
- 给出完整启动命令，包括 `roslaunch px4 aruco_search_and_land_weighted_demo.launch gui:=true`。
- 记录本机 weighted demo 启动失败的恢复办法。

## 0. 先恢复和验证当前本机项目

我已经把 `scripts/setup_aruco_runtime.bash` 恢复为你原来的本机路径设置：

```bash
PX4_DIR=/home/zz/PX4_Firmware
GAZEBO_WS=/home/zz/catkin_ws
ARUCO_WS=/home/zz/ros_gazebo_px4_sim_ws-master
XTDRONE_MODELS=/home/zz/XTDrone/sitl_config/models
```

启动前先清理残留进程，尤其是上一次失败后留下的 `gzserver`、`gzclient`、`rosmaster`、`px4`：

```bash
cd /home/zz/PX4_Firmware
scripts/cleanup_aruco_runtime.sh
```

然后启动 weighted 嵌套码 PID 降落：

```bash
cd /home/zz/PX4_Firmware
source scripts/setup_aruco_runtime.bash
roslaunch px4 aruco_search_and_land_weighted_demo.launch gui:=true
```

我这里复现过一次失败，真正的致命错误是 Gazebo 端口占用：

```text
Unable to start server [bind: Address already in use]
```

清理后再次启动已经成功，日志里出现了：

```text
SpawnModel: Successfully spawned entity
Simulator connected on TCP port 4560
PX4 Startup script returned successfully
```

如果你看到 `fuel.gazebosim.org`、`models.gazebosim.org/fountain` 连接失败，这通常是 Gazebo GUI 想访问在线模型库，不是本项目 ArUco 模型缺失。可以在启动前禁用在线模型库：

```bash
export GAZEBO_MODEL_DATABASE_URI=""
```

如果是在 VMware 里 GUI 黑屏或渲染异常，先尝试：

```bash
export SVGA_VGPU10=0
export LIBGL_ALWAYS_SOFTWARE=1
```

## 1. 你要上传到 GitHub 的两种方式

这里有一个现实限制要先讲清楚：

- 如果你希望新设备 `git clone` 后就是完整 PX4 工作区，能直接 `roslaunch px4 ...`，那仓库必须包含 PX4 主工程，体积会比较大。
- 如果你希望只上传单码/嵌套码降落相关文件，仓库会很小，但它本身不是完整 PX4，需要通过脚本或 Docker 把这些文件覆盖到 PX4 基础工程里。

推荐做两个仓库：

```text
1. PX4-Visual-Landing-Runtime
   完整可运行仓库。新设备用 HTTPS clone 后直接构建运行。

2. px4-aruco-precision-landing-overlay
   精简迁移仓库。只包含当前项目新增/修改的视觉降落文件和 Docker 方案。
```

如果你只想维护一个仓库，我建议优先做完整可运行仓库，因为它最符合“别人 clone 后能直接用”的要求。

## 2. 第一次使用 GitHub：准备工作

### 2.1 注册和创建仓库

1. 打开 GitHub 官网并登录。
2. 点击右上角 `+`，选择 `New repository`。
3. 仓库名建议：

```text
PX4-Visual-Landing-Runtime
```

4. 选择 `Public`。这样别人可以直接用 HTTPS clone，不需要你的 SSH 密钥。
5. 不要勾选 `Add a README file`。
6. 不要添加 `.gitignore`。
7. 不要选择 license。
8. 点击 `Create repository`。

### 2.2 本机配置 Git 身份

只需要做一次：

```bash
git config --global user.name "你的GitHub用户名"
git config --global user.email "你的邮箱"
```

查看是否设置成功：

```bash
git config --global --list
```

### 2.3 使用 HTTPS 推送，不使用 SSH

GitHub 已经不支持用账号密码直接推送。你有两种选择：

方式 A：安装 GitHub CLI，最省心：

```bash
sudo apt update
sudo apt install -y gh
gh auth login
```

如果你的 Ubuntu 软件源里没有 `gh`，直接用下面的 Personal Access Token 方式即可。

登录时选择：

```text
GitHub.com
HTTPS
Login with a web browser
```

方式 B：使用 Personal Access Token：

1. GitHub 右上角头像。
2. `Settings`。
3. `Developer settings`。
4. `Personal access tokens`。
5. 创建 fine-grained token。
6. Repository 选择你的仓库。
7. 权限给 `Contents: Read and write`。
8. 推送时用户名填 GitHub 用户名，密码填 token。

## 3. 完整可运行仓库上传流程

这个方式最适合新设备直接：

```bash
git clone --recursive https://github.com/你的用户名/PX4-Visual-Landing-Runtime.git
```

### 3.1 先不要用网页上传

不要把文件夹拖到 GitHub 网页上传。PX4 项目太大，网页上传很容易中断。

使用命令行推送。

### 3.2 确认不要上传运行产物

当前项目里不要上传这些：

```text
build/
devel/
.catkin_tools/
generated/
logs/
scripts/__pycache__/
*.pyc
*.ulg
```

如果它们被误加入 Git，先从暂存区移除：

```bash
cd /home/zz/PX4_Firmware
git rm -r --cached build devel .catkin_tools generated logs 2>/dev/null || true
git rm -r --cached scripts/__pycache__ 2>/dev/null || true
```

### 3.3 检查大文件

```bash
cd /home/zz/PX4_Firmware
du -sh .
du -sh build devel generated logs 2>/dev/null
find . -type f -size +50M \
  -not -path "./.git/*" \
  -not -path "./build/*" \
  -not -path "./devel/*" \
  -not -path "./generated/*" \
  -not -path "./logs/*"
```

如果大文件来自 `build/`、`generated/`、`logs/`，不要提交。

### 3.4 添加 GitHub HTTPS 远程仓库

如果当前仓库的 `origin` 还是 PX4 官方仓库，先改名：

```bash
cd /home/zz/PX4_Firmware
git remote -v
git remote rename origin upstream
```

添加你的 GitHub 仓库：

```bash
git remote add origin https://github.com/你的用户名/PX4-Visual-Landing-Runtime.git
git remote -v
```

### 3.5 只添加视觉降落相关文件

如果你做完整可运行仓库，可以保留 PX4 基础工程，但新增/修改内容建议只明确添加这些：

```bash
cd /home/zz/PX4_Firmware

git add \
  .gitignore \
  docs/precision_landing_github_docker_full_guide.md \
  config/aruco_single_marker.yaml \
  config/aruco_nested_board.yaml \
  config/aruco_nested_board_weighted.yaml \
  config/camera_monocular_1280x720.yaml \
  launch/aruco_detect_and_search.launch \
  launch/aruco_detect_and_search_weighted.launch \
  launch/aruco_search_and_land_demo.launch \
  launch/aruco_search_and_land_weighted_demo.launch \
  launch/aruco_search_and_land_benchmark.launch \
  launch/mavros_posix_sitl_aruco_project.launch \
  launch/posix_sitl.launch \
  scripts/setup_aruco_runtime.bash \
  scripts/cleanup_aruco_runtime.sh \
  scripts/aruco_multi_marker_det.py \
  scripts/aruco_multi_marker_det_weighted.py \
  scripts/aruco_search_and_detect.py \
  scripts/aruco_search_and_detect_no_pid.py
```

Gazebo 子模块里的模型和世界也要提交到 `Tools/sitl_gazebo` 子模块自己的仓库，不能只在 PX4 主仓库里 `git add`。详见第 4 节。

检查暂存内容：

```bash
git status --short
git diff --cached --name-only
```

确认不要出现这些测试脚本：

```text
scripts/benchmark_*.py
scripts/batch_*.py
scripts/plot_*.py
scripts/sweep_*.py
scripts/test_*.py
scripts/capture_and_detect_aruco.py
scripts/realtime_*.py
scripts/make_aruco_nested_layout.py
scripts/aruco_search_and_detect_baseline.py
```

如果误加了，用：

```bash
git restore --staged scripts/benchmark_*.py scripts/batch_*.py scripts/plot_*.py scripts/sweep_*.py scripts/test_*.py 2>/dev/null || true
git restore --staged scripts/capture_and_detect_aruco.py scripts/realtime_*.py scripts/make_aruco_nested_layout.py scripts/aruco_search_and_detect_baseline.py 2>/dev/null || true
```

### 3.6 提交和推送

```bash
git commit -m "Add ArUco precision landing runtime"
git push -u origin HEAD:main
```

以后修改后再上传：

```bash
git status
git add 你修改过的文件
git commit -m "说明这次修改"
git push
```

## 4. Gazebo 子模块必须单独上传

当前 ArUco 世界和模型在：

```text
Tools/sitl_gazebo
```

这是一个 Git 子模块。你需要给它也创建一个 GitHub 仓库，例如：

```text
PX4-SITL-gazebo-Visual-Landing
```

在 GitHub 创建公开仓库后：

```bash
cd /home/zz/PX4_Firmware/Tools/sitl_gazebo
git remote -v
git remote rename origin upstream
git remote add origin https://github.com/你的用户名/PX4-SITL-gazebo-Visual-Landing.git
git checkout -b visual-landing-gazebo
```

只添加单码/嵌套码必需模型和世界：

```bash
git add \
  worlds/aruco_search_demo.world \
  worlds/aruco_single_marker_demo.world \
  models/aruco_nested_board \
  models/aruco_marker_6x6_1000_31_plane \
  models/iris_down_monocular_cam \
  models/monocular_camera
```

提交并推送：

```bash
git commit -m "Add ArUco landing worlds and models"
git push -u origin visual-landing-gazebo
```

回到 PX4 主仓库，把子模块地址改成 HTTPS：

```bash
cd /home/zz/PX4_Firmware
git config -f .gitmodules submodule.Tools/sitl_gazebo.url https://github.com/你的用户名/PX4-SITL-gazebo-Visual-Landing.git
git config -f .gitmodules submodule.Tools/sitl_gazebo.branch visual-landing-gazebo
git submodule sync Tools/sitl_gazebo
git add .gitmodules Tools/sitl_gazebo
git commit -m "Point SITL Gazebo submodule to visual landing fork"
git push
```

新设备就可以用 HTTPS 克隆主仓库和子模块：

```bash
git clone --recursive https://github.com/你的用户名/PX4-Visual-Landing-Runtime.git /home/zz/PX4_Firmware
```

## 5. 精简 overlay 仓库方案

如果你只想上传当前项目新增的最小文件，不想上传整个 PX4，就新建第二个仓库：

```text
px4-aruco-precision-landing-overlay
```

推荐结构：

```text
px4-aruco-precision-landing-overlay/
  README.md
  px4_overlay/
    config/
    launch/
    scripts/
    Tools/sitl_gazebo/models/
    Tools/sitl_gazebo/worlds/
  docker/
    Dockerfile
    entrypoint.sh
```

从当前项目复制最小文件：

```bash
mkdir -p ~/px4-aruco-precision-landing-overlay
cd ~/px4-aruco-precision-landing-overlay
mkdir -p px4_overlay

cd /home/zz/PX4_Firmware
rsync -av --relative \
  config/aruco_single_marker.yaml \
  config/aruco_nested_board.yaml \
  config/aruco_nested_board_weighted.yaml \
  config/camera_monocular_1280x720.yaml \
  launch/aruco_detect_and_search.launch \
  launch/aruco_detect_and_search_weighted.launch \
  launch/aruco_search_and_land_demo.launch \
  launch/aruco_search_and_land_weighted_demo.launch \
  launch/aruco_search_and_land_benchmark.launch \
  launch/mavros_posix_sitl_aruco_project.launch \
  launch/posix_sitl.launch \
  scripts/setup_aruco_runtime.bash \
  scripts/cleanup_aruco_runtime.sh \
  scripts/aruco_multi_marker_det.py \
  scripts/aruco_multi_marker_det_weighted.py \
  scripts/aruco_search_and_detect.py \
  scripts/aruco_search_and_detect_no_pid.py \
  Tools/sitl_gazebo/worlds/aruco_search_demo.world \
  Tools/sitl_gazebo/worlds/aruco_single_marker_demo.world \
  Tools/sitl_gazebo/models/aruco_nested_board \
  Tools/sitl_gazebo/models/aruco_marker_6x6_1000_31_plane \
  Tools/sitl_gazebo/models/iris_down_monocular_cam \
  Tools/sitl_gazebo/models/monocular_camera \
  ~/px4-aruco-precision-landing-overlay/px4_overlay/
```

注意：不要复制这些测试脚本：

```text
benchmark_*.py
batch_*.py
plot_*.py
sweep_*.py
test_*.py
capture_and_detect_aruco.py
realtime_*.py
make_aruco_nested_layout.py
```

初始化并推送 overlay 仓库：

```bash
cd ~/px4-aruco-precision-landing-overlay
printf "# PX4 ArUco Precision Landing Overlay\n" > README.md
cat > .gitignore <<'EOF'
build/
devel/
.catkin_tools/
generated/
logs/
__pycache__/
*.pyc
*.ulg
EOF

git init
git add README.md .gitignore px4_overlay
git commit -m "Add minimal PX4 ArUco landing overlay"
git branch -M main
git remote add origin https://github.com/你的用户名/px4-aruco-precision-landing-overlay.git
git push -u origin main
```

这个仓库小，不容易上传中断。缺点是 clone 后需要把 `px4_overlay/` 覆盖到 PX4 基础工程中，或者直接使用 Docker 自动完成。

## 6. 解决上传过大导致连接中断

优先级从高到低：

1. 不用网页上传，用 Git 命令行。
2. 不提交 `build/`、`devel/`、`generated/`、`logs/`。
3. Gazebo 大模型放在子模块自己的仓库里。
4. 精简 overlay 仓库只上传运行必需文件。
5. 如果已经误提交了大文件，最省心是重新建一个干净仓库，不要在旧大仓库里继续修。

推送前检查：

```bash
git status --short
git diff --cached --name-only
git count-objects -vH
```

如果网络不稳定，可以尝试：

```bash
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
git config --global core.compression 0
git push --progress
```

如果仍然中断，分成多个小提交推送：

```bash
git add config launch scripts
git commit -m "Add ArUco ROS runtime files"
git push

git add docs
git commit -m "Add deployment documentation"
git push
```

## 7. 新设备原生环境安装命令

推荐系统：

```text
Ubuntu 20.04
ROS Noetic
Gazebo 11
Python 3
```

如果要完全兼容你当前硬编码路径，建议新设备也使用用户 `zz`，项目路径为：

```text
/home/zz/PX4_Firmware
```

### 7.1 基础工具

```bash
sudo apt update
sudo apt install -y \
  git curl wget gnupg lsb-release ca-certificates \
  build-essential cmake ninja-build pkg-config \
  python3 python3-dev python3-pip python3-setuptools python3-wheel \
  unzip zip rsync
```

### 7.2 添加 ROS Noetic 源

```bash
sudo mkdir -p /etc/apt/keyrings
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc \
  | sudo gpg --dearmor -o /etc/apt/keyrings/ros-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/ros1.list

sudo apt update
```

### 7.3 安装 ROS、MAVROS、Gazebo、OpenCV

```bash
sudo apt install -y \
  ros-noetic-desktop-full \
  ros-noetic-mavros ros-noetic-mavros-extras \
  ros-noetic-gazebo-ros-pkgs ros-noetic-gazebo-ros-control \
  ros-noetic-cv-bridge ros-noetic-image-transport \
  ros-noetic-tf ros-noetic-tf2-ros ros-noetic-dynamic-reconfigure \
  ros-noetic-geometry-msgs ros-noetic-sensor-msgs ros-noetic-nav-msgs \
  ros-noetic-std-msgs ros-noetic-visualization-msgs \
  python3-rosdep python3-catkin-tools python3-vcstool \
  python3-opencv libopencv-dev libopencv-contrib-dev \
  gazebo11 libgazebo11-dev
```

初始化 rosdep：

```bash
sudo rosdep init 2>/dev/null || true
rosdep update
```

安装 MAVROS 地理数据：

```bash
sudo /opt/ros/noetic/lib/mavros/install_geographiclib_datasets.sh
```

验证 OpenCV ArUco：

```bash
python3 -c "import cv2; print(cv2.__version__); print(hasattr(cv2, 'aruco'))"
```

最后一行必须是：

```text
True
```

### 7.4 克隆你的项目

完整可运行仓库：

```bash
git clone --recursive https://github.com/你的用户名/PX4-Visual-Landing-Runtime.git /home/zz/PX4_Firmware
cd /home/zz/PX4_Firmware
git submodule update --init --recursive
```

安装 PX4 Python 依赖并构建：

```bash
cd /home/zz/PX4_Firmware
python3 -m pip install --user -r Tools/setup/requirements.txt
DONT_RUN=1 make px4_sitl_default gazebo
```

如果你保留外部 ArUco workspace，则也克隆它：

```bash
git clone https://github.com/你的用户名/ros_gazebo_px4_sim_ws.git /home/zz/ros_gazebo_px4_sim_ws-master
cd /home/zz/ros_gazebo_px4_sim_ws-master
rosdep install --from-paths src --ignore-src -r -y
catkin build
```

如果不需要旧版 `maxi_aruco_det_pkg`，可以创建空 workspace 避免硬编码 source 失败：

```bash
mkdir -p /home/zz/ros_gazebo_px4_sim_ws-master/src
cd /home/zz/ros_gazebo_px4_sim_ws-master
catkin build

mkdir -p /home/zz/catkin_ws/src
cd /home/zz/catkin_ws
catkin build
```

## 8. 启动命令矩阵

每次启动前建议先清理：

```bash
cd /home/zz/PX4_Firmware
scripts/cleanup_aruco_runtime.sh
source scripts/setup_aruco_runtime.bash
export GAZEBO_MODEL_DATABASE_URI=""
```

### 8.1 嵌套码 + weighted 检测 + PID

这是你给出的命令，也是当前推荐主流程：

```bash
roslaunch px4 aruco_search_and_land_weighted_demo.launch gui:=true
```

无 GUI：

```bash
roslaunch px4 aruco_search_and_land_weighted_demo.launch gui:=false
```

### 8.2 嵌套码 + 普通检测 + PID

```bash
roslaunch px4 aruco_search_and_land_demo.launch gui:=true
```

### 8.3 嵌套码 + weighted 检测 + 无 PID

```bash
WORLD=$(rospack find mavlink_sitl_gazebo)/worlds/aruco_search_demo.world
CFG=$(rospack find px4)/config/aruco_nested_board_weighted.yaml

roslaunch px4 aruco_search_and_land_benchmark.launch \
  gui:=true \
  world:="$WORLD" \
  marker_config_path:="$CFG" \
  detector_type:=aruco_multi_marker_det_weighted.py \
  controller_type:=aruco_search_and_detect_no_pid.py
```

### 8.4 单码 + PID

```bash
WORLD=$(rospack find mavlink_sitl_gazebo)/worlds/aruco_single_marker_demo.world
CFG=$(rospack find px4)/config/aruco_single_marker.yaml

roslaunch px4 aruco_search_and_land_benchmark.launch \
  gui:=true \
  world:="$WORLD" \
  marker_config_path:="$CFG" \
  detector_type:=aruco_multi_marker_det.py \
  controller_type:=aruco_search_and_detect.py
```

### 8.5 单码 + 无 PID

```bash
WORLD=$(rospack find mavlink_sitl_gazebo)/worlds/aruco_single_marker_demo.world
CFG=$(rospack find px4)/config/aruco_single_marker.yaml

roslaunch px4 aruco_search_and_land_benchmark.launch \
  gui:=true \
  world:="$WORLD" \
  marker_config_path:="$CFG" \
  detector_type:=aruco_multi_marker_det.py \
  controller_type:=aruco_search_and_detect_no_pid.py
```

### 8.6 检查运行状态

```bash
rostopic echo -n 1 /mavros/state
rostopic list | grep -E "camera|aruco|mavros/state|local_position"
rostopic hz /aruco/pose -w 5
```

## 9. Docker 迁移方案

Docker 的目标是避免新设备 ROS/Gazebo/PX4 环境不一致。

### 9.1 新设备安装 Docker

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
docker --version
```

如果要使用 NVIDIA 显卡：

```bash
sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### 9.2 Dockerfile 方案

在 overlay 仓库中创建 `docker/Dockerfile`，核心思路是：

```dockerfile
FROM osrf/ros:noetic-desktop-full

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=noetic
ENV GAZEBO_MODEL_DATABASE_URI=""

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl wget ca-certificates gnupg lsb-release sudo \
    build-essential cmake ninja-build pkg-config rsync unzip zip \
    python3 python3-dev python3-pip python3-setuptools python3-wheel \
    python3-opencv libopencv-dev libopencv-contrib-dev \
    gazebo11 libgazebo11-dev \
    ros-noetic-mavros ros-noetic-mavros-extras \
    ros-noetic-gazebo-ros-pkgs ros-noetic-gazebo-ros-control \
    ros-noetic-cv-bridge ros-noetic-image-transport \
    ros-noetic-tf ros-noetic-tf2-ros ros-noetic-dynamic-reconfigure \
    ros-noetic-geometry-msgs ros-noetic-sensor-msgs ros-noetic-nav-msgs \
    ros-noetic-std-msgs ros-noetic-visualization-msgs \
    python3-rosdep python3-catkin-tools python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

RUN /opt/ros/noetic/lib/mavros/install_geographiclib_datasets.sh

RUN useradd -m -s /bin/bash zz && echo "zz ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/zz
USER zz
WORKDIR /home/zz

RUN git clone --recursive https://github.com/PX4/PX4-Autopilot.git PX4_Firmware \
    && cd PX4_Firmware \
    && git checkout 46a12a09bf11c8cbafc5ad905996645b4fe1a9df \
    && git submodule update --init --recursive

COPY --chown=zz:zz px4_overlay/ /home/zz/PX4_Firmware/

RUN mkdir -p /home/zz/catkin_ws/src /home/zz/ros_gazebo_px4_sim_ws-master/src \
    && /bin/bash -lc "source /opt/ros/noetic/setup.bash && cd /home/zz/catkin_ws && catkin build" \
    && /bin/bash -lc "source /opt/ros/noetic/setup.bash && cd /home/zz/ros_gazebo_px4_sim_ws-master && catkin build"

RUN cd /home/zz/PX4_Firmware \
    && python3 -m pip install --user -r Tools/setup/requirements.txt \
    && DONT_RUN=1 make px4_sitl_default gazebo

WORKDIR /home/zz/PX4_Firmware
CMD ["/bin/bash"]
```

如果你的完整可运行仓库已经在 GitHub，可以把 `PX4/PX4-Autopilot.git` 换成你的 HTTPS 仓库：

```dockerfile
RUN git clone --recursive https://github.com/你的用户名/PX4-Visual-Landing-Runtime.git PX4_Firmware
```

这样就不需要 `COPY px4_overlay/`。

### 9.3 构建 Docker 镜像

在 overlay 仓库根目录：

```bash
docker build -f docker/Dockerfile -t px4-aruco-landing:noetic .
```

### 9.4 Docker 内无 GUI 启动

```bash
docker run --rm -it --net=host --name px4_aruco \
  px4-aruco-landing:noetic \
  bash -lc "source scripts/setup_aruco_runtime.bash && roslaunch px4 aruco_search_and_land_weighted_demo.launch gui:=false"
```

### 9.5 Docker 内 GUI 启动

宿主机允许 Docker 使用 X11：

```bash
xhost +local:docker
```

启动：

```bash
docker run --rm -it --net=host --privileged --name px4_aruco \
  -e DISPLAY=$DISPLAY \
  -e QT_X11_NO_MITSHM=1 \
  -e GAZEBO_MODEL_DATABASE_URI="" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  px4-aruco-landing:noetic \
  bash -lc "source scripts/setup_aruco_runtime.bash && roslaunch px4 aruco_search_and_land_weighted_demo.launch gui:=true"
```

如果是 VMware：

```bash
docker run --rm -it --net=host --privileged --name px4_aruco \
  -e DISPLAY=$DISPLAY \
  -e QT_X11_NO_MITSHM=1 \
  -e SVGA_VGPU10=0 \
  -e LIBGL_ALWAYS_SOFTWARE=1 \
  -e GAZEBO_MODEL_DATABASE_URI="" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  px4-aruco-landing:noetic \
  bash -lc "source scripts/setup_aruco_runtime.bash && roslaunch px4 aruco_search_and_land_weighted_demo.launch gui:=true"
```

### 9.6 Docker 清理

```bash
docker ps
docker stop px4_aruco
docker rm px4_aruco 2>/dev/null || true
```

## 10. 推荐最终操作顺序

第一次建议按这个顺序来：

1. 本机执行：

```bash
cd /home/zz/PX4_Firmware
scripts/cleanup_aruco_runtime.sh
source scripts/setup_aruco_runtime.bash
roslaunch px4 aruco_search_and_land_weighted_demo.launch gui:=true
```

确认可以跑。

2. GitHub 创建公开仓库：

```text
PX4-SITL-gazebo-Visual-Landing
PX4-Visual-Landing-Runtime
```

3. 先推 `Tools/sitl_gazebo` 子模块。

4. 再推 PX4 主仓库。

5. 用另一台机器测试 HTTPS clone：

```bash
git clone --recursive https://github.com/你的用户名/PX4-Visual-Landing-Runtime.git /home/zz/PX4_Firmware
```

6. 如果 clone 和 build 太慢，再做 overlay + Docker 仓库。

7. 项目稳定后，README 首页只保留最短命令：

```bash
git clone --recursive https://github.com/你的用户名/PX4-Visual-Landing-Runtime.git /home/zz/PX4_Firmware
cd /home/zz/PX4_Firmware
python3 -m pip install --user -r Tools/setup/requirements.txt
DONT_RUN=1 make px4_sitl_default gazebo
scripts/cleanup_aruco_runtime.sh
source scripts/setup_aruco_runtime.bash
roslaunch px4 aruco_search_and_land_weighted_demo.launch gui:=true
```
