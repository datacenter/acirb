# EPG BD and Subnet relationship mapper
# Will query for all EPGs in the fabric, and find the associated BD and subnets
# available in that BD, and then print the results as a JSON document
#
# palesiak@cisco.com
#

require 'acirb'
require 'json'

apicuri = 'https://apic'
username = 'admin'
password = 'password'

def class_query_children(options = {})
  rest = options[:rest]
  cls = options[:cls]
  parent_dn = options[:parent_dn]
  child_class = options[:child_class]

  if parent_dn
    dnq = ACIrb::DnQuery.new(parent_dn)
    dnq.class_filter = cls
    dnq.query_target = 'subtree'
    dnq.subtree = 'children'
    dnq.subtree_class_filter = child_class if child_class
    return rest.query(dnq)
  else
    cq = ACIrb::ClassQuery.new(cls)
    cq.subtree = 'children'
    cq.subtree_class_filter = child_class if child_class
    return rest.query(cq)
  end
end

def find_matching_relation(relation_list, relation_prop, target_list, target_prop)
  matched_targets = []
  relation_list.each do |mo|
    rel_prop = mo.send(relation_prop)
    target_list.each do |targetmo|
      tgt_prop = targetmo.send(target_prop)
      matched_targets.push(targetmo) if rel_prop == tgt_prop
    end
  end
end

rest = ACIrb::RestClient.new(url: apicuri, user: username,
                             password: password)

rest.format = 'json'
tenants = rest.lookupByClass('fvTenant')
aps = rest.lookupByClass('fvAp')

epgs = class_query_children(rest: rest, cls: 'fvAEPg',
                            child_class: 'fvRsBd,tagInst')

bds = class_query_children(rest: rest, cls: 'fvBD', child_class: 'fvSubnet')

epg_array = []
epgs.each do |epg|
  ap = epg.parent
  tenant = ap.parent
  find_matching_relation(epg.rsbd, 'tDn', bds, 'dn').each do |bd|
    epg_hash = {
      'tenant' => tenant.name,
      'ap' => ap.name,
      'epg' => epg.name,
      'bd' => bd.dn
    }
    epg_array.push(epg_hash)
  end
end

puts JSON.pretty_generate(epg_array)
