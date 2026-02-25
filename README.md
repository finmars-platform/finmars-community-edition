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

To install and to start using Finmars, please refer [Getting Started Community Edition](https://docs.finmars.com/shelves/community-edition).

### Installing the Prerequisites

This guide assumes you are deploying to a Debian-based Linux distribution. It may work on different Linux distributions, 
or other OSes such as macOS, but you may need to change the package names and installation commands.

On the deployment machine, install the prerequisites first:

```bash
# Install Updates
sudo apt update

# Install dependencies
sudo apt install -y ca-certificates curl git gnupg lsb-release make ntp python3-pip unzip zip

# Install docker (or follow https://docs.docker.com/engine/install/)
wget -qO- https://get.docker.com/ | sh
sudo usermod -aG docker $USER
newgrp docker

# Install Python dependencies
pip install -r requirements.txt # (if you get an error, use the --break-system-packages option)
```

### Self-Hosting with Docker Compose

[Install the prerequisites first](#installing-the-prerequisites).

This is the simplest way to get a local Finmars instance running using prebuilt images from
our [Docker](https://hub.docker.com/u/finmars). However, if you want to modify any code, you 
are better off following [Locally Developing Finmars](#locally-developing-finmars).

On Linux or Mac Enviroment (preferable on your Linux Server VM):
```bash
# Clone the Finmars Community Edition repository
git clone https://github.com/finmars-platform/finmars-community-edition.git

# Navigate to the repository
cd finmars-community-edition

# Install envs, certificates, keycloak e.t.c
make install

# Run Finmars
make up
```

### Locally Developing Finmars

[Install the prerequisites first](#installing-the-prerequisites).

This is a more involved way to set up Finmars, by building images directly from source code and enabling hot
reloading code on change. Ideal for developing Finmars locally.

```sh
# 1. Create and enter a directory for Finmars
mkdir finmars && cd finmars

# 2. Clone all repositories
finmars_repos="finmars-community-edition finmars-core finmars-portal finmars-vue-portal finmars-workflow finmars-workflow-portal"
for repo in $finmars_repos; do
    git clone "https://github.com/finmars-platform/$repo.git"
done

# Your directory now should look like this:
ls -1
# finmars-community-edition
# finmars-core
# finmars-portal
# finmars-vue-portal
# finmars-workflow
# finmars-workflow-portal

# 3. Enter the community-edition directory
cd finmars-community-edition

# 4. Build and install envs, certificates, keycloak etc

# When you are asked to select a version, select local
make install

# 5. Run Finmars in development mode, with hot-reload enabled
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


