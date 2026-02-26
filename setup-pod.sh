#!/usr/bin/env bash

set -euo pipefail

# Basic colors
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}This script must be run as root (use sudo).${NC}"
  exit 1
fi

echo -e "${GREEN}Updating package lists...${NC}"
apt update

echo -e "${GREEN}Installing packages...${NC}"
apt install -y \
  lshw \
  zstd \
  vim \
  jq \
  bc \
  htop \
  tmux

echo -e "${GREEN}Installation completed successfully.${NC}"