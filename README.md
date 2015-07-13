# Overview
ACIrb is a Ruby implementation of the Cisco APIC REST API. It enables direct manipulation of the Management Information Tree (MIT) through the REST API using standard ruby language options, allowing programmatic interaction with APIC to configure all aspects of the fabric. The project aims to be a thin layer over the object model, so creating code is simple. 
# Installation
If you want the simple version, the gem for this is available on rubygems, so you can install via ruby gems. To install the latest version use the below command:
```
gem install acirb
```
If you want or need to install a specific version (such as if you are running APIC 1.0.4o and need to install ACIrb for that version), you can specify the -v tag to select a version of a gem:
```
# Install ACIrb for APIC 1.0.4o
gem install acirb -v 1.0.4.1

# Install ACIrb for APIC 1.1.1j
gem install acirb -v 1.1.1.1
```
If you've checked out this repo and want to install the gem from the repo, you can also install it from a .gem file:
```
gem install acirb-version.gem
```
If you are building from scratch, when build.sh is run it will build the GEM and install it. You can just use **gem install** to install that generated gem 

# Samples
## Querying fabric health score
Querying can be accomplished using the lookupByDn and lookupByClass helper methods, e.g.:
```
require 'acirb'

apicuri = 'https://apic'
username = 'admin'
password = 'password'

rest = ACIrb::RestClient.new(url: apicuri, user: username,
                                 password: password)

health = rest.lookupByDn('topology/HDfabricOverallHealth5min-0',
                         subtree: 'full')
puts health.healthAvg
```
## Creating a new tenant
Object creation is simple -- just build the hierarchy of objects, and call .create to commit the changes:
```
apicuri = 'https://apic'
username = 'admin'
password = 'password'

rest = ACIrb::RestClient.new(url: apicuri, user: username,
                                 password: password)

uni = ACIrb::PolUni.new(nil)
tenant = ACIrb::FvTenant.new(uni, name: 'NewTenant')
tenant.create(rest)
```
## Modifying stuff
You don't always just want to query and create things -- somethings you need to change them. Luckily we can do that too. Let's say that we want to change the description on an EPG. This example will query for an EPG named 'test' in tenant 'test' and application 'test' and change the description on it:
```
apicuri = 'https://apic'
username = 'admin'
password = 'password'

rest = ACIrb::RestClient.new(url: apicuri, user: username,
                                 password: password)

mo = @rest.lookupByDn('uni/tn-test/ap-test/epg-test)
mo.descr = 'Hey look I am a described'
mo.create(@rest)
```
Note that we're using the mo.create() method here. Since APIC generally doesn't discriminate between updates and creations, we use the same API method to do this, so rest assured that when you call mo.create() on something that is already there, it will just make changes to that object. I guess we could add a .modify call to the MO class, but it would just be an alias to .create, and since we are all mature adults, I think we can accept this. If not, please open an issue and tell me why not.

## Deleting stuff
We can use the example above to query for the EPG, and then delete it too, using the mo.destroy() method
```
apicuri = 'https://apic'
username = 'admin'
password = 'password'

rest = ACIrb::RestClient.new(url: apicuri, user: username,
                                 password: password)

mo = @rest.lookupByDn('uni/tn-test/ap-test/epg-test)
mo.destroy(@rest)
```
Just be careful not to delete anything that is super critical, or else your boss will be mad at you

## More examples
For more examples, please check out the [examples](examples) folder
# Building
Building is likely something most users won't need to do, however if you are adventurous you can give it a try. It consists of three steps:

1. Get the source code from git
```
git clone https://github.com/datacenter/acirb
```
2. Copy the python model from an APIC
To generate the model, you need a Python meta-model (pysdk). pysdk contains all of the objects in the ACI object model, with properties, attributes, values, validation and relationships, so it makes a good source for generating the model in other languages. You can get the contents from any APIC, and a reference script called **updatepysdk.sh** is included here, where you can simply substitute in the IP address and username for your own, run it, and it will place everything nicely into a pysdk folder sitting next to this README.
```
./updatepysdk.sh
```
3. Generate the ruby model and GEM

At this point you can run **./build.sh** which will kick off **genrubyfrompython.py**, and a bunch of other scripts that generate the Ruby GEM and install it on your system.
```
./build.sh
````

# Build Requirements
To use the contents of pysdk, you'll need PyAML. You can get this using pip, easy_install or equivalent
```
pip install pyaml
```
To build some of the ruby dependencies, you'll need the ruby development files in your system. For debian/ubuntu based systems:
```
apt-get install ruby-dev
```
# Tests
The spec folder contains a number of automated tests to do basic sanity testing of various functions. This can be invoked using typical rspec calls, however a few environment variables must be set pointing to the APIC for the spec_basic.rb suite of tests.

    export APIC_URI='https://apic'
    export APIC_USERNAME='admin'
    export APIC_PASSWORD='password'
    rspec -Ilib -fd spec/*.rb
