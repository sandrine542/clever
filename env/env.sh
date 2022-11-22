#!/bin/sh

cat <<EOF >/tomcat/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      }
    ]
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 12345,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": false,
          "path": "/${UUID}-vless"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 12346,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 0
          }
        ],
        "disableInsecureEncryption": true
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": false,
          "path": "/${UUID}-vmess"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF


cat <<EOF >/etc/nginx/conf.d/tomcat.conf
server {
  listen       ${Port} default_server;
  listen       [::]:${Port};

  resolver 8.8.8.8:53;
  location / {
    proxy_pass https://${ProxySite};
    proxy_ssl_server_name on;
    proxy_redirect off;
    sub_filter_once off;
    sub_filter ${ProxySite} \$server_name;
    proxy_http_version 1.1;
    proxy_set_header Host ${ProxySite};
    proxy_set_header Connection "";
    proxy_set_header Referer \$http_referer;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header User-Agent \$http_user_agent;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
  }
  
  location = /${UUID}-vless {
    if (\$http_upgrade != "websocket") { 
        return 404;
    }
    proxy_redirect off;
    proxy_pass http://127.0.0.1:12345;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$http_host;
  }

  location = /${UUID}-vmess {
    if (\$http_upgrade != "websocket") { 
        return 404;
    }
    proxy_redirect off;
    proxy_pass http://127.0.0.1:12346;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$http_host;
  }
}
EOF
