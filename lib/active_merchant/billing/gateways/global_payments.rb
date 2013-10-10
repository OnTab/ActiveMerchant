module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalPaymentsGateway < Gateway

      self.test_url = 'https://certapia.globalpay.com/GlobalPay/transact.asmx/'
      #self.live_url = 'https://example.com/live'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['CA']

      self.default_currency = 'CAD'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.globalpaymentsinc.com/USA/merchants/eCommerce.html'

      # The money format
      self.money_format = :cents

      # The name of the gateway
      self.display_name = 'Global Payments'

      def initialize(options = {})
        requires!(options, :login, :password)
        @username = options[:login]
        @password = options[:password]
        super
      end

      #def authorize(money, creditcard, options = {})
      #  post = {}
      #  add_invoice(post, options)
      #  add_creditcard(post, creditcard)
      #  add_address(post, creditcard, options)
      #  add_customer_data(post, options)
      #
      #  commit('authonly', money, post)
      #end

      # To create a charge on a card or a token, call
      #
      #   purchase(money, card_hash, { ... })
      #
      # To create a charge on a customer, call
      #
      #   purchase(money, nil, { :customer => PNRef, ... })
      def purchase(money, creditcard, options = {})
        post = create_post_for_purchase(money, creditcard, options)

        if (!creditcard.nil?)
          post[:TransType] = 'Sale'
        elsif !options[:customer].nil?
          post[:TransType] = 'RepeatSale'
        end

        commit('ProcessCreditCard?', post)
      end

      def store(creditcard, options = {})
        post = {}
        post[:TransType] = 'RepeatSale'
      end

      #def capture(money, authorization, options = {})
      #  commit('capture', money, post)
      #end

      #private

      #def add_customer_data(post, options)
      #end

      #def add_invoice(post, options)
      #end

      #def add_creditcard(post, creditcard)
      #end

      #def parse(body)
      #end

      #def commit(action, money, parameters)
      #end

      #def message_from(response)
      #end

      private

      def commit(action, parameters)
        add_auth_token(parameters)
        success = false
        begin
          url = self.test_url + action + post_data(parameters)
          raw_response = ssl_request(:get, url ,nil, {})
          response = parse_xml(raw_response)
          response = response['Response']
          success = (response['Result'] == '0')
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        end

        Response.new(success,
                     success ? "Transaction approved" : response["RespMSG"],
                     response,
                     :authorization => response['PNRef'],
                     :avs_result => response['GetAVSResult'],
                     :cvc_result => response['GetCVResult'],
                     :message => response['Message']
        )

      end

      def parse(body)
        JSON.parse(body)
      end

      # Tokenize and sanitize response for http
      def post_data(params)
        return nil unless params

        params.map do |key, value|
          #next if value.blank?
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end

      def create_post_for_purchase(money, creditcard, options)
        post = { }
        post[:InvNum] = ""
        post[:PNRef] = ""
        post[:ExtData] = ""
        post[:MagData] = ""
        add_amount(post, money, options)
        add_address(post, creditcard, options)
        add_creditcard(post, creditcard, options)
        post
      end

      def create_post_for_auth_or_purchase(money, creditcard, options)
        post = { }
        post[:InvNum] = ""
        post[:PNRef] = ""
        post[:ExtData] = ""
        post[:MagData] = ""
        add_customer(post, options)
        add_amount(post, money, options)
        add_address(post, creditcard, options)
        add_creditcard(post, creditcard, options)
        post
      end

      def add_customer(post, options)
        post[:PNRef] = options[:customer] if options[:customer]
      end

      def add_address(post, creditcard, options)
        post[:Zip] = ""
        post[:Street] = ""
      end

      def add_amount(post, money, options)
        post[:Amount] = amount(money)    #note this is changed to cents!
      end

      def add_auth_token(post)
        post[:GlobalUsername] = @username
        post[:GlobalPassword] = @password
      end

      def add_creditcard(post, creditcard, options)
        # Values must be defined in request even if not required, so initialize them here
        post[:CardNum] = ""
        post[:ExpDate] = ""
        post[:CVNum] = ""
        post[:NameOnCard] = ""
        if !creditcard.nil?
          post[:CardNum] = creditcard.number
          post[:ExpDate] = creditcard.month.to_s + creditcard.year.to_s[-2,2]
          post[:CVNum] = creditcard.verification_value if creditcard.verification_value?
          post[:NameOnCard] = creditcard.name if creditcard.name?
        end
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Global Payments API.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
            "error" => {
                "message" => msg
            }
        }
      end

      def parse_xml(xml)
        xmlHash = Hash.from_xml(xml)
      end


=begin
      self.test_url = 'https://example.com/test'
      self.live_url = 'https://example.com/live'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.example.net/'

      # The name of the gateway
      self.display_name = 'New Gateway'

      def initialize(options = {})
        #requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('authonly', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
      end

      def add_creditcard(post, creditcard)
      end

      def parse(body)
      end

      def commit(action, money, parameters)
      end

      def message_from(response)
      end

      def post_data(action, parameters = {})
      end
=end
    end
  end
end

