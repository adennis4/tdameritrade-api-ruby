require 'tdameritrade/authentication'
require 'tdameritrade/client'
require 'tdameritrade/error'
require 'tdameritrade/version'
require 'tdameritrade/operations/create_watchlist'
require 'tdameritrade/operations/get_instrument_fundamentals'
require 'tdameritrade/operations/get_price_history'
require 'tdameritrade/operations/get_quotes'
require 'tdameritrade/operations/get_watchlists'
require 'tdameritrade/operations/replace_watchlist'
require 'tdameritrade/operations/update_watchlist'

module TDAmeritrade
  class Client
    include TDAmeritrade::Authentication
    include TDAmeritrade::Error

    def initialize(**args)
      @access_token = args[:access_token]
      @refresh_token = args[:refresh_token]
      @client_id = args[:client_id] || Error.gem_error('client_id is required!')
      @redirect_uri = args[:redirect_uri] || Error.gem_error('redirect_uri is required!')
    end

    def get_instrument_fundamentals(symbol)
      Operations::GetInstrumentFundamentals.new(self).call(symbol)
    end

    def get_price_history(symbol, **options)
      Operations::GetPriceHistory.new(self).call(symbol, options)
    end

    def get_quotes(symbols)
      Operations::GetQuotes.new(self).call(symbols: symbols)
    end

    def create_watchlist(account_id, watchlist_name, symbols)
      Operations::CreateWatchlist.new(self).call(account_id, watchlist_name, symbols)
    end

    def get_watchlists(account_id)
      Operations::GetWatchlists.new(self).call(account_id: account_id)
    end

    def replace_watchlist(account_id, watchlist_id, watchlist_name, symbols_to_add=[])
      Operations::ReplaceWatchlist.new(self).call(account_id, watchlist_id, watchlist_name, symbols_to_add)
    end

    def update_watchlist(account_id, watchlist_id, watchlist_name, symbols_to_add=[])
      Operations::UpdateWatchlist.new(self).call(account_id, watchlist_id, watchlist_name, symbols_to_add)
    end
    
    HISTORY_URL='https://apis.tdameritrade.com/apps/100/History'

    def get_transaction_history(account_id, start_date, end_date, type)
      request_params = build_transaction_history_params(account_id, start_date, end_date, type)

      uri = URI.parse HISTORY_URL
      uri.query = URI.encode_www_form(request_params)

      response = HTTParty.get(uri, headers: {'Cookie' => "JSESSIONID=#{@session_id}"}, timeout: 10)
      if response.code != 200
        raise TDAmeritradeApiError, "HTTP response #{response.code}: #{response.body}"
      end

      bp_hash = {"error"=>"failed"}
      result_hash = Hash.from_xml(response.body.to_s)
      if result_hash['amtd']['result'] == 'OK'
        bp_hash = result_hash['amtd']['history']
      end

      bp_hash
    rescue Exception => e
      raise TDAmeritradeApiError, "error in get_positions() - #{e.message}" if !e.is_ctrl_c_exception?
    end
    
    BALANCES_AND_POSITIONS_URL='https://apis.tdameritrade.com/apps/100/BalancesAndPositions'

    # +get_positions+ get account balances
    # +options+ may contain any of the params outlined in the API docs
    # * accountid - one of the account ids returned from the login service
    # * type - type of data to be returned ('b' or 'p')
    # * suppress_quotes - whether or not quotes should be suppressed on the positions (true/false)
    # * alt_balance_format - whether or not the balances response should be returned in alternative format (true/false)
    def get_positions(account_id, options={})
      request_params = build_bp_params(account_id, options)

      uri = URI.parse BALANCES_AND_POSITIONS_URL
      uri.query = URI.encode_www_form(request_params)

      response = HTTParty.get(uri, headers: {'Cookie' => "JSESSIONID=#{@session_id}"}, timeout: 10)
      if response.code != 200
        raise TDAmeritradeApiError, "HTTP response #{response.code}: #{response.body}"
      end

      bp_hash = {"error"=>"failed"}
      result_hash = Hash.from_xml(response.body.to_s)
      if result_hash['amtd']['result'] == 'OK' then
        bp_hash = result_hash['amtd']['positions']
      end

      bp_hash
    rescue Exception => e
      raise TDAmeritradeApiError, "error in get_positions() - #{e.message}" if !e.is_ctrl_c_exception?
    end

    def get_balances(account_id, options={})
      request_params = build_bp_params(account_id, options)

      uri = URI.parse BALANCES_AND_POSITIONS_URL
      uri.query = URI.encode_www_form(request_params)

      response = HTTParty.get(uri, headers: {'Cookie' => "JSESSIONID=#{@session_id}"}, timeout: 10)
      if response.code != 200
        raise TDAmeritradeApiError, "HTTP response #{response.code}: #{response.body}"
      end

      bp_hash = {"error"=>"failed"}
      result_hash = Hash.from_xml(response.body.to_s)

      if result_hash['amtd']['result'] == 'OK' then

        balance = result_hash['amtd']['balance']
        margin_balance = balance['margin_balance'] ? balance['margin_balance']['current'].to_i : 0

        bp_hash = {
          'cash_balance' => balance['cash_balance']['current'].to_i,
          'money_market_balance' => balance['money_market_balance']['current'].to_i,
          'margin_balance' => margin_balance
        }
      end

      bp_hash
    rescue Exception => e
      raise TDAmeritradeApiError, "error in get_balances() - #{e.message}" if !e.is_ctrl_c_exception?
    end

    private

    def build_transaction_history_params(account_id, start_date, end_date, type)
      {
        source: @source_id,
        accountid: account_id,
        startdate: start_date,
        enddate: end_date,
        type: type
      }
    end

    def build_bp_params(account_id, options)
      {source: @source_id, accountid: account_id}.merge(options)
    end
  end
end
