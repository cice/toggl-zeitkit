require 'config'
require 'rounding'

class Generator
  attr_reader :toggl_entries, :trello_actions

  def initialize(toggl_entries, trello_actions, tz, tags = false)
    @toggl_entries = toggl_entries.sort_by do |entry|
      entry[:start]
    end
    @trello_actions = trello_actions
    @tz = tz
    @tags = tags
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

      entry[:card_names] = days_cards.map { |c| '* ' + c.data['card']['name'] }.uniq

      if entry[:card_names].blank?
        entry[:card_names] = [entry[:description]]
      end
    end
  end

  def group_by_day
    @toggl_entries.group_by do |entry|
      [entry[:start].in_time_zone(@tz).midnight]
    end
  end

  def group_by_day_and_tag
    @toggl_entries.group_by do |entry|
      [entry[:start].in_time_zone(@tz).midnight, entry[:tags][0]]
    end
  end

  def create_worklogs
    generate_descriptions

    (@tags ? group_by_day_and_tag : group_by_day).map do |((_, tag), entries)|
      card_names = entries.sum([]) { |e| e[:card_names] || [] }.uniq

      worklog = Zeitkit::Worklog.new
      worklog.description = card_names * "\n"
      worklog.description = "#{tag}\n#{worklog.description}" if @tags

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
    worklogs.each do |w|
      raise "Workflow #{w.timeframes} is missing description" if w.description.blank?
    end
    project = Zeitkit::Project.create

    worklogs.each do |w|
      project.submit_worklog! w
    end
  end

  class << self
    def create_month(y, m)
      create(Date.new(y, m, 1), Date.new(y, m, -1))
    end

    def create_last_week(n = 1)
      a = (n * 7) + 1
      b = 1 + ((n - 1) * 7)
      create(Date.today.beginning_of_week(:monday) - a.days,
        Date.today.beginning_of_week(:monday) - b.days,

      )
    end

    def create(start, finish)
      trello = TrelloClient.create
      toggl = Toggl::Project.create

      new toggl.get_reports(start, finish), trello.get_all_actions(start - 4), ENV['TZ'],
        ENV['WITH_TAGS'] == 'true'
    end
  end
end
