#!/usr/bin/env bash

bundle exec dotenv -f $1 pry -r./lib/config.rb -r./lib/generator.rb
