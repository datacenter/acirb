require 'httpclient'
require 'openssl'
require 'nokogiri'
require 'json'
# require 'uri'

# rubocop:disable ClassLength
module ACIrb
  # REST client end point implementation

  class RestClient
    attr_accessor :format, :user, :password, :baseurl, :debug, :verify
    attr_reader :auth_cookie, :refresh_time

    class ApicAuthenticationError < StandardError
    end

    class ApicErrorResponse < StandardError
    end

    # Public: Initializes and establishes an authenticated session with APIC
    #         REST endpoint
    #
    # options - Hash options used to specify connectivity
    #           attributes (default: {}):
    #
    #           :url - string URL of APIC, e.g., https://apic (required)
    #           :user - string containing User ID for authentication (required)
    #           :password - string containing Password for
    #                       authentication (required)
    #           :debug - boolean true or false for including verbose REST output
    #                    (default: false)
    #           :format - string 'xml' or 'json' specifying the format to use
    #                     for messaging to APIC. (default: xml)
    #           :verify - boolean true or false for verifying the SSL
    #                     certificate. (default: false)
    #
    # Examples:
    #    rest = ACIrb::RestClient.new(url: 'https://apic', user: 'admin',
    #                                 password: 'password', format: 'json',
    #                                 debug: false)
    def initialize(options = {})
      uri = URI.parse(options[:url])
      @baseurl = '%s://%s:%s' % [uri.scheme, uri.host, uri.port]
      @format = options[:format] ? options[:format] : 'xml'

      @user = options[:user]
      @password = options[:password]

      @verify = options[:verify]

      @client = HTTPClient.new

      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE \
        unless options[:verify] && uri.scheme == 'https'

      @debug = options[:debug]

      @auth_cookie = ''

      authenticate if @user && @password
    end

    # Public: Authenticates the REST session with APIC
    # Sends a aaaLogin message to APIC and updates the following instance
    # variables:
    #   @auth_cookie - session cookie
    #   @refresh_time - session refresh timeout in seconds
    #
    # Returns nothing.
    def authenticate
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.aaaUser(name: @user, pwd: @password)
      end
      post_url = URI.encode(@baseurl.to_s + '/api/mo/aaaLogin.xml')
      puts 'POST REQUEST', post_url if @debug
      puts 'POST BODY', builder.to_xml if @debug
      response = @client.post(post_url, body: builder.to_xml)
      puts 'POST RESPONSE: ', response.body if @debug
      doc = Nokogiri::XML(response.body)
      fail ApicAuthenticationError, 'Authentication error(%s): %s' % [doc.at_css('error')['code'], doc.at_css('error')['text']] \
        if doc.at_css('error')
      fail ApicErrorResponse, 'Unexpected HTTP Error response code(%s): %s' % [response.code, response.body] if response.code != 200
      @auth_cookie = doc.at_css('aaaLogin')['token']
      @refresh_time = doc.at_css('aaaLogin')['refreshTimeoutSeconds']
    end

    # Public: Refreshes an existing RestClient object session
    # Sends a aaaRefresh message to APIC and updates the following instance
    # variables:
    #   @auth_cookie - session cookie
    #   @refresh_time - session refresh timeout in seconds
    #
    # Returns nothing.
    def refresh_session
      get_url = URI.encode(@baseurl.to_s + '/api/mo/aaaRefresh.xml')
      puts 'GET REQUEST', get_url if @debug
      response = @client.get(get_url)
      puts 'GET RESPONSE: ', response.body if @debug
      doc = Nokogiri::XML(response.body)
      fail ApicAuthenticationError, 'Authentication error(%s): %s' % [doc.at_css('error')['code'], doc.at_css('error')['text']] \
        if doc.at_css('error')
      @auth_cookie = doc.at_css('aaaLogin')['token']
      @refresh_time = doc.at_css('aaaLogin')['refreshTimeoutSeconds']
    end

    # Internal: Posts data to the APIC REST interface
    #
    # options - Hash options for defining post parameters (default: {})
    #           :url - relative URL for request (required)
    #           :data - post payload to be included in the request (required)
    #
    # Returns results of parse_response, which will be the parsed results of
    # the XML or JSON payload represented as ACIrb::MO objects
    def post(options)
      post_url = URI.encode(@baseurl.to_s + options[:url].to_s)

      data = options[:data]
      if @format == 'xml'
        data = data.to_xml
      elsif @format == 'json'
        data = data.to_json
      end

      puts 'POST REQUEST', post_url if @debug
      puts 'POST BODY', data if @debug
      response = @client.post(post_url, body: data)
      puts 'POST RESPONSE: ', response.body if @debug

      parse_response(response)
    end

    # Internal: Queries the APIC REST API for data
    #
    # options - Hash options for defining get parameters (default: {})
    #           :url - relative URL for request (required)
    #
    # Returns results of parse_response, which will be the parsed results of
    # the XML or JSON payload represented as ACIrb::MO objects
    def get(options)
      get_url = URI.encode(@baseurl.to_s + options[:url].to_s)

      puts 'GET REQUEST', get_url if @debug
      response = @client.get(get_url)
      puts 'GET RESPONSE: ', response.body if @debug

      parse_response(response)
    end

    # Internal: Parses for error responses in APIC response payload
    #
    # doc - Nokigiri XML document or Hash array containing well formed
    #       APIC response payload (required)
    def parse_error(doc)
      if format == 'xml'
        fail ApicErrorResponse, 'Error response from APIC (%s): "%s"' % \
          [doc.at_css('error')['code'], doc.at_css('error')['text']] \
          if doc.at_css('error')
      elsif format == 'json'
        fail ApicErrorResponse, 'Error response from APIC (%s): "%s"' % \
          [doc['imdata'][0]['error']['attributes']['code'].to_s, \
           doc['imdata'][0]['error']['attributes']['text'].to_s] \
           if doc['imdata'].length > 0 && doc['imdata'][0].include?('error')
      end
    end

    # Internal: Parses APIC response payload into ACIrb::MO objects
    #
    # response - string containing the XML or JSON payload that will be
    #            parsed according to the format defined at instance creation
    #            (required)
    def parse_response(response)
      if format == 'xml'
        xml_data = response.body
        doc = Nokogiri::XML(xml_data)

        parse_error(doc)

        mos = []
        doc.root.elements.each do |xml_obj|
          mo = ACIrb::Loader.load_xml(xml_obj)
          mos.push(mo)
        end

        return mos

      elsif format == 'json'
        json_data = response.body
        doc = JSON.parse(json_data)

        parse_error(doc)

        mos = []
        doc['imdata'].each do |json_obj|
          mo = ACIrb::Loader.load_json(json_obj)
          mos.push(mo)
        end

        return mos
      end
    end

    # Public: Sends a query to APIC and returns the matching MO objects
    #
    # query_obj - ACIrb::Query object, typically either ACIrb::DnQuery or
    #             ACIrb::ClassQuery which contains the query that will be issued
    #             (required)
    #
    # Examples
    #    dn_query = ACIrb::DnQuery.new('uni/tn-common')
    #    dn_query.subtree = 'full'
    #    mos = rest.query(dn_query)
    #
    # Returns array of ACIrb::MO objects for the query
    def query(query_obj)
      query_uri = query_obj.uri(@format)
      get(url: query_uri)
    end

    # Public: Sends an event subscription query to APIC
    #
    # query_obj - ACIrb::Query object, typically either ACIrb::DnQuery or
    #             ACIrb::ClassQuery which contains the query that will be
    #             issued. This query will have the .subscribe property set
    #             to "yes" as part of the subscription process (required)
    #
    # Examples
    #    # subscribe to all changes on fvCEp end points on fabric
    #    # but restrict the results of the query to only include 1
    #    # as to reduce the initial subscription time
    #    class_query = ACIrb::ClassQuery.new('fvCEp')
    #    class_query.page_size = '1'
    #    class_query.page = '0'
    #    subscription_id = rest.subscribe(class_query)
    #
    # Returns the subscription ID for the newly registered subscription
    def subscribe(query_obj)
      query_obj.subscribe = 'yes'
      query_uri = query_obj.uri(@format)

      get_url = URI.encode(@baseurl.to_s + query_uri.to_s)

      puts 'GET REQUEST', get_url if @debug
      response = @client.get(get_url)
      puts 'GET RESPONSE: ', response.body if @debug

      if format == 'xml'
        xml_data = response.body
        doc = Nokogiri::XML(xml_data)
        parse_error(doc)
        subscriptionId = doc.at_css('imdata')['subscriptionId']
      elsif format == 'json'
        json_data = response.body
        doc = JSON.parse(json_data)
        parse_error(doc)
        subscriptionId = doc['subscriptionId']
      end

      subscriptionId
    end

    # Public: Refreshes an existing subscription query
    #
    # subscription_id - string containing the subscription ID for a previously
    #                   subscribed to query
    #
    # Examples
    #    class_query = ACIrb::ClassQuery.new('fvCEp')
    #    class_query.page_size = '1'
    #    class_query.page = '0'
    #    subscription_id = rest.subscribe(class_query)
    #    sleep(50)
    #    rest.refresh_subscription(subcription_id)
    #
    # Returns nothing.
    def refresh_subscription(subscription_id)
      query_uri = '/api/subscriptionRefresh.%s?id=%s' % [@format, subscription_id]
      get(url: query_uri)
    end

    # Public: Helper function that performs a simple lookup on a Dn
    #
    # dn - string containing distinguished name for the object to query
    #      (required)
    # options - Hash options for defining query options (default: {})
    #           :subtree - specifies the subtree query options, which can be
    #                      children, full or self
    # Examples
    #    mo = rest.lookupByDn('uni/tn-common', subtree: 'full')
    #
    # Returns a single ACIrb::MO object or nil if no response for the query
    # is received
    def lookupByDn(dn, options = {})
      subtree = options[:subtree]
      dn_query = ACIrb::DnQuery.new(dn)
      dn_query.subtree = subtree

      mos = query(dn_query)
      if mos.length == 1
        return mos[0]
      else
        return nil
      end
    end

    # Public: Helper function that performs a simple lookup on a Class
    #
    # cls - string containing the class name to query (required)
    # options - Hash options for defining query options (default: {})
    #           :subtree - specifies the subtree query options, which can be
    #                      children, full or self
    # Examples
    #    # return all L1 physical interfaces on the fabric with complete subtree
    #    mo = rest.lookupByClass('l1PhysIf', subtree: 'full')
    #
    # Returns an array of ACIrb::MO objects for the query
    def lookupByClass(cls, options = {})
      subtree = options[:subtree]
      cls_query = ACIrb::ClassQuery.new(cls)
      cls_query.subtree = subtree
      query(cls_query)
    end
  end
end
