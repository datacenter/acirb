# Overview
ACIrb is a Ruby implementation of the Cisco APIC REST API. It enables direct manipulation of the Management Information Tree (MIT) through the REST API using standard ruby language options, allowing programmatic interaction with APIC to configure all aspects of the fabric. The project aims to be a thin layer over the object model, so creating code is simple. 

# Building
Building is likely something most users won't need to do, however if you are adventurous you can give it a try. It consists of three steps:
1. Get the source code from git
```
git clone https://github.com/datacenter/acirb
```
2. Copy the python model from an APIC
To generate the model, you need a Python meta-model (pysdk). pysdk contains all of the objects in the ACI object model, with properties, attributes, values, validation and relationships, so it makes a good source for generating the model in other languages. You can get the contents from any APIC, and a reference script called **updatepysdk.sh** is included here, where you can simply substitute in the IP address and username for your own, run it, and it will place everything nicely into a pysdk folder sitting next to this README.
3. Generate the ruby model and GEM
At this point you can run **./build.sh** which will kick off **genrubyfrompython.py**, and a bunch of other scripts that generate the Ruby GEM and install it on your system.

# Build Requirements
To use the contents of pysdk, you'll need PyAML. You can get this using pip, easy_install or equivalent
   pip install pyaml

To build some of the ruby dependencies, you'll need the ruby development files in your system. For debian/ubuntu based systems:
    apt-get install ruby-dev

# Installation
When build.sh is run it will build the GEM and install it, however it's probably simpler to just install the pre-built gem, as shown here:

   gem install acirb-version.gem

# Tests
The spec folder contains a number of automated tests to do basic sanity testing of various functions. This can be invoked using typical rspec calls, however a few environment variables must be set pointing to the APIC for the spec_basic.rb suite of tests.

   export APIC_URI='https://apic'
   export APIC_USERNAME='admin'
   export APIC_PASSWORD='password'
   rspec -Ilib -fd spec/*.rb
