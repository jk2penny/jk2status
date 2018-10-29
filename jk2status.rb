require 'open-uri'
require 'discordrb'
require 'json'
require 'mysql2'
require 'pp'

BOT = Discordrb::Bot.new token: ENV["DISCORD_BOT_TOKEN"]

MYSQL = Mysql2::Client.new(:host => "localhost", :username => ENV["JK2_DB_USER"], :password => ENV["JK2_DB_PASSWORD"])

SERVERS = [
  {name: "denver",  ip: "104.219.169.154"},
  {name: "texas",   ip: "96.126.127.20"},
  {name: "iowa",    ip: "35.225.136.229"},
  {name: "cali",    ip: "35.235.74.142"},
  {name: "chicago", ip: "74.91.115.117"},
  {name: "japan",   ip: "139.162.124.210"},
]

GAMEDIG = "gamedig --type quake3 --port %s --host %s"

STATUS = "493255398795509761"

STATS_WINRATE = <<-EOS
SELECT
    name,
    count(matchID) games,
    sum(winOrLose) wins,
    count(matchID) - sum(winOrLose) losses,
    round(sum(winOrLose) / count(matchID) * 100, 2) winrate 
FROM jk2.Matches
INNER JOIN jk2.Stats ON jk2.Matches.﻿ID = jk2.Stats.matchID && (jk2.Matches.captainBLUE = jk2.Stats.name OR jk2.Matches.captainRED = jk2.Stats.name)
GROUP BY name
ORDER BY games DESC, winrate DESC
EOS

STATS_CAPPERS = <<-EOS
SELECT 
    name,
    sum(flagGrabs) totalFlagGrabs,
    sum(captures) totalCaptures,
    round(sum(TIME_TO_SEC(flagHold)) / sum(flagGrabs), 2) AS avgFlagHold,
    round(sum(captures) / sum(flagGrabs) * 100, 2) ratingConversion,
    count(matchID) games
FROM jk2.Stats GROUP BY name HAVING sum(captures) > 0 ORDER BY avgFlagHold DESC
LIMIT 15
EOS

STATS_RETURNERS = <<-EOS
SELECT 
    name,
    round(avg(rets), 2) avgRets,
    round(avg(baseCleans), 2) avgBC,
    round(avg(frags), 2) avgFrags,
    sum(duration) duration,
    round((sum(rets)*0.70 + sum(baseCleans)*0.15 + sum(frags)*0.15) / sum(duration) * 100, 2) rating,
    count(matchID) games
FROM jk2.Stats GROUP BY name ORDER BY rating DESC
LIMIT 15
EOS

BOT.message(with_text: '!status') do |event|
  buffer = "```"

  SERVERS.each do |server|
    server_refresh(server)

    buffer += server[:name].ljust(8, ' ')
    buffer += ": "
    if server[:total_players] > 0
      buffer += server[:total_players].to_s.ljust(2, ' ')
      buffer += " pogs\n"
    else
      buffer += "dead game\n"
    end
  end

  buffer += "```"

  BOT.send_message(STATUS, buffer)
end

def server_refresh(server)
    status = `#{sprintf(GAMEDIG, "28070", server[:ip])}`
    data = JSON.parse(status)

    if data["players"] && data["players"].size == 0
      status = `#{sprintf(GAMEDIG, "28071", server[:ip])}`
      data = JSON.parse(status)
    end

    server[:total_players] = data["players"].nil? ? 0 : data["players"].size
    server[:players] = data["players"]

    return data
end

def server_status(server)
  data = server_refresh(server)

  puts "Gamedig status for #{server[:name]}"
  puts "\n"
  puts JSON.pretty_generate(data)
  puts "\n"

  buffer = "Status for #{server[:name]}:\n"
  buffer += "Total players: #{server[:total_players]}\n"

  buffer += "```\n"

  if server[:players] && server[:players].any?
    buffer += "name".ljust(25, ' ')
    buffer += "ping".ljust(8, ' ')
    buffer += "score".ljust(8, ' ')
    buffer += "\n"

    server[:players].each do |player|
      buffer += player["name"][0..25].ljust(25, ' ')
      buffer += player["ping"].to_s.ljust(8, ' ')
      buffer += player["frags"].to_s.ljust(8, ' ')
      buffer += "\n"
    end
  else
    buffer += "dead game"
  end

  buffer += "```"

  return buffer
end

