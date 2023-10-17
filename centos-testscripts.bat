docker rm -f centos-vergil
docker run -itd --name centos-vergil centos:7
docker cp centos-installer_pythonenv.sh centos-vergil:/home
docker cp Python-3.10.13.tgz centos-vergil:/home
docker cp gcc-8.5.0.tar.gz centos-vergil:/home
docker cp resolv-template.conf centos-vergil:/home
docker cp D:\Project\software\Product\dependency centos-vergil:/home
docker exec -it centos-vergil /bin/bash
