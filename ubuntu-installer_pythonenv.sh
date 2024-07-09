#!/bin/bash
# Functions: Auto upgrade the python binary version
# 乌班图操作系统的流程全部跑通了
# 再加一个安装gcc版本的函数就行了

# 主函数
main() {
    # 检测操作系统类型
    detect_os
    # 检测Python解释器是否存在
    python_binary_status=$(detect_python_binary)
    # 所需Python版本
    required_version="3.10.13"
    # Python二进制文件名
    python_binary="python"
    # 指定gcc-tar包文件的名称
    gcc_tar_ball="gcc-8.5.0.tar.gz"
    # 新的安装路径
    new_path="/usr/local"
    current_python_path=$(which python3)
    if [ -n "$current_python_path" ]; then
        echo "当前使用的Python为: $current_python_path"
    else
        echo "未找到Python解释器"
    fi

    source_template
    # ncurses sqlite sqlite openssl11和gcc要加解包逻辑 "openssl11" "openssl11-devel"
    packagenames=("libffi-dev" "g++" "gcc" "make" "libssl-dev" "zlib1g-dev" "gdbm-devel" "uuid-devel" "build-essential")
    for pkg in "${packagenames[@]}"; do
        # 检查包是否已安装
        if dpkg -l | grep -E "^ii\s+$pkg\s+" &>/dev/null; then
            echo "$pkg 已经安装。"
            # 检查 gcc 版本是否大于 5
            if [[ $pkg == "gcc" ]]; then
                version=$(gcc --version | grep -oP '(?<=gcc \(Ubuntu )\d+')
                if ((version > 5)); then
                    echo "gcc 版本大于 5。"
                else
                    echo "gcc 版本小于等于 5。"
                fi
            # 检查 openssl 版本是否大于等于 1.1.1
            elif [[ $pkg == "openssl11" ]]; then
                version=$(openssl version | grep -oP '(?<=OpenSSL )[\d\.]+')
                if ((version >= 1.1)); then
                    echo "openssl 版本大于等于 1.1.1。"
                else
                    echo "openssl 版本小于 1.1.1。"
                fi
            else
                :
            fi
        else
            # 安装包
            echo "安装 $pkg..."
            install_pack "$pkg"
        fi
    done

    if [ "$python_binary_status" -eq 0 ]; then
        echo "Python3 未安装。"
    elif [ "$python_binary_status" -eq 1 ]; then
        echo "Python3 已安装，开始检查Python3的版本，请稍候..."
        version_compare
    fi

    # 下载和编译Python
    download_package
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
    echo
}

# 检测Python版本
version_compare() {
    python_version=$("$new_path/bin/python3" --version 2>&1 | awk '{print $2}')
    if [ "$(version_compare_internal "$python_version" "$required_version")" -eq 1 ]; then
        echo "当前Python版本为 $python_version, 升级至 $required_version..."
    else
        echo "Python已是最新版本 ($python_version)，无需升级。"
    fi
}

# 编译安装gcc的函数
# ./configure --enable-optimizations 使用该条指令安装稳定的gcc环境
make_install_gcc() {
    # 指令释放路径
    tar -xzvf $gcc_tar_ball -C $new_path
    cd $new_path
    GCC=$(ls | grep gcc)
    cd $GCC && ./configure --enable-optimizations && make && make install
    sleep 1
    echo "开始检查gcc状态"
    gcc --version
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
        echo 0 # 版本相同
    fi
}

# 检测操作系统类型的函数
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=${ID}
    elif [ -f /etc/centos-release ]; then
        OS_NAME="centos"
    elif [ -f /etc/os-release ];then
        OS_NAME="ubuntu"
    else
        OS_NAME="unknown"
    fi
}

# 安装软件包的函数
install_pack() {
    package="$1"
    if [ "$OS_NAME" == "ubuntu" ]; then
        echo "apt-get install $package 在 $OS_NAME 上..."
        sudo apt-get install "$package" -y
        echo "******************************************************************************************"
    elif [ "$OS_NAME" == "centos" ] || [ "$OS_NAME" == "alinux" ]; then
        echo "yum install $package 在 $OS_NAME 上..."
        sudo yum install -y "$package"
        echo "******************************************************************************************"
    else
        echo "不支持的操作系统: $OS_NAME"
    fi
}

# 读取对应镜像源模板的函数
source_template() {
    if [ "$OS_NAME" == "ubuntu" ]; then
        mv -f sources-template.list /etc/apt/sources.list
        echo "正在更新apt源..."
        apt-get update
        apt install sudo -y
        progress_bar
    elif [ "$OS_NAME" == "centos" ] || [ "$OS_NAME" == "alinux" ]; then
        echo "正在更新yum源..."
        yum update
        yum install sudo -y
    else
        echo "不支持的操作系统: $OS_NAME"
    fi
}

# 下载Python3.10函数
download_package() {
    convert_name=$(echo "$python_binary" | cut -c1 | tr 'a-z' 'A-Z')
    rest_name=$(echo "$python_binary" | cut -c2-)
    mix_name="$convert_name$rest_name"
    tar_ball="$mix_name-$required_version.tgz"

    # 这段git的逻辑需要进一步检查并实现
    # 替换为公司仓库
    company_url="git@github.com:Vergilraven/test-autoupgde-python.git"
    status_code=$(curl -o /dev/null -s -w %{http_code} https://www.python.org)
    if [ "$status_code" == 200 ]; then
        # git clone "$company_url"
        echo "正在克隆代码仓库"
        sleep 1
        # cd test-autoupgde-python/
    else
        echo "正在连接外网环境,从官网获得安装包"
        # wget "https://www.python.org/ftp/$python_binary/$required_version/$tar_ball"
    fi

    TAR_RELEASE=$(tar zxvf "$mix_name-$required_version.tgz")
    echo "TAR_RELEASE: $TAR_RELEASE"
    echo "$mix_name-$required_version $python_binary-$required_version"
    mv "$mix_name-$required_version" "$new_path/$python_binary-$required_version"
    cd "$new_path/$python_binary-$required_version"

    # 编译和安装
    ./configure --enable-optimizations
    # ./configure
    sudo make && sudo make install

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
