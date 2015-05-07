require 'restclient'
require 'rexml/document'
require 'json'

# rubocop:disable ClassLength
module ACIrb
  # A generic managed object class
  class MO
    # Class variable properties
    class << self
      # for class variables
      attr_reader :prefix, :class_name, :child_classes, :props,
                  :naming_props, :prefixes, :ruby_class, :containers
    end

    # for instance variables
    attr_reader :children, :attributes
    attr_accessor :parent

    def prefixes
      self.class.prefixes
    end

    def child_classes
      self.class.child_classes
    end

    def containers
      self.class.containers
    end

    def naming_props
      self.class.naming_props
    end

    def props
      self.class.props
    end

    def class_name
      self.class.class_name
    end

    def ruby_class
      self.class.ruby_class
    end

    def initialize(create_parent, create_attr = {})
      @attributes = {}
      props.each do |prop|
        @attributes[prop.to_s] = ''
      end
      @children = []

      if create_parent.nil?
        @parent = nil
      else
        @parent = create_parent
        @parent.add_child(self)
      end

      # for performance reasons, do not use set_prop here
      # and build the dn string after all attributes are set
      create_attr.each do |k, v|
        @attributes[k.to_s] = v
      end
      @attributes['dn'] = build_dn
    end

    def add_child(child)
      unless child.containers.include?(ruby_class)
        fail child.class.to_s + ' cannot be child of ' + self.class.to_s
      end
      @children.each do |mo|
        return nil if mo.dn == child.dn
      end
      @children.push(child)
      child.parent = self
    end

    def set_prop(key, val)
      key = key.to_s
      val = val.to_s
      return if key == 'dn' || key == 'rn'
      @attributes[key] = val
      if naming_props.include? key
        dn_str = build_dn
        @attributes['dn'] = dn_str
      end
    end

    def root
      p = self
      p = p.parent until p.parent.nil?
      p
    end

    def to_xml
      # TODO: Use nokogiri here
      #   https://github.com/sparklemotion/nokogiri/wiki/Cheat-sheet
      x = REXML::Element.new mo_type.to_s
      @attributes.each do |key, value|
        x.attributes[key.to_s] = value if value.to_s != ''
      end
      @children.each do |child|
        x.add_element(child.to_xml)
      end
      x
    end

    def to_hash
      h = {}
      h[mo_type.to_s] = {}
      h[mo_type.to_s]['attributes'] = @attributes
      h[mo_type.to_s]['attributes']['dn'] = dn
      h[mo_type.to_s]['children'] = [] if children.length > 0
      @children.each do |child|
        h[mo_type.to_s]['children'].push(child.to_hash)
      end
      h
    end

    def to_json
      JSON.dump(to_hash)
    end

    def create(restclient)
      @attributes['status'] = 'created,modified'
      restclient.post(data: self,
                      url: "/api/mo/#{dn}.#{restclient.format}")
    end

    def destroy(restclient)
      @attributes['status'] = 'deleted'
      restclient.post(data: self,
                      url: "/api/mo/#{dn}.#{restclient.format}")
    end

    def exists(restclient, recurse = false)
      options = {}
      options[:subtree] = 'full' if recurse
      if restclient.lookupByDn(dn, options)
        if recurse == true
          children.each do |child|
            unless child.exists(restclient, recurse = true)
              return false
            end
          end
        end
        return true
      else
        return false
      end
    end

    def build_dn
      if @parent.nil?
        return rn
      else
        parent_dn = '' << @parent.dn
        if parent_dn == ''
          return rn
        else
          parent_dn << '/'
          parent_dn << rn
          return parent_dn
        end
      end
    end

    def mo_type
      self.class.class_name.delete('.')
    end

    def to_s
      def hash_to_table(h)
        len = h.keys.map(&:length).max
        ret = []
        h.each do |k, v|
          ret.push(('%' + len.to_s + 's: %s') % [k.to_s, v.to_s])
        end
        ret
      end
      header_table = hash_to_table(
        'Class' => class_name,
      )
      attribute_table = hash_to_table(attributes)
      header_table.push(attribute_table)
      header_table.join("\n")
    end

    def method_missing(name, *args, &block)
      lookup_name = name.to_s
      return @attributes[lookup_name] if @attributes.include? lookup_name
      child_matches = []
      @children.each do |child|
        child_matches.push(child) if child.class.prefix.sub('-', '') == lookup_name
      end
      return child_matches if child_matches.length > 0
      super
    end
  end
end
