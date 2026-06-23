#!/bin/bash
sudo apt update -y
sudo apt install apache2 -y

sudo mkdir -p /var/www/html/github-webhooks

echo "<h1>Server Details</h1><p><strong>IP Address:</strong> $(hostname)</p>" > /var/www/html/github-webhooks/index.html

sudo systemctl restart apache2
