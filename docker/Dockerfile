FROM ubuntu:22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=C.UTF-8

# 安装编译依赖
RUN apt update && apt install -y \
    build-essential clang flex bison g++ gawk \
    gettext git libssl-dev libelf-dev python3-distutils \
    python3-dev rsync unzip zlib1g-dev file wget \
    subversion patch upx-ucl ccache ecj fastjar \
    jarwrapper java-propose-classpath libz-dev \
    libncurses5-dev libncursesw5-dev \
    && rm -rf /var/lib/apt/lists/*

# 配置 ccache
RUN ccache --set-config=cache_dir=/ccache && \
    ccache --set-config=max_size=5G

# 设置工作目录
WORKDIR /openwrt

# 创建编译用户
RUN useradd -m -s /bin/bash builder && \
    mkdir -p /ccache && \
    chown -R builder:builder /ccache /openwrt

USER builder

# 配置 Git
RUN git config --global http.postBuffer 524288000

CMD ["/bin/bash"]