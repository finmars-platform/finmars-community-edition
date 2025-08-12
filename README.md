<p align="center">
  <p align="center">
    <a href="https://finmars.io/?utm_source=github&utm_medium=logo" target="_blank">
      <img src="https://github.com/finmars-platform/finmars-core/blob/main/finmars-misc/logo_white_bg.png" alt="Finmars" height="84" />
    </a>
  </p>
</p>

# Finmars Community Edition

Finmars is a **free, open-source** platform to help you manage all your money and investments in one place.  You can pull in data from many accounts and see it together.  
\
It gives you easy tools to create reports, dashboards, and PDFs without writing code.  
You can add extra features from our open marketplace — just pick what you need and plug it in.  
Finmars runs in your web browser, so you and your team can use it from anywhere.

<p align="center">
  <img src="https://github.com/finmars-platform/finmars-core/blob/main/finmars-misc/dashboard.png" width="270" />
  <img src="https://github.com/finmars-platform/finmars-core/blob/main/finmars-misc/report.png" width="270" />
  <img src="https://github.com/finmars-platform/finmars-core/blob/main/finmars-misc/book.png" width="270" />
  <img src="https://github.com/finmars-platform/finmars-core/blob/main/finmars-misc/matrix.png" width="270" />
</p>

## Getting Started

To install and to start using Finmars please refer [Getting Started Community Edition](https://docs.finmars.com/shelves/community-edition).


#### Self-Hosting with Docker Compose
This is the simplest way to get a local Finmars instance running.

On Linux or Mac Enviroment (preferable on your Linux Server VM):
```bash
# Install Updates

sudo apt update

sudo apt install -y ca-certificates curl gnupg lsb-release ntp
wget -qO- https://get.docker.com/ | sh
sudo usermod -aG docker $USER
newgrp docker

sudo apt install make

sudo apt install python3-pip -y
pip install flask


# Clone the Finmars Community Edition repository
git clone https://github.com/finmars-platform/finmars-community-edition.git


# Navigate to the repository
cd finmars-community-edition

# Configure env file
make generate-env

# Configure Certs
make init-cert

# Init Keycloak
make init-keycloak

# Run Finmars
make up

```

## Local Development

```aiignore
# Create venv
python3 -m venv venv

# Activate Venv

source venv/bin/activate

# Install Requirements

pip install -r requirements.txt    
 
# Run Web Form 

python3 init-setup.py

# Check 80 port
```


## License
Please refer to the [LICENSE](https://github.com/finmars-platform/finmars-core/blob/main/LICENSE.md) file for a copy of the license.


## Support
Please use the GitHub issues for support, feature requests and bug reports, or contact us by sending an email to support@finmars.com.


