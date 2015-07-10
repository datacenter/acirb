#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start
require 'acirb'

apicuri = ENV['APIC_URI']
username = ENV['APIC_USERNAME']
password = ENV['APIC_PASSWORD']
# password = 'wrong'

testtenant = 'rubysdktest'
# formats = ['xml', 'json']
formats = %w(xml json)
debug = false

formats.each do |format|
  RSpec.describe 'ACIrb Basic' do
    before(:each) do
      pending 'No apic target defined' unless apicuri && username && password
      @rest = ACIrb::RestClient.new(url: apicuri, user: username, format: format,
                                    password: password, debug: debug)
    end

    it '' + format + ' Creates a tenant named test and verifies its existence' do
      uni = ACIrb::PolUni.new(nil)
      expect(uni.dn).to eq('uni')
      tenant = ACIrb::FvTenant.new(uni, name: testtenant)
      expect(tenant.rn).to eq('tn-' + testtenant)
      expect(tenant.dn).to eq('uni/tn-' + testtenant)
      tenant.create(@rest)
      expect(tenant.exists(@rest, true)).to eq(true)
    end

    it '' + format + ' Performs a lookupByDn on the tenant created' do
      mo = @rest.lookupByDn('uni/tn-' + testtenant, subtree: 'full')
      expect(mo.rn).to eq('tn-' + testtenant)
      expect(mo.dn).to eq('uni/tn-' + testtenant)
    end

    it '' + format + ' Create an app profile under the created tenant' do
      mo = @rest.lookupByDn('uni/tn-' + testtenant, subtree: 'full')
      ap = ACIrb::FvAp.new(mo, name: 'app1')
      ap.create(@rest)
      expect(ap.exists(@rest, true)).to eq(true)
    end

    it '' + format + ' Create an EPG profile under the app profile' do
      mo = @rest.lookupByDn('uni/tn-' + testtenant, subtree: 'full')
      ap = ACIrb::FvAp.new(mo, name: 'app1')
      epg = ACIrb::FvAEPg.new(ap, name: 'epg1')
      ap.create(@rest)
      expect(ap.exists(@rest, true)).to eq(true)
      expect(epg.exists(@rest, true)).to eq(true)
    end

    it '' + format + ' Look up the EPG' do
      mo = @rest.lookupByDn('uni/tn-%s/ap-%s/epg-%s' % [testtenant, 'app1', 'epg1'], subtree: 'full')
      expect(mo.rn).to eq('epg-epg1')
      expect(mo.dn).to eq('uni/tn-%s/ap-%s/epg-%s' % [testtenant, 'app1', 'epg1'])
    end

    it '' + format + ' Modify the description of an EPG' do
      descr = 'This is a new description'
      mo = @rest.lookupByDn('uni/tn-%s/ap-%s/epg-%s' % [testtenant, 'app1', 'epg1'], subtree: 'full')
      mo.descr = descr
      mo.create(@rest)
      mo = @rest.lookupByDn('uni/tn-%s/ap-%s/epg-%s' % [testtenant, 'app1', 'epg1'], subtree: 'full')
      expect(mo.descr).to eq(descr)
      expect(mo.rn).to eq('epg-epg1')
      expect(mo.dn).to eq('uni/tn-%s/ap-%s/epg-%s' % [testtenant, 'app1', 'epg1'])
    end

    it '' + format + ' Lookup by class for all EPGs with subtree' do
      @rest.lookupByClass('fvAEPg', subtree: 'full')
    end

    it '' + format + ' Creates a static path binding' do
      epg = @rest.lookupByDn('uni/tn-%s/ap-%s/epg-%s' % [testtenant, 'app1', 'epg1'], subtree: 'full')
      path = @rest.lookupByClass('fabricPathEp')[0]
      pathatt = ACIrb::FvRsPathAtt.new(epg, tDn: path.dn, encap: 'vlan-101')
      pathatt.create(@rest)
    end

    it '' + format + ' Delete static path binding' do
      epg = @rest.lookupByDn('uni/tn-%s/ap-%s/epg-%s' % [testtenant, 'app1', 'epg1'], subtree: 'full')
      dnq = ACIrb::DnQuery.new(epg.dn)
      dnq.class_filter = 'fvRsPathAtt'
      dnq.query_target = 'children'
      pathatt = @rest.query(dnq)[0]
      pathatt.destroy(@rest)
    end

    it '' + format + ' Lookup by class for all Tenants with subtree' do
      mos = @rest.lookupByClass('fvTenant', subtree: 'full')

      count = 0

      mos.each do |mo|
        count += 1 if mo.attributes['name'] == 'common' || \
                      mo.attributes['name'] == 'mgmt' || \
                      mo.attributes['name'] == 'infra'
      end
      expect(count).to eq(3)
    end

    it '' + format + ' Does a complex Dn query' do
      dn = 'uni/tn-ASA-F5-TEST/ap-qbo/epg-app/FI_C-qbo-app-compl-G-web-' \
           'F-Firewall-N-AccessList'
      @rest.lookupByDn(dn, subtree: 'full')
    end

    it '' + format + ' Does a complex class query' do
      dnq = ACIrb::ClassQuery.new('acEntity')
      dnq.subtree = 'children'
      @rest.query(dnq)
    end

    it '' + format + ' Performs multiple queries on the same connection' do
      %w(acEntity fvTenant topSystem).each do |cls|
        dnq = ACIrb::ClassQuery.new(cls)
        dnq.subtree = 'children'
        dnq.page_size = 10
        @rest.query(dnq)
      end
    end

    it '' + format + ' Deletes the tenant created' do
      uni = ACIrb::PolUni.new(nil)
      tenant = ACIrb::FvTenant.new(uni, name: testtenant)
      tenant.destroy(@rest)
      expect(tenant.exists(@rest)).to eq(false)
    end
  end
end
