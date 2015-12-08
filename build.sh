#!/bin/bash
echo "Generating ruby model"
python genrubyfrompy.py || (echo "Failed to generate ruby model"; exit 1)
echo "Building gem"
gem build acirb.spec || (echo "Failed to build gem"; exit 1)
cp -v *.gem gems
version=$(ruby -e "require './lib/acirb/version'; puts ACIrb::VERSION")
echo "Generated gem for $version"
# sudo gem install --no-ri --no-rdoc acirb-${version}.gem