BOT.message(with_text: '!status cali') do |event|
  server = SERVERS.select { |s| s[:name] == "cali" }[0]
  status = server_status(server)
  BOT.send_message(STATUS, status)
end

BOT.message(with_text: '!status iowa') do |event|
  server = SERVERS.select { |s| s[:name] == "iowa" }[0]
  status = server_status(server)
  BOT.send_message(STATUS, status)
end

BOT.message(with_text: '!status chicago') do |event|
  server = SERVERS.select { |s| s[:name] == "chicago" }[0]
  status = server_status(server)
  BOT.send_message(STATUS, status)
end

BOT.message(with_text: '!status denver') do |event|
  server = SERVERS.select { |s| s[:name] == "denver" }[0]
  status = server_status(server)
  BOT.send_message(STATUS, status)
end

BOT.message(with_text: '!status texas') do |event|
  server = SERVERS.select { |s| s[:name] == "texas" }[0]
  status = server_status(server)
  BOT.send_message(STATUS, status)
end

BOT.message(with_text: '!status japan') do |event|
  server = SERVERS.select { |s| s[:name] == "japan" }[0]
  status = server_status(server)
  BOT.send_message(STATUS, status)
end

BOT.message(with_text: '!stats winrate') do |event|
  results = MYSQL.query(STATS_WINRATE)
  buffer = "Stats for winrate:\n"

  buffer += "```\n"

  buffer += "name".ljust(25, ' ')
  buffer += "games".ljust(7, ' ')
  buffer += "wins".ljust(5, ' ')
  buffer += "losses".ljust(7, ' ')
  buffer += "winrate".ljust(7, ' ')
  buffer += "\n"

  results.each do |row|
    buffer += row["name"].ljust(25, ' ')
    buffer += row["games"].to_s.ljust(7, ' ')
    buffer += row["wins"].to_s.ljust(5, ' ')
    buffer += row["losses"].to_s.ljust(7, ' ')
    buffer += row["winrate"].to_s.ljust(7, ' ')
    buffer += "\n"
  end

  buffer += "```\n"
  BOT.send_message(STATUS, buffer)
end

BOT.message(with_text: '!stats cappers') do |event|
  results = MYSQL.query(STATS_CAPPERS)
  buffer = "Stats for cappers:\n"

  buffer += "```\n"

  buffer += "name".ljust(25, ' ')
  buffer += "grabs".to_s.ljust(7, ' ')
  buffer += "caps".to_s.ljust(6, ' ')
  buffer += "hold".to_s.ljust(8, ' ')
  buffer += "rating".to_s.ljust(7, ' ')
  buffer += "games".to_s.ljust(7, ' ')
  buffer += "\n"

  results.each do |row|
    buffer += row["name"].ljust(25, ' ')
    buffer += row["totalFlagGrabs"].to_s.ljust(7, ' ')
    buffer += row["totalCaptures"].to_s.ljust(6, ' ')
    buffer += row["avgFlagHold"].to_s.ljust(8, ' ')
    buffer += row["ratingConversion"].to_s.ljust(7, ' ')
    buffer += row["games"].to_s.ljust(7, ' ')
    buffer += "\n"
  end

  buffer += "```\n"
  BOT.send_message(STATUS, buffer)

end

BOT.message(with_text: '!stats returners') do |event|
  results = MYSQL.query(STATS_RETURNERS)
  buffer = "Stats for returners:\n"

  buffer += "```\n"

  buffer += "name".ljust(25, ' ')
  buffer += "rets".ljust(7, ' ')
  buffer += "bc".ljust(7, ' ')
  buffer += "frags".ljust(7, ' ')
  buffer += "rating".ljust(8, ' ')
  buffer += "games".ljust(8, ' ')
  buffer += "\n"

  results.each do |row|
    buffer += row["name"].ljust(25, ' ')
    buffer += row["avgRets"].to_s.ljust(7, ' ')
    buffer += row["avgBC"].to_s.ljust(7, ' ')
    buffer += row["avgFrags"].to_s.ljust(7, ' ')
    buffer += row["rating"].to_s.ljust(8, ' ')
    buffer += row["games"].to_s.ljust(8, ' ')
    buffer += "\n"
  end

  buffer += "```\n"
  BOT.send_message(STATUS, buffer)

end

BOT.message(with_text: 'gg') do |event|
  BOT.send_message(event.channel.id, "ggtrashbar", true)
end

BOT.message(with_text: 'owned') do |event|
  BOT.send_message(event.channel.id, "owned wolfie gg 10 - 0", true)
end

BOT.run
