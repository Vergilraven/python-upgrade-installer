#!/bin/bash

main() {
    # 按照步骤依次执行
    # 检测操作系统类型
    detect_os
    # 检测Python解释器是否存在
    python_binary_status=$(detect_python_binary)
    # 所需Python版本
    required_version="3.10.13"
    # Python二进制文件名
    python_binary="python"
    # 指定tar包文件的名称
    gcc_tar_ball="gcc-8.5.0.tar.gz"
    gmp_tar_ball="gmp-6.3.0.tar.gz"
    mpfr_tar_ball="mpfr-4.1.0.tar.gz"
    mpc_tar_ball="mpc-1.3.1.tar.gz"
    HOME="/home"
    dependency="/home/dependency"
    # 指定python-tar包的名称
    python_tar_ball="Python-3.10.13.tgz"
    # 新的安装路径
    new_path="/usr/local/bin"

    source_template
    yum groupinstall 'Development Tools' -y
    packagenames=("m4" "which" "sudo" "gcc-c++" "zlib-devel" "make" "libffi-devel" "bzip2-devel" "ncurses-devel" "gdbm-devel" "sqlite-devel" "tk-devel" "uuid-devel" "readline-devel")
    for pkg in "${packagenames[@]}"; do
        if rpm -qa | grep -q "$pkg"; then
            echo "$pkg is already installed."
        else
            install_pack "$pkg"
        fi
    done
    # binary_packages=('')
    make_install_packages

    if [ "$python_binary_status" -eq 0 ]; then
        echo "Python3 is not installed."
    elif [ "$python_binary_status" -eq 1 ]; then
        echo "Python3 is installed,Starting checking the version of python3,Plz wait"
        version_compare
    else
        download_package
    fi
}

# 进度条函数
progress_bar() {
    mark=''
    for ((ratio=0;ratio<=100;ratio+=5))
    do
        sleep 0.1
        printf "进度:[%-40s]%d%%\r" "${mark}" "${ratio}"
        mark=">>${mark}"
    done
    echo "任务已经完成"
}

# 检测Python版本的函数
version_compare() {
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    if [ "$(version_compare_internal "$python_version" "$required_version")" -eq 1 ]; then
        echo "Current Python version is $python_version, upgrading to $required_version..."
    else
        echo "Python is up to date ($python_version). No need to upgrade."
    fi
}

# 编译安装gcc的函数
# 其中包含了编译安装依赖包的逻辑
# ./configure --enable-optimizations 使用该条指令安装稳定的gcc环境
make_install_packages() {
    # 临时方案
    yum install -y gcc
    # 指令释放路径
    echo '开始释放各种装Python3.10所需的tar包'
    # 这里是因为编译安装找不到Makefile并且初始化容器的时候gpg钥匙认证失败采取的临时解决方法
    tar -xzvf $gcc_tar_ball -C $new_path
    tar -xzvf $dependency/$gmp_tar_ball -C $new_path
    tar -xzvf $dependency/$mpfr_tar_ball -C $new_path
    tar -xzvf $dependency/$mpc_tar_ball -C $new_path
    progress_bar
    # echo "开始下载依赖包......"
    # 这边从gnu官网下载包的逻辑可以做的更加考究一点
    # 这边如果有别的要求可以改为,本地上传校验完的tar包进行安装
    # curl -o $new_path/mpc-1.3.1.tar.gz http://ftp.gnu.org/pub/gnu/mpc/mpc-1.3.1.tar.gz
    # curl -o $new_path/mpfr-3.1.6.tar.gz http://ftp.gnu.org/pub/pub/gnu/mpfr/mpfr-3.1.6.tar.gz
    # curl -o $new_path/gmp-6.3.0.tar.gz http://ftp.gnu.org/pub/pub/gnu/gmp/gmp-6.3.0.tar.gz
    # progress_bar

    echo '---第一步开始编译安装gmp---'
    cd $new_path
    # GMP_TAR=$(ls | grep gmp)
    # tar -zxvf $GMP_TAR && rm -rf $GMP_TAR
    GMP=$(ls | grep gmp)
    # 做编译安装gmp的动作
    cd $GMP && ./configure --prefix=$new_path/$GMP --enable-optimizations
    make && make install
    sleep 1

    echo '---第二步开始编译安装mpfr---'
    cd $new_path
    # MPFR_TAR=$(ls | grep mpfr)
    # tar -zxvf $MPFR_TAR && rm -rf $MPFR_TAR
    MPFR=$(ls | grep mpfr)
    # 做编译安装mpfr的动作
    cd $MPFR && ./configure --prefix=$new_path/$MPFR --with-gmp=$new_path/$GMP --enable-optimizations
    make && make install
    export LD_LIBRARY_PATH=/usr/local/bin/mpfr-4.1.0/lib
    sleep 1

    cd $new_path
    echo '---最后开始编译安装mpc---'
    # MPC_TAR=$(ls | grep mpc)
    # tar -zxvf $MPC_TAR && rm -rf $MPC_TAR
    MPC=$(ls | grep mpc)
    # 做编译安装mpc的动作
    cd $MPC && ./configure --prefix=$new_path/$MPC --with-gmp=$new_path/$GMP --with-mpfr=$new_path/$MPFR --enable-optimizations
    make && make install
    sleep 1

    echo '开始编译安装gcc'
    # gmp-6.3.0  mpc-1.3.1 mpfr-3.1.6 gcc-8.5.0 /usr/local/bin
    export LD_LIBRARY_PATH=$new_path/$GMP/lib:$new_path/$MPFR/lib/:$new_path/$MPC:$LD_LIBRARY_PATH
    # ./configure --with-gmp=/path/to/gmp --with-mpfr=/path/to/mpfr --with-mpc=/path/to/mpc
    cd /usr/local/bin/gcc-8.5.0 && ./configure --with-gmp=/usr/local/bin/gmp-6.3.0 \
    --with-mpfr=/usr/local/bin/mpfr-4.1.0 --with-mpc=/usr/local/bin/mpc-1.3.1 \
    --disable-multilib
    # --disable-multilib --disable-bootstrap --without-headers --target=aarch64-linux-musl

    # cd /usr/local/bin/gcc-8.5.0 && ./configure --prefix=/usr/local/bin/gcc-8.5.0 \
    # --enable-threads=posix --disable-checking --disable-multilib \
    # --enable-languages=c,c++ \
    # --with-gmp=/usr/local/bin/gmp-6.3.0 --with-mpfr=/usr/local/bin/mpfr-3.1.6 --with-mpc=/usr/local/bin/mpc-1.3.1 \
    # --build=x86_64-linux --enable-optimizations
    make && make install
    sleep 1
    echo "开始检查gcc状态"
    which gcc

}

