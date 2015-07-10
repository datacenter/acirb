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
                  :naming_props, :prefixes, :ruby_class, :containers,
                  :read_only
    end

    # for instance variables
    attr_reader :children, :attributes
    attr_accessor :parent, :dirty_props

    # Internal: Returns class prefixes
    def prefixes
      self.class.prefixes
    end

    # Internal: Returns child classes
    def child_classes
      self.class.child_classes
    end

    # Internal: Returns containiner classes
    def containers
      self.class.containers
    end

    # Internal: Returns naming properties
    def naming_props
      self.class.naming_props
    end

    # Internal: Returns class properties
    def props
      self.class.props
    end

    # Internal: Returns object class name in APIC package.class notation
    def class_name
      self.class.class_name
    end

    # Internal: Returns class name as ruby package notation
    def ruby_class
      self.class.ruby_class
    end

    # Interal: Returns boolean for if this class is read only
    def read_only
      self.class.read_only
    end

    def initialize(create_parent, create_options = {})
      # always mark dirty unless otherwise specified
      if create_options[:mark_dirty] == false
        mark_dirty = false
      else
        mark_dirty = true
      end
      create_options.delete(:mark_dirty)

      @attributes = {}
      @dirty_props = []
      props.each do |prop, _flags|
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
      create_options.each do |k, v|
        flags = props[k.to_s]
        @attributes[k.to_s] = v.to_s
        @dirty_props.push(k.to_s) if mark_dirty
      end
      @attributes['dn'] = build_dn
      @attributes['rn'] = rn
    end

    # Internal: Adds another MO object as a child to this class
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
      @dirty_props.push(key)

      if naming_props.include? key
        dn_str = build_dn
        @attributes['dn'] = dn_str
        @attributes['rn'] = rn
      end
    end

    def root
      p = self
      p = p.parent until p.parent.nil?
      p
    end

    def get_attributes_to_include
      incl_attr = {}
      @attributes.each do |key, value|
        if props[key.to_s]['isDn'] == true || props[key.to_s]['isRn'] == true || @dirty_props.include?(key) || naming_props.include?(key)
          incl_attr[key.to_s] = value
        end
      end
      incl_attr
    end

    def get_children_to_include
      incl_children = []
      @children.each do |child|
        incl_children.push(child) if child.read_only == false
      end
      incl_children
    end

    def to_xml
      # TODO: Use nokogiri here
      #   https://github.com/sparklemotion/nokogiri/wiki/Cheat-sheet
      x = REXML::Element.new mo_type.to_s

      get_attributes_to_include.each do |key, value|
        x.attributes[key.to_s] = value
      end

      get_children_to_include.each do |child|
        x.add_element(child.to_xml)
      end
      x
    end

    def to_hash
      h = {}
      h[mo_type.to_s] = {}
      h[mo_type.to_s]['attributes'] = {}
      get_attributes_to_include.each do |key, value|
        h[mo_type.to_s]['attributes'][key.to_s] = value
      end
      h[mo_type.to_s]['attributes']['dn'] = dn
      h[mo_type.to_s]['children'] = [] if children.length > 0
      get_children_to_include.each do |child|
        h[mo_type.to_s]['children'].push(child.to_hash)
      end
      h
    end

    def to_json
      JSON.dump(to_hash)
    end

    def create(restclient)
      self.status = 'created,modified'
      restclient.post(data: self,
                      url: "/api/mo/#{dn}.#{restclient.format}")
      @dirty_props = []
    end

    def destroy(restclient)
      self.status = 'deleted'
      restclient.post(data: self,
                      url: "/api/mo/#{dn}.#{restclient.format}")
      @dirty_props = []
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
        'Class' => class_name
      )
      attribute_table = hash_to_table(attributes)
      header_table.push(attribute_table)
      header_table.join("\n")
    end

    def method_missing(name, *args, &block)
      lookup_name = name.to_s
      return @attributes[lookup_name] if @attributes.key? lookup_name
      return set_prop(lookup_name.chomp('='), args[0]) if @attributes.key? lookup_name.chomp('=')
      child_matches = []
      @children.each do |child|
        child_matches.push(child) if child.class.prefix.sub('-', '') == lookup_name
      end
      return child_matches if child_matches.length > 0
      super
    end
  end
end
