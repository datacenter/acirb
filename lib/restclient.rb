require 'httpclient'
require 'openssl'
require 'nokogiri'
require 'json'
# require 'uri'

# rubocop:disable ClassLength
module ACIrb
  # REST client end point implementation

  class RestClient
    attr_accessor :format, :user, :password, :baseurl, :debug, :refresh_time
    attr_reader :auth_cookie
    # Desc: initialize a rest client
    # Returns: does not return anything, but will raise an exception
    #   if authentication fails
    # Parameters: accepts a hash of options:
    #   url : string. URL of APIC
    #   user : string. User ID for authentication
    #   password : string. Password for authentication
    #   debug : true or false. Flag for enabling verbose REST output
    #   format : 'xml' or 'json'. Defaults to xml
    #   verify : true or false. verify the SSL certificate. Defaults to disabled
    def initialize(options = {})
      uri = URI.parse(options[:url])
      @baseurl = '%s://%s' % [uri.scheme, uri.host]
      @format = options[:format] ? options[:format] : 'xml'

      @user = options[:user]
      @password = options[:password]

      @client = HTTPClient.new

      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE \
        unless options[:verify] && uri.scheme == 'https'

      @debug = options[:debug]

      @auth_cookie = ''

      authenticate if @user && @password
    end

    # Desc: authenticates the REST session with the APIC and receives an
    #   auth_cookie/token
    # Returns: does not return anything, but will raise an exception if
    #   authentication fails
    # Parameters: does not accept any parameters
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
      fail 'Authentication error(%s): %s' % [doc.at_css('error')['code'], doc.at_css('error')['text']] \
        if doc.at_css('error')
      @auth_cookie = doc.at_css('aaaLogin')['token']
      @refresh_time = doc.at_css('aaaLogin')['refreshTimeoutSeconds']
    end

    def refresh_session
      get_url = URI.encode(@baseurl.to_s + '/api/mo/aaaRefresh.xml')
      puts 'GET REQUEST', get_url if @debug
      response = @client.get(get_url)
      puts 'GET RESPONSE: ', response.body if @debug
      doc = Nokogiri::XML(response.body)
      fail 'Authentication error(%s): %s' % [doc.at_css('error')['code'], doc.at_css('error')['text']] \
        if doc.at_css('error')
      @auth_cookie = doc.at_css('aaaLogin')['token']
      @refresh_time = doc.at_css('aaaLogin')['refreshTimeoutSeconds']
    end

    # Desc: Perform a Net::HTTP::Post to the REST interface with the
    #   parameters provided
    # Returns: an array of managed object containing the parsed result
    # Parameters: a single hash array is accepted, with the following keys:
    #   data : This is a string containing the data to be posted. This
    #      should be well formed XML that the APIC REST interface can interpret.
    #      No validation is done
    #   url : this is the path to the REST interface method being
    #      utilized, typicalliy /api/mo/.xml

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

    # Desc: Perform a Net::HTTP::Get to the REST interface with the
    #   parameters provided
    # Returns: an array of managed object containing the parsed result
    # Parameters: a single hash array is accepted, with the following keys:
    #   url : this is the path to the REST interface method being utilized,
    #     typicalliy /api/mo/.xml with some parameters

    def get(options)
      get_url = URI.encode(@baseurl.to_s + options[:url].to_s)

      puts 'GET REQUEST', get_url if @debug
      response = @client.get(get_url)
      puts 'GET RESPONSE: ', response.body if @debug

      parse_response(response)
    end

    def parse_error(doc)
      if format == 'xml'
        fail 'Error response from APIC (%s): "%s"' % \
          [doc.at_css('error')['code'], doc.at_css('error')['text']] \
          if doc.at_css('error')
      elsif format == 'json'
        fail 'Error response from APIC (%s): "%s"' % \
          [doc['imdata'][0]['error']['attributes']['code'].to_s, \
           doc['imdata'][0]['error']['attributes']['text'].to_s] \
           if doc['imdata'].length > 0 && doc['imdata'][0].include?('error')
      end
    end

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

    def query(query)
      query_uri = query.uri(@format)
      get(url: query_uri)
    end

    # Desc: A helper function that will lookup a given DN via the
    #   APIC REST interface
    # Returns: Returns Mo for match if one exists, otherwise nil
    # Parameters:
    #   dn : string. the distinguished name to query
    #   options : hash. set query parameters

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

    def lookupByClass(cls, options = {})
      subtree = options[:subtree]
      cls_query = ACIrb::ClassQuery.new(cls)
      cls_query.subtree = subtree
      query(cls_query)
    end
  end
end
