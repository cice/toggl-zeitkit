require 'active_support/core_ext/hash/keys'

module Toggl
  class Client
    attr_reader :user_agent, :api_key, :workspace_id

    def initialize(user_agent, api_key, workspace_id)
      @user_agent = user_agent
      @api_key = api_key
      @workspace_id = workspace_id
    end

    def get_project(project_id)
      Project.new(self, project_id)
    end

    class << self
      def create
        new ENV['TOGGL_USER_AGENT'], ENV['TOGGL_API_KEY'], ENV['TOGGL_WORKSPACE_ID']
      end
    end
  end

  class Project
    REPORTS_URL = 'https://toggl.com/reports/api/v2/details'

    def initialize(client, project_id)
      @client = client
      @project_id = project_id
    end

    def parse_data(data)
      data.uniq { |a| a['id'] }.map(&:symbolize_keys).map do |a|
        a[:start] = Time.parse a[:start]
        a[:end] = Time.parse a[:end]

        a
      end
    end

    def get_reports(start, finish)
      first = get_report(start, finish)
      data = first['data']
      total_count = first['total_count']
      per_page = first['per_page']

      return parse_data(data) if total_count <= per_page

      # additional pages
      pages = total_count / per_page

      pages.times do |page|
        # + 2 because: 1-based and first page already fetched
        data += get_report(start, finish, page + 2)['data']
      end

      parse_data(data)
    end

    def get_report(start, finish, page = nil)
      params = {
        workspace_id: @client.workspace_id,
        user_agent: @client.user_agent,
        since: format_date(start),
        until: format_date(finish),
        project_ids: @project_id,
        page: page || 1,
      }

      headers = {
        accept: :json,
        params: params,
      }

      response = RestClient::Request.execute(
        method: 'GET',
        url: REPORTS_URL,
        headers: headers,
        user: @client.api_key,
        password: 'api_token',
      )

      JSON.parse response.body
    end

    def format_date(date)
      date.strftime '%Y-%m-%d'
    end

    class << self
      def create
        new Client.create, ENV['TOGGL_PROJECT_ID']
      end
    end
  end
end
