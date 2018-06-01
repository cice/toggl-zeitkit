require 'trello'

require 'rest-client'

RestClient.log = Logger.new(STDOUT)

class TrelloClient
  def initialize(member_name, board_id)
    @member_name = member_name
    @board_id = board_id
  end

  def member
    @member ||= Trello::Member.find(@member_name)
  end

  def board
    @board ||= Trello::Board.find(@board_id)
  end

  def get_all_actions(since, options = {})
    total = []
    actions, count = get_actions(since, options.merge(page: 0, limit: 1000))
    total += actions

    page = 1
    while count == 1000
      actions, count = get_actions(since, options.merge(page: page, limit: 1000))
      page += 1
      total += actions
    end

    total
  end

  def get_actions(since, options = {})
    options = options.merge({
      filter: ['addMemberToCard', 'updateCheckItemStateOnCard'],
      limit: 1000,
      member: true,
      since: since.iso8601
    })

    actions = board.actions(options)
    count = actions.length
    actions = actions.select do |action|
      action.member_participant && action.member_participant['id'] == member.id || action.member_creator_id == member.id
    end

    [actions, count]
  end

  class << self
    def create
      new(ENV['TRELLO_USER'], ENV['TRELLO_BOARD_ID'])
    end
  end
end