# 检测Python3解释器是否存在的函数
detect_python_binary() {
    if [ ! -e /usr/bin/python3 ]; then
        echo 0 # Python3解释器不存在
    else
        echo 1 # Python3解释器存在
    fi
}

# 比较版本号函数
version_compare_internal() {
    v1=$1
    v2=$2
    if [[ $(echo -e "$v1\n$v2" | sort -V | head -n1) == "$v1" ]]; then
        echo 1 # 如果等于版本1 调用第一个变量
    elif [[ $(echo -e "$v1\n$v2" | sort -V | head -n1) == "$v2" ]]; then
        echo -1 # 如果等于版本2 调用第二个变量
    else
        echo 0
    fi
}

# 检测操作系统类型的函数
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=${ID}
    elif [ -f /etc/centos-release ]; then
        OS_NAME="centos"
    else
        OS_NAME="unknown"
    fi
}

# 安装包的函数
install_pack() {
    package="$1"
    if [ "$OS_NAME" == "ubuntu" ]; then
        echo "apt-get install $package on $OS_NAME..."
        # 在这里执行Ubuntu系统下的安装操作，例如：
        # sudo apt-get install "$package"
    elif [ "$OS_NAME" == "centos" ] || [ "$OS_NAME" == "alinux" ]; then
        echo "yum install $package on $OS_NAME..."
        # 在这里执行CentOS或Alibaba Linux系统下的安装操作，例如：
        sudo yum install -y "$package"
    else
        echo "Unsupported operating system: $OS_NAME"
    fi
}


source_template() {
    if [ "$OS_NAME" == "ubuntu" ]; then
        mv -f sources-template.list /etc/apt/sources.list
        echo "正在更新apt源..."
        apt-get update
        apt install sudo -y
        progress_bar

    elif [ "$OS_NAME" == "centos" ] || [ "$OS_NAME" == "alinux" ]; then
        echo "正在替换服务器DNS文件......"
        # mv -f /home/resolv-template.conf /etc/resolv.conf
        echo "nameserver 100.100.2.136" >> /etc/resolv.conf
        echo "nameserver 100.100.2.138" >> /etc/resolv.conf
        echo "正在备份原始yum源文件......"
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
        progress_bar
        echo "正在download阿里云Centos7的yum源文件"
        curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
        echo "正在更新yum源......"
        yum update -y
        yum install sudo -y
        progress_bar
    else
        echo "不支持的操作系统: $OS_NAME"
    fi
}

download_package() {
    convert_name=$(echo "$python_binary" | cut -c1 | tr 'a-z' 'A-Z')
    rest_name=$(echo "$python_binary" | cut -c2-)
    mix_name="$convert_name$rest_name"
    # tar_ball="$mix_name-$required_version.tgz"


    company_url="git@github.com:Vergilraven/test-autoupgde-python.git"
    status_code=$(curl -o /dev/null -s -w %{http_code} https://www.python.org)
    if [ "$status_code" == 200 ]; then
        echo "正在连接外网环境,从官网下载安装包"
        # wget "https://www.python.org/ftp/$python_binary/$required_version/$tar_ball"
        # git clone "$company_url"
    else
        echo "正在下载公司的代码仓库里的安装包"
        sleep 1
        # cd test-autoupgde-python/
    fi
    convert_version=$required_version | awk -F "." '{print $1"."$2}'
    TAR_RELEASE=$(tar -xzvf "$HOME/$python_tar_ball" -C $new_path)
    mv $new_path/$mix_name-$required_version $new_path/python3.10/
    cd $new_path/python3.10/
    # 编译和安装
    # ./configure
    ./configure --enable-optimizations
    make && make install

    if [ "$python_binary_status" -eq 1 ]; then
        echo "开始删除python3二进制链接..."
        sudo rm "$current_python_path"
    fi

    sudo ln -s "$new_path/python3.10" "/usr/bin/python3"
    echo "开始配置国内镜像源地址"
    sleep 0.5
    pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/
    pip3 config set global.trusted-host mirrors.aliyun.com

    sudo python3 -m ensurepip
    sudo python3 -m pip install --upgrade pip
    sudo pip3 install --upgrade setuptools

    version_command="python3 -V"
    eval "$version_command"
}

# 调用主函数
main