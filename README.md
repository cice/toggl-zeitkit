# toggl-zeitkit

Simple tool to fetch entries from Toggl, fill descriptions using Trello actions (matched by date)
and submit as worklogs to Zeitkit

```bash
./bin/console.sh
```

```ruby
generator = Generator.create_month(2018, 5)

generator.submit
```
