require 'rest-client'

module Zeitkit
  class Client
    attr_reader :urls

    def initialize(urls, api_key)
      @urls = urls.symbolize_keys
      @api_key = api_key
    end

    def get_project(client_id, team_id)
      Project.new(self, client_id, team_id)
    end

    def get_request_headers
      {
        content_type: :json,
        accept: :json,
        authorization: 'Token ' + @api_key
      }
    end

    class << self
      def create
        new({ worklogs: ENV['ZEITKIT_WORKLOGS_ENDPOINT'] }, ENV['ZEITKIT_AUTH_TOKEN'])
      end
    end
  end

  class Project
    def initialize(client, client_id, team_id)
      @client = client
      @client_id = client_id
      @team_id = team_id
    end

    def submit_worklog!(worklog)
      url = @client.urls[:worklogs]

      RestClient::Request.execute(
        method: 'POST',
        url: url,
        headers: @client.get_request_headers,
        payload: worklog.to_payload(@client_id, @team_id).to_json
      )
    end

    class << self
      def create
        new(Client.create, ENV['ZEITKIT_CLIENT_ID'], ENV['ZEITKIT_TEAM_ID'])
      end
    end
  end

  class Worklog
    attr_reader :timeframes
    attr_accessor :description

    def initialize
      @timeframes = []
    end

    def add_timeframe(start, finish)
      @timeframes << [start, finish]
    end

    def duration
      @timeframes.sum(0) do |(start, finish)|
        finish - start
      end
    end

    def to_payload(client_id, team_id)
      {
        client_id: client_id,
        team_id: team_id,
        description: @description,
        worklogs: @timeframes.map { |(s, e)| [s.to_i, e.to_i] },
      }
    end
  end
end
