require 'simplecov'
SimpleCov.start
require 'acirb'

RSpec.describe 'ACIrb Naming' do
  it 'Verifies simple function of splitting method' do
    dn_str = 'uni'
    parts = ACIrb::Naming.split_dn_str(dn_str)
    expect(parts[0]).to eq('uni')
  end

  it 'Verifies nested function of splitting method' do
    dn_str = 'uni/tn-common/ap-ap/epg-test'
    parts = ACIrb::Naming.split_dn_str(dn_str)
    expect(parts[0]).to eq('uni')
    expect(parts[1]).to eq('tn-common')
    expect(parts[2]).to eq('ap-ap')
    expect(parts[3]).to eq('epg-test')
  end

  it 'Verifies nested function of splitting where an rn is where it doesnt belong'  do
    dn_str = 'uni/tn-common/epg-test'
    parts = ACIrb::Naming.split_dn_str(dn_str)
    expect(parts[0]).to eq('uni')
    expect(parts[1]).to eq('tn-common')
    expect(parts[2]).to eq('epg-test')
  end

  it 'Simple: Creates an Mo from a Dn string' do
    mo = ACIrb::Naming.get_mo_from_dn('uni')
    expect(mo.class_name).to eq('pol.Uni')
  end

  it 'Nested: Creates an Mo from a Dn string' do
    mo = ACIrb::Naming.get_mo_from_dn('uni/tn-common')
    expect(mo.class_name).to eq('fv.Tenant')
    expect(mo.attributes['name']).to eq('common')
  end

  it 'Deep Nested: Creates an Mo from a Dn string' do
    mo = ACIrb::Naming.get_mo_from_dn('uni/tn-common/ap-app1/epg-epg1')
    expect(mo.class_name).to eq('fv.AEPg')
    expect(mo.attributes['name']).to eq('epg1')
  end

  it 'Deeper Nested: Creates an Mo from a Dn string' do
    mo = ACIrb::Naming.get_mo_from_dn('uni/tn-common/ap-app1/epg-epg1/rspathAtt-[test]')
    expect(mo.class_name).to eq('fv.RsPathAtt')
    expect(mo.parent.class_name).to eq('fv.AEPg')
    expect(mo.parent.parent.class_name).to eq('fv.Ap')
    expect(mo.parent.parent.parent.class_name).to eq('fv.Tenant')
    expect(mo.parent.parent.parent.parent.class_name).to eq('pol.Uni')
  end

  it 'Nested: Have a rn where it doesn\'t belong' do
    expect { ACIrb::Naming.get_mo_from_dn('uni/epg-common') }.to raise_error(RuntimeError)
  end

  it 'Complex Dn' do
    dn = 'uni/tn-ASA-F5-TEST/ap-qbo/epg-app/FI_C-qbo-app-compl-G-web-F-Firewall-N-AccessList'
    mo = ACIrb::Naming.get_mo_from_dn(dn)
    expect(mo.dn).to eq(dn)
  end
end
