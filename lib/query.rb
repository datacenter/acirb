require 'restclient'

# rubocop:disable ClassLength
# rubocop:disable FormatString
module ACIrb
  # Generic Query Interface
  class Query
    attr_accessor :subtree, :class_filter, :query_target, :subtree_class_filter,
                  :prop_filter, :subtree_prop_filter, :subtree_include,
                  :page_size, :include_prop, :subscribe, :sort_order, :page

    def make_options
      query_params = []

      query_params.push('rsp-subtree=%s' % @subtree) \
        if @subtree
      query_params.push('target-subtree-class=%s' % @class_filter) \
        if @class_filter
      query_params.push('query-target=%s' % @query_target) \
        if @query_target
      query_params.push('rsp-subtree-class=%s' % @subtree_class_filter) \
        if @subtree_class_filter
      query_params.push('query-target-filter=%s' % @prop_filter) \
        if @prop_filter
      query_params.push('rsp-subtree-filter=%s' % @subtree_prop_filter) \
        if @subtree_prop_filter
      query_params.push('rsp-subtree-include=%s' % @subtree_include) \
        if @subtree_include
      query_params.push('page-size=%s' % @page_size) \
        if @page_size
      query_params.push('page=%s' % @page) \
        if @page
      query_params.push('order-by=%s' % @sort_order) \
        if @sort_order
      query_params.push('rsp-prop-include=%s' % @include_prop) \
        if @include_prop
      query_params.push('subscription=yes') \
        if @subscribe

      if query_params.length > 0
        '?' + query_params.join('&')
      else
        ''
      end
    end
  end

  # Dn Query
  class DnQuery < Query
    attr_accessor :dn
    def initialize(dn)
      @dn = dn
    end

    def uri(format)
      '/api/mo/%s.%s%s' % [@dn, format, make_options]
    end
  end

  # Class Query
  class ClassQuery < Query
    attr_accessor :cls
    def initialize(cls)
      @cls = cls
    end

    def uri(format)
      '/api/class/%s.%s%s' % [@cls, format, make_options]
    end
  end
end
