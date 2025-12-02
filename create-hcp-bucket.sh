#!/bin/bash
# Script to create HCP Packer bucket via HCP CLI
# Make sure you're authenticated: hcp auth login

hcp packer buckets create ubuntu-golden-image \
  --description "Ubuntu Golden Image for AWS" \
  --labels os=ubuntu,managed-by=packer

