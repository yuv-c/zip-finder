#!/bin/bash
echo "Setting up docker"
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker
sudo chkconfig docker on

# Pull the images
echo "Pulling images"
sudo docker pull docker.elastic.co/kibana/kibana:7.10.2
sudo docker pull docker.elastic.co/elasticsearch/elasticsearch:7.10.2

# Start the containers
echo "Starting containers"
sudo docker run -d --name elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" --restart always -v es_data:/usr/share/elasticsearch/data docker.elastic.co/elasticsearch/elasticsearch:7.10.2
sudo docker run -d --name kibana --link elasticsearch:elasticsearch -p 5601:5601 --restart always -v kibana_data:/usr/share/kibana/data docker.elastic.co/kibana/kibana:7.10.2

# Install plugin
echo "Installing plugin"
sudo docker exec elasticsearch ./bin/elasticsearch-plugin install --batch https://github.com/Immanuelbh/elasticsearch-analysis-hebrew/releases/download/elasticsearch-analysis-hebrew-7.10.2/elasticsearch-analysis-hebrew-7.10.2.zip

# Restart elasticsearch and kibana
sudo docker restart elasticsearch kibana
