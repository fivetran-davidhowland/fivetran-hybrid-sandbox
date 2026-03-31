#!/bin/bash
# Cleanup script for AWS CloudShell
# Run this to free up space before starting fresh

echo "Cleaning up..."

# Remove existing terraform directories
rm -rf ~/fivetran-hybrid-sandbox/.terraform
rm -rf ~/fivetran-hybrid-sandbox
rm -rf ~/.terraform.d

echo "Done. Disk space now:"
df -h /home/cloudshell-user
