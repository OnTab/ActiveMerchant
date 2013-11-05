module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalPaymentsGateway < Gateway

      TRANSACTION_TYPES = [TYPE_SALE = "Sale",
                           TYPE_REFUND = "Return",
                           TYPE_REPEAT_SALE = "RepeatSale"]

      self.test_url = 'https://certapia.globalpay.com/GlobalPay/'
      #self.live_url = 'https://example.com/live'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['CA']

      self.default_currency = 'CAD'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.globalpaymentsinc.com/USA/merchants/eCommerce.html'

      # The money format
      self.money_format = :dollars

      # The name of the gateway
      self.display_name = 'Global Payments'

      def initialize(options = {})
        requires!(options, :login, :password)
        @username = options[:login]
        @password = options[:password]
        super
      end

      def purchase(money, creditcard, options = {})
        post = { }
        post = create_gp_transact_params(post, TYPE_SALE, money, creditcard, nil, options)
        commit('transact.asmx/ProcessCreditCard?', post)
      end

      def refund(money, authorization, options = {})
        post = { }
        post = create_gp_transact_params(post, TYPE_REFUND, money, nil, authorization, options)
        commit('transact.asmx/ProcessCreditCard?', post)
      end

      def repeat_sale(money, authorization, options = {})
        post = { }
        post = create_gp_transact_params(post, TYPE_REPEAT_SALE, money, nil, authorization, options)
        commit('transact.asmx/ProcessCreditCard?', post)
      end

      def recurring(authorization, options = {})
        repeat_sale(nil, authorization, options)
      end


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
                     :cvv_result => response['GetCVResult'],
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

      def create_gp_transact_params(post, transaction_type, money, creditcard, authorization, options)
        add_transact_type(post, transaction_type)
        add_authorization(post, authorization)
        add_invoice(post, options)
        add_magdata(post, options)
        add_amount(post, money, options)
        add_address(post, creditcard, options)
        add_creditcard(post, creditcard, options)
        add_extradata(post, options)
        post
      end

      def add_auth_token(post)
        post[:GlobalUsername] = @username
        post[:GlobalPassword] = @password
      end

      def add_transact_type(post, transaction_type)
        post[:TransType] = transaction_type
      end


      def add_authorization(post, authorization)
        post[:PNRef] = authorization
      end

      def add_invoice(post, options)
        post[:InvNum] = options[:invoice_number]
      end

      def add_magdata(post, options)
        post[:MagData] = options[:mag_data]
      end

      def add_amount(post, money, options)
        post[:Amount] = amount(money)    #note this is changed to cents!
      end

      def add_address(post, creditcard, options)
        post[:Zip] = ""
        post[:Street] = ""
      end

      def add_creditcard(post, creditcard, options)
        # Values must be defined in request even if not required, so initialize them here
        post[:CardNum] = ""
        post[:ExpDate] = ""
        post[:CVNum] = ""
        post[:NameOnCard] = ""
        unless creditcard.nil?
          post[:CardNum] = creditcard.number
          post[:ExpDate] = creditcard.month.to_s + creditcard.year.to_s[-2,2]
          post[:CVNum] = creditcard.verification_value if creditcard.verification_value?
          post[:NameOnCard] = creditcard.name if creditcard.name?
        end
      end

      def add_extradata(post, options)
        post[:ExtData] = options[:extra_data]
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


    end
  end
end

