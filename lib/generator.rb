require 'config'
require 'rounding'

class Generator
  attr_reader :toggl_entries, :trello_actions

  def initialize(toggl_entries, trello_actions, tz)
    @toggl_entries = toggl_entries.sort_by do |entry|
      entry[:start]
    end
    @trello_actions = trello_actions
    @tz = tz
  end

  def generate_descriptions
    cards = []

    @toggl_entries.each do |entry|
      day = entry[:start].in_time_zone(@tz).midnight
      days_cards = @trello_actions.select do |action|
        action.date.in_time_zone(@tz).midnight == day
      end
      if days_cards.any?
        cards = days_cards
      else
        days_cards = cards
      end

      entry[:card_names] = days_cards.map {|c| '* ' + c.data['card']['name']}.uniq

      if entry[:card_names].blank?
        entry[:card_names] = [entry[:description]]
      end
    end
  end

  def group_by_day
    @toggl_entries.group_by do |entry|
      entry[:start].in_time_zone(@tz).midnight
    end
  end

  def create_worklogs
    generate_descriptions

    group_by_day.map do |(day, entries)|
      card_names = entries.sum([]) { |e| e[:card_names] || [] }.uniq

      worklog = Zeitkit::Worklog.new
      worklog.description = card_names * "\n"

      entries.each do |entry|
        start = entry[:start].floor_to 5.minutes
        finish = entry[:end].ceil_to 5.minutes
        worklog.add_timeframe start, finish
      end

      worklog
    end
  end

  def submit
    worklogs = create_worklogs
    project = Zeitkit::Project.create

    worklogs.each do |w|
      project.submit_worklog! w
    end
  end

  class << self
    def create_month(y, m)
      create(Date.new(y, m, 1), Date.new(y, m, -1))
    end

    def create(start, finish)
      trello = TrelloClient.create
      toggl = Toggl::Project.create

      new toggl.get_reports(start, finish), trello.get_all_actions(start), ENV['TZ']
    end
  end
end
