module ACIrb
  class Naming
    def self.split_outside_brackets(dn_str, splitChar)
      depth = 0
      place = 0
      last_split = 0
      pieces = []
      while place < dn_str.length
        c = dn_str[place]
        if c == '['
          depth += 1
        elsif c == ']'
          depth -= 1
        end
        if depth == 0 && c == splitChar && place != 0
          pieces.push(dn_str[last_split..place])
          last_split = place + 1
        end
        place += 1
      end
      pieces.push(dn_str[last_split..place - 1]) if place != last_split

      pieces
    end

    def self.strip_last_delimiter(str, delim)
      if str[-1] == delim
        return str[0..-2]
      else
        return str
      end
    end

    def self.strip_outer_brackets(str)
      if str[0] == '[' && str[-1] == ']'
        return str[1..-2]
      else
        return str
      end
    end

    def self.split_dn_str(dn_str)
      rns = []
      split_outside_brackets(dn_str, '/').each do |rn|
        rns.push(strip_last_delimiter(rn, '/'))
      end
      rns
    end

    def self.split_rn_str(rn_str, delims)
      rn_pieces = []
      delims.each_with_index do |(delim, _has_prop), index|
        begin_delim = rn_str.split(delim)

        if index == delims.length - 1
          name_prop = begin_delim[1]
        else
          rn_str = begin_delim[1]
          end_delim = rn_str.split(delims[index + 1][0])
          name_prop = end_delim[0]
        end

        rn_pieces.push(delim)
        rn_pieces.push(name_prop)
      end
      rn_pieces
    end

    def self.get_mo_from_dn(dn_str)
      rns = split_dn_str(dn_str)
      mo = ACIrb::TopRoot.new(nil)
      rns.each do |rn|
        mo = get_mo_from_rn(mo, rn)
      end
      mo
    end

    def self.get_mo_from_rn(parent_mo, rn_str)
      mo = get_class_from_child_prefix(parent_mo, rn_str).new(parent_mo)
      return mo if mo.naming_props.length == 0
      rn_pieces = split_rn_str(rn_str, mo.prefixes)
      rn_values = rn_pieces.values_at(*(1..rn_pieces.length - 1).step(2))
      mo.naming_props.each_with_index do |prop_name, index|
        prop_val = rn_values[index]
        mo.set_prop(prop_name.to_s, strip_outer_brackets(prop_val))
      end
      mo
    end

    def self.match_prefix_in_list(rn_str, prefix_list)
      matches = false
      prefix_match = ''
      prefix_list.each do |prefix|
        if rn_str.start_with?(prefix)
          matches = true
          prefix_match = prefix
          break
        end
      end

      return prefix_match if matches

      return nil
    end

    def self.get_class_from_child_prefix(parent_mo, rn_str)
      prefix_to_class = {}
      parent_mo.child_classes.each do |c|
        cls = ACIrb.const_get(c)
        prefix_to_class[cls.prefix] = cls
      end

      lpm = prefix_to_class.keys.sort_by { |x| -1 * x.length }
      prefix_match = match_prefix_in_list(rn_str, lpm)

      if prefix_match
        return prefix_to_class[prefix_match]
      else
        fail 'Unknown child prefix ' + rn_str + ' in container class ' +
          parent_mo.class.to_s
      end
    end
  end
end
