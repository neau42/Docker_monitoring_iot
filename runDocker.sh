#!/bin/bash
# Deployment Docker d'infra monitoring IOT
# DOC/TUTO https://github.com/CampusIoT/tutorial/tree/master/nodered
#
# Placer les fichiers docker dans le dossier ~/Docker 
# Docker et Docker-compose doivent etre installés
# L'utilisateur doit etre sudoers

if [[ "$(whereis docker | grep /)" != "" && "$(whereis docker-compose | grep /)" != "" ]]; then 
    echo "Docker installe ok"
else
    echo "Erreur: docker et docker-compose doivent etre installés"
    exit
fi

if [[ "$(groups | grep docker)" == "" ]] ; then
    echo "Erreur: $USER n'est pas dans le groupe docker"
    exit
else
    echo "$USER dans le groupe docker"
fi

if  [[ "$PWD" == "$HOME/Docker" && "$(ls . | grep 'grafana.yml\|influxdb.yml')" == "grafana.yml
influxdb.yml" ]] ; then
    echo "Fichiers de configuration présents"
else
    echo "Erreur: les fichiers Docker doivent être dans ~/Docker"
    exit
fi
sudo ls >/dev/null 2>&1
if [[ "$?" != "0" ]] ; then
  echo "Erreur: l'utilisateur doit pouvoir utiliser sudo"
  exit
fi

# creer le dossier binde pour influx
sudo mkdir -p /data/influxdb
sudo chown -R $USER:$USER /data

# creer le dossier binde pour nodered
mv ./config/nodered /data/.
sudo chown 1000:1000 /data/nodered
#le user de noderedDocker a forcement l'ID 1000 -_-'

#creer un volume Docker persistant pour Grafana
if [[ "$(docker volume ls -q| grep 'grafana-storage')" == "" ]] ; then
    docker volume create --name=grafana-storage
    echo "Volume \"grafana-storage\" créé"
else
    echo "Volume docker \"grafana-storage\" existe"
    read -p "Réinitialiser ce volume? (Yes/No) " yn
    case $yn in
    [Yy]es )  docker volume rm grafana-storage; docker volume create --name=grafana-storage;echo "Volume \"grafana-storage\" créé";;
        * ) echo "non";;
    esac
fi

#copier le fichier de conf influx
mv ./config/influxdb.conf /data/.

# GRAFANA user: admin
#        pass: dans le fichier ~/Docker/grafana.yml ( definir la variable GF_SECURITY_ADMIN_PASSWORD )

echo "== CONFIG GRAFANA =="
read -sp "Mot de passe \"admin\" Grafana? " pass_grafana
echo ""

sed -i "s/GF_SECURITY_ADMIN_PASSWORD:.*/GF_SECURITY_ADMIN_PASSWORD: $pass_grafana/" grafana.yml
echo -e "\tMot de passe remplacé dans grafana.yml"

#INFLUX
# #        Dans le fichier ~/Docker/influxdb.yml
# #        user et admin name and password

echo "== CONFIG INFLUXDB =="
read -p "Nom d'utilisateur administrateur InfluxDB? " admin_user_influxdb
read -sp "Mot de passe pour \"$admin_user_influxdb\" InfluxDB? " admin_pass_influxdb
echo ""
read -p "Nom d'utilisateur standard InfluxDB? " std_user_influxdb
read -sp "Mot de passe pour \"$std_user_influxdb\" InfluxDB? " std_pass_influxdb
echo ""


sed -i -e "s/INFLUXDB_ADMIN_USER:.*/INFLUXDB_ADMIN_USER: $admin_user_influxdb/" \
       -e "s/INFLUXDB_ADMIN_PASSWORD:.*/INFLUXDB_ADMIN_PASSWORD: $admin_pass_influxdb/" \
       -e "s/INFLUXDB_USER:.*/INFLUXDB_USER: $std_user_influxdb/" \
       -e "s/INFLUXDB_USER_PASSWORD:.*/INFLUXDB_USER_PASSWORD: $std_pass_influxdb/" \
            influxdb.yml

echo -e "\tInformations remplacées dans influxdb.yml"

read -p "Lancer la composition Docker pour definir le mot de passe pour nodered? (Yes/No) " yn
    case $yn in
    [Yy]es )  echo "Ok";;
        * ) echo "No"; exit;;
    esac

docker-compose up -d

#NODERED
# apres le lancement du container via la commande 
echo "== CONFIG NODERED =="
read -sp "Mot de passe administrateur Nodered? " admin_pass_nodered
echo ""
read -sp "Mot de passe utilisateur Nodered? " user_pass_nodered
echo ""
docker-compose exec nodered /data/set_password.sh $admin_pass_nodered $user_pass_nodered
docker-compose restart nodered

IP="$(hostname -I | cut -d ' ' -f1)"

echo -e "==========================================
========= Installation terminiée =========
==========================================
Les Fichiers influxDB et nodered bindés aux conteneurs sont dans le dossier /data

Visualiser les containers actifs : 'docker ps'
Arreter la composition Docker : 'docker-compose down'
Démarrer la composition Docker : 'docker-compose up -d'
(les commandes 'docker-compose' doivent etre executées depuis le dossier ~/Docker)
Acces au services:
================ NODE-RED ================\n\thttp://$IP:1880
\tAuthentification: utilisateur administrateur et mot de passe definis plus tot (le compte utilisateur peute etre utile pour un acces a d'autres panneaux nodered comme /ui)
================ GRAFANA  ================\n\thttp://$IP
\tAuthentification: utilisateur: 'admin' mot de passe defini plus tot
============== INFLUXDB API ==============\n\thttp://$IP:8086
==========================================
\n\nPlus d'informations de configuration disponibles sur le depot de CampusIOT https://github.com/CampusIoT/tutorial/tree/master/nodered"
