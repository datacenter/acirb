# Installation
- Make sure you have ruby gems installed  
  - https://rubygems.org/pages/download
- Next, install dashing following the steps on the website  
  - http://shopify.github.io/dashing/  
  
  Or, just run the following at your terminal.  
  **Note**: you may need to prefix this with sudo depending on your installation  
```
gem install dashing bundle
gem install acirb
```
- Change into the acirb/examples/acidashboard folder  
```
cd acirb/examples/acidashboard
```
- Modify jobs/apic.erb to include your APIC IP address and credentials with an account that can query the objects being polled
```
apicuri = 'https://apic'
username = 'admin'
password = 'password'
```
- Run the "bundle" command
```
bundle
```
# Running
- Run "dashing start" to start the dashboard
```
dashing start
```
- Access your local web server at http://localhost:3030

# More information
Check out http://shopify.github.com/dashing for more information about dashing
