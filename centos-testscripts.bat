docker rm -f vergil-centos
docker run -itd --name vergil-centos centos:7
docker cp centos-installer_pythonenv.sh vergil-centos:/home
docker cp Python-3.10.13.tgz vergil-centos:/home
docker cp gcc-8.5.0.tar.gz vergil-centos:/home
docker cp resolv-template.conf vergil-centos:/home
docker cp D:\Project\software\Product\dependency vergil-centos:/home
docker exec -it medishare-centos /bin/bash