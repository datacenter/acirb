require 'json'
require 'nokogiri'

module ACIrb
  class Loader
    def self.load_xml_str(xml_str)
      doc = Nokogiri::XML(xml_str)
      load_xml(doc.root)
    end

    def self.load_xml(doc)
      dn_str = doc.attributes['dn'].to_s

      parent_mo = ACIrb::Naming.get_mo_from_dn(dn_str).parent if dn_str

      get_mo_from_xml(parent_mo, doc)
    end

    def self.get_mo_from_xml(parent_mo, element)
      class_name = element.name
      unless ACIrb::CLASSMAP.include?(class_name)
        fail 'Could not find class "%s" defined in "%s"' % \
          [class_name, element.to_s]
      end

      mo = ACIrb.const_get(ACIrb::CLASSMAP[class_name])

      create_attr = {}
      element.attributes.each do |k, v|
        create_attr[k.to_s] = v.to_s
      end
      create_attr[:mark_dirty] = false
      mo = mo.new(parent_mo, create_attr)

      element.elements.each do |e|
        mo.add_child(get_mo_from_xml(mo, e))
      end

      mo
    end

    def self.load_json_str(json_data)
      doc = JSON.parse(json_data, symbolize_names: false)
      load_json(doc)
    end

    def self.load_json(doc)
      load_hash(doc)
    end

    def self.load_hash(hash)
      top = hash.keys[0]
      attrib = hash[top]['attributes'] || {}
      dn_str = attrib['dn']

      parent_mo = ACIrb::Naming.get_mo_from_dn(dn_str).parent \
        unless dn_str.nil?

      get_mo_from_hash(parent_mo, hash)
    end

    def self.get_mo_from_hash(parent_mo, hash)
      class_name = hash.keys[0]
      values = hash[class_name]

      unless ACIrb::CLASSMAP.include?(class_name)
        fail 'Could not find class "%s" defined in "%s"' % [class_name, hash]
      end

      mo = ACIrb.const_get(ACIrb::CLASSMAP[class_name])

      create_attr = {}
      (values['attributes'] || {}).each do |propName, propVal|
        create_attr[propName.to_s] = propVal
      end

      create_attr[:mark_dirty] = false
      mo = mo.new(parent_mo, create_attr)

      (values['children'] || []).each do |child|
        mo.add_child(get_mo_from_hash(mo, child))
      end

      mo
    end
  end
end
