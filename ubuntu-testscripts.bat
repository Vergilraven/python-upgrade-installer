docker rm -f ubuntu
docker run -itd --name ubuntu ubuntu:latest
docker cp sources-template.list ubuntu:/home
docker cp ubuntu-installer_pythonenv.sh ubuntu:/home
docker cp Python-3.10.13.tgz ubuntu:/home
docker exec -it ubuntu /bin/bash