#!/bin/bash
echo 'Generating ruby model'
python genrubyfrompy.py
echo 'Building gem'
gem build acirb.spec
echo 'Installing gem'
version=$(ruby -e "require './lib/version'; puts ACIrb::VERSION")
sudo gem install --no-ri --no-rdoc acirb-${version}.gem
