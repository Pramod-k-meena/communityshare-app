#!/bin/bash

# Help message
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage: ./setup_env.sh"
  echo "This script helps you set up your environment variables securely"
  exit 0
fi

# Check if .env.template exists
if [ ! -f .env.template ]; then
  echo "Error: .env.template file not found!"
  exit 1
fi

# Check if .env already exists
if [ -f .env ]; then
  read -p ".env file already exists. Do you want to overwrite it? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
fi

# Copy the template to .env
cp .env.template .env
echo ".env file created from template."
echo "Please edit the .env file with your actual API keys and sensitive information."
echo "DO NOT commit this file to version control."
