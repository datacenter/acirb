#!/bin/bash
. env.sh
rspec -Ilib -fd spec/*.rb
