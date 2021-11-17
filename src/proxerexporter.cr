require "xml"
require "json"
require "crystagiri"
require "http/client"

puts "Please enter your proxer id:"
pid = gets

doc = Crystagiri::HTML.from_url "https://proxer.me/user/#{pid}/anime"
HEADERS = HTTP::Headers.new
HEADERS["X-MAL-CLIENT-ID"] = "usually this would be my mal client id :)"

class Anime
  getter id
  getter name
  getter rating
  property status
  getter progress
  property started = "0000-00-00"
  property finished = "0000-00-00"

  def initialize(@id : String,
                 @name : String,
                 @rating : String,
                 @progress : String)
    @status = "geckw"
  end
end

allAnime = [] of Anime

doc.where_tag("table") { |table|
  break if table.nil?

  status = table.node.children[0].content

  tempAnime = [] of Anime
  rows = table.node.children.map { |c| c.children.skip(1) }
  rows.skip(2).each { |r|
    columns = r.skip(1)
    next if columns.empty?

    name = columns.first.content.strip

    progress = columns.skip(3).first.content.split('/').first.strip

    ratingnode = columns.skip(2).first.children
    rating = "0"
    rating = ratingnode.map { |c| c.attributes[1].content }.count { |c| c.includes? "stern.png" } if ratingnode[0].content != "-"

    id = get_id name

    puts "Fetched info for: \"#{name}\"."

    tempAnime << Anime.new id, name, rating.to_s, progress
  }

  case status
  when "Geschaut"
    tempAnime.each { |a| a.status = "Completed" }
  when "Am Schauen"
    tempAnime.each { |a| a.status = "Watching" }
  when "Wird noch geschaut"
    tempAnime.each { |a| a.status = "Plan to Watch" }
  when "Abgebrochen"
    tempAnime.each { |a| a.status = "Dropped" }
  else
  end

  allAnime = allAnime + tempAnime
}

puts "Fetched #{allAnime.size} in total."

contents = XML.build(indent: "    ") do |xml|
  xml.element("myanimelist") {
    allAnime.each { |a|
      if a.id == "0"
        puts "Skipping entry for #{a.name} because of a missing ID."
        next
      end
      xml.element("anime") do
        xml.element("series_animedb_id") { xml.text a.id }
        xml.element("series_title") { xml.text a.name }
        xml.element("my_watched_episodes") { xml.text a.progress }
        xml.element("my_start_date") { xml.text a.started }
        xml.element("my_finish_date") { xml.text a.finished }
        xml.element("my_score") { xml.text a.rating }
        xml.element("my_status") { xml.text a.status }
      end
    }
  }
end

File.write("#{pid}.xml", contents) unless allAnime.empty?

def get_id(name)
  response = HTTP::Client.get("https://api.myanimelist.net/v2/anime?q=#{name}", headers: HEADERS)

  if response.status_code == 200
    j = JSON.parse(response.body)
    return j["data"][0]["node"]["id"].to_s
  end
  return "0"
end

