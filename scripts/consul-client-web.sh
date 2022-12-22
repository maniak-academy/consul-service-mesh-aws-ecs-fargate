#!/bin/bash

#Utils
sudo apt-get install unzip

#Download Consul
curl --silent --remote-name https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip

#Install Consul
unzip consul_${consul_version}_linux_amd64.zip
sudo chown root:root consul
sudo mv consul /usr/local/bin/
consul -autocomplete-install
complete -C /usr/local/bin/consul consul


#install Envoy
curl https://func-e.io/install.sh | bash -s -- -b /usr/local/bin
func-e use 1.23.1
cp /root/.func-e/versions/1.23.1/bin/envoy /usr/local/bin


#Create Consul User
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

#Create Systemd Config
sudo cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/server.hcl
[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=always
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

#Create config dir
sudo mkdir --parents /etc/consul.d
sudo touch /etc/consul.d/server.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/server.hcl

#Create CA certificate files
sudo touch /etc/consul.d/consul-agent-ca.pem
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul-agent-ca.pem
sudo touch /etc/consul.d/consul-agent-ca-key.pem
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul-agent-ca-key.pem

#Populate CA certificate files
cat << EOF > /etc/consul.d/consul-agent-ca.pem
${consul_ca_cert}
EOF
cat << EOF > /etc/consul.d/consul-agent-ca-key.pem
${consul_ca_key}
EOF


#Create Consul config file
cat << EOF > /etc/consul.d/server.hcl
node_name = "ec2-server-web"
datacenter = "${consul_datacenter}"
data_dir = "/opt/consul"
client_addr = "0.0.0.0"
bind_addr = "0.0.0.0"
acl { 
	enabled = true
	default_policy = "deny"
	enable_token_persistence = true
	tokens {
		master = "${consul_acl_token}"
		agent = "${consul_acl_token}"
	}
}
connect {
    enabled = true
}
retry_join = ["${consul_ip}"]

verify_incoming = false
verify_outgoing = false
verify_server_hostname = false
encrypt = "${consul_gossip_key}"
ca_file = "/etc/consul.d/consul-agent-ca.pem"
auto_encrypt {
  tls = true
}
ports {
  grps_tls = 8503
}

EOF

#Enable the service
sudo systemctl enable consul
sudo service consul start
sudo service consul status



# Pull down and install Fake Service
curl -LO https://github.com/nicholasjackson/fake-service/releases/download/v0.22.7/fake_service_linux_amd64.zip
unzip fake_service_linux_amd64.zip
mv fake-service /usr/local/bin
chmod +x /usr/local/bin/fake-service

# Fake Service Systemd Unit File
cat > /etc/systemd/system/web.service <<- EOF
[Unit]
Description=WEB
After=syslog.target network.target

[Service]
Environment="MESSAGE=Hello from Web"
Environment="NAME=web"
Environment="UPSTREAM_URIS=http://api.service.consul:9090"
ExecStart=/usr/local/bin/fake-service
ExecStop=/bin/sleep 5
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload unit files and start the API
systemctl daemon-reload
systemctl start web

# Consul Conf/ig file for our fake API service
cat > /etc/consul.d/web.hcl <<- EOF
service {
  name = "web"
  port = 9090
  token = "${consul_acl_token}"
  check {
    id = "web"
    name = "HTTP Web on Port 9090"
    http = "http://localhost:9090/health"
    interval = "30s"
  }

  connect {
    sidecar_service {
      port = 20000
      check {
        name     = "Connect Envoy Sidecar"
        tcp      = "127.0.0.1:20000"
        interval = "10s"
      }
      proxy {
        upstreams {
          destination_name   = "api"
          local_bind_address = "127.0.0.1"
          local_bind_port    = 9091
        }
      }
    }
  }
}
EOF

systemctl restart consul

cat > /etc/systemd/system/consul-envoy.service <<- EOF
[Unit]
Description=Consul Envoy
After=syslog.target network.target

# Put web service token here for the -token option!
[Service]
ExecStart=/usr/bin/consul connect envoy -sidecar-for=web -token=${consul_acl_token}
ExecStop=/bin/sleep 5
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start consul-envoy
mkdir -p /etc/systemd/resolved.conf.d

# Point DNS to Consul's DNS
cat > /etc/systemd/resolved.conf.d/consul.conf <<- EOF
[Resolve]
DNS=127.0.0.1
Domains=~consul
EOF

# Because our Ubuntu's systemd is < 245, we need to redirect traffic to the correct port for the DNS changes to take effect
iptables --table nat --append OUTPUT --destination localhost --protocol udp --match udp --dport 53 --jump REDIRECT --to-ports 8600
iptables --table nat --append OUTPUT --destination localhost --protocol tcp --match tcp --dport 53 --jump REDIRECT --to-ports 8600

# Restart systemd-resolved so that the above DNS changes take effect
systemctl restart systemd-resolved


sudo systemctl restart consul
sudo service consul restart
sudo service consul status