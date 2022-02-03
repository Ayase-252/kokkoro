port=$1
host_name=$2
cf_account_id=$3
cf_token=$4

echo "Starting proxy on Port $port"

read -n 1 -p "Press Y to Confirm" is_confirm

if ["is_confirm" != "Y"]; then
    echo "Aborting"
    exit 1
fi

sudo apt update
sudo apt install shadowsocks-libev

wget https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.1/v2ray-plugin-linux-amd64-v1.3.1.tar.gz
tar zxf v2ray-plugin-linux-amd64-v1.3.1.tar.gz
sudo mv v2ray-plugin_linux_amd64 /usr/bin/v2ray-plugin
rm v2ray-plugin-linux-amd64-v1.3.1.tar.gz

sudo apt install nginx

curl https://get.acme.sh | sh
export CF_Token=$cf_token
export CF_Account_ID=$cf_account_id
# Need to register an account 

source ~/.bashrc
acme.sh --issue --dns dns_cf -d $host_name
acme.sh --install-cert -d $host_name \
--key-file /etc/nginx/certs/$host_name.key \
--fullchain-file /etc/nginx/certs/$host_name.cer \
--reloadcmd "sudo systemctl restart nginx"

echo "
server {
  listen  443 ssl;
  ssl on;
  ssl_certificate       /etc/nginx/certs/$host_name.cer;
  ssl_certificate_key   /etc/nginx/certs/$host_name.key;
  ssl_protocols         TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers           HIGH:!aNULL:!MD5;
  server_name           $host_name;
  root                  /var/www/html;

  location /index {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
}
" > /etc/nginx/conf.d/$host_name.conf

password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

echo "Your password is $password, please remember"

echo "
{
    \"server\":\"127.0.0.1\",
    \"server_port\":$port,
    \"password\":\"$password\",
    \"timeout\":60,
    \"method\":\"chacha20-ietf-poly1305\",
    \"mode\":\"tcp_and_udp\",
    \"fast_open\":false,
    \"plugin\":\"v2ray-plugin\",
    \"plugin_opts\":\"server;path=/index\"
}
" > /etc/shadowsocks-libev/config.json

sudo systemctl restart shadowsocks-libev
sudo systemctl restart nginx

echo "Server started on ${host_name}:${port}. Access with TLS/Websocket, with parameter server;path=/index"
