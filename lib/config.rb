# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'bundler/setup'

require 'trello'

Trello.configure do |config|
  config.developer_public_key = ENV['TRELLO_API_KEY']
  config.member_token = ENV['TRELLO_AUTH_TOKEN']
end

require 'trello_client'
require 'zeitkit'
require 'toggl'
