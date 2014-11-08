#!/usr/bin/ruby
require 'rubygems'
require 'bundler/setup'
require 'time'
require 'yaml'
require 'erb'
require 'logger'

require_relative 'plex'
require_relative 'themoviedb'
require_relative 'thetvdb'
require_relative 'mailReport'

# Class for parsing the Plex server for new movies and TV Shows
#
# Author: Brian Stascavage
# Email: brian@stascavage.com
#
class PlexReport
    def initialize
        begin
            $config = YAML.load_file(File.join(File.expand_path(File.dirname(__FILE__)), '../etc/config.yaml') )
        rescue Errno::ENOENT => e
            abort('Configuration file not found.  Exiting...')
        end

        begin
            $logging_path = File.join(File.expand_path(File.dirname(__FILE__)), '../plexReport.log') 
            $logger = Logger.new($logging_path)
        rescue
            abort('Log file not found.  Exiting...')
        end

        $logger.info("Starting up PlexReport")
    end
     
    # Method for retrieving information for all movies for a given period of time. 
    def getMovies
    	moviedb = TheMovieDB.new($config)
	    plex = Plex.new($config)
	    library = plex.get('/library/recentlyAdded')
	    movies = Array.new

	    library['MediaContainer']['Video'].each do | element |
	        if (Time.now.to_i - element['addedAt'].to_i < 604800)
		        plex_movie = plex.get("/library/metadata/#{element['ratingKey']}")['MediaContainer']['Video']
    	        
                # This is some contrivulted logic to strip off the moviedb.org id
                # from the Plex mediadata.  I wish Plex made this information
                # easier to get
                movie_id = plex.get("/library/metadata/#{element['ratingKey']}")['MediaContainer']['Video']['guid'].gsub(/com.plexapp.agents.themoviedb:\/\//, '').gsub(/\?lang=en/, '')

    	        if !movie_id.include?('local') 
	                begin
       	                movie = moviedb.get("movie/#{movie_id}")
                        $logger.info("Reporting Movie: #{movie['title']}")
	                    movies.push({ 
	                        :id       => movie['id'],
	                        :title    => movie['title'],
	                        :image    => "https://image.tmdb.org/t/p/w154#{movie['poster_path']}",
	                        :date     => Time.new(movie['release_date']).year,
	                        :tagline  => movie['tagline'],
	                        :synopsis => movie['overview'],
	                        :runtime  => movie['runtime'],
	                        :imdb     => "http://www.imdb.com/title/#{movie['imdb_id']}"
		            })
    	            rescue
                    end
	            end
            end
    	end
	    return movies.sort_by { |hsh| hsh[:title] }
    end

    # Method for getting new TV episodes for a given time period.  
    # This only returns new episodes, not seasons
    def getNewTVEpisodes
        thetvdb = TheTVDB.new
        plex = Plex.new($config)
        library = plex.get('/library/recentlyAdded')
        tv_episodes = Hash.new
        tv_episodes[:new] = []
        tv_episodes[:seasons] = []

	    library['MediaContainer']['Directory'].each do | element |
            if element['type'].include?('season')
                if (Time.now.to_i - element['addedAt'].to_i < 604800)
                    show_episodes = plex.get("/library/metadata/#{element['parentRatingKey']}/allLeaves")
                    show_id = plex.get(element['parentKey'])['MediaContainer']['Directory']['guid'].gsub(/.*:\/\//, '').gsub(/\?.*/, '')

                    show = thetvdb.get("series/#{show_id}/all/")['Data']
                    $logger.info("Reporting First Episode of #{show['Series']['SeriesName']}")

                    episodes = show['Episode'].sort_by { |hsh| hsh[:FirstAired] }.reverse!

                    episodes.each do | episode |
                        airdate = nil
                        begin
                            airdate = Date.parse(episode['FirstAired'])
                        rescue
                        end
                           
                        if !airdate.nil?
                            if (Time.now.to_i - airdate.to_time.to_i < 604800 && 
                                Time.now.to_i - airdate.to_time.to_i > 0)
                                    tv_episodes[:new].push({
                                        :id             => show_id,
                                        :series_name    => show['Series']['SeriesName'],
                                        :image          => "http://thetvdb.com/banners/#{show['Series']['poster']}",
                                        :network        => show['Series']['Network'],
                                        :imdb           => "http://www.imdb.com/title/#{show['Series']['IMDB_ID']}",
                                        :title          => episode['EpisodeName'],
                                        :episode_number => "S#{episode['SeasonNumber']} E#{episode['EpisodeNumber']}",
                                        :synopsis       => episode['Overview'],
                                        :airdate        => episode['FirstAired']
                                    })
                            else
                                begin
                                    season_mapping = Hash.new
                                    dvd_season_mapping = Hash.new
                                    show['Episode'].each do | episode_count |
                                        season_mapping[episode_count['SeasonNumber']] = 
                                        episode_count['EpisodeNumber']
                                    end
                                    show['Episode'].each do | episode_count |
                                        if !episode_count['DVD_episodenumber'].nil?
                                            dvd_season_mapping[episode_count['SeasonNumber']] =
                                            episode_count['DVD_episodenumber'].to_i
                                        end
                                    end
                                    if (season_mapping[element['index']].to_i == element['leafCount'].to_i ||
                                        dvd_season_mapping[element['index']].to_i == element['leafCount'].to_i )
                                        if !tv_episodes[:new].detect { |f| f[:id].to_i == show_id.to_i }
                                            if tv_episodes[:seasons].detect { |f| f[:id].to_i == show_id.to_i }
                                                tv_episodes[:seasons].each do |x|
                                                    if x[:id] == show_id
                                                        if !x[:season].include? element['index']
                                                            x[:season].push(element['index'])
                                                        end
                                                    end
                                                end
                                            else
                                                tv_episodes[:seasons].push({
                                                    :id             => show_id,
                                                    :series_name    => show['Series']['SeriesName'],
                                                   :image          => "http://thetvdb.com/banners/#{show['Series']['poster']}",
                                                    :season         => [element['index']],
                                                    :network        => show['Series']['Network'],
                                                    :imdb           => "http://www.imdb.com/title/#{show['Series']['IMDB_ID']}",
                                                    :synopsis       => show['Series']['Overview']
                                                })
                                            end
                                        end 
                                    end
                                rescue
                                end           
                            end
                        end
                            
                        $logger.info("Reporting #{show['Series']['SeriesName']} S#{episode['SeasonNumber']} E#{episode['EpisodeNumber']}")
                    end
                end
            end
        end
        tv_episodes[:new].sort_by! { |hsh| hsh[:series_name] }
        tv_episodes[:seasons].sort_by! { |hsh| hsh[:series_name] }
        return tv_episodes 
    end
end

# Main method that starts the report
def main
    test = PlexReport.new
    new_episodes = test.getNewTVEpisodes
    movies = test.getMovies
    
    new_seasons = new_episodes[:seasons]
    new_episodes = new_episodes[:new]

    YAML.load_file(File.join(File.expand_path(File.dirname(__FILE__)), '../etc/config.yaml') )
    template = ERB.new File.new(File.join(File.expand_path(File.dirname(__FILE__)), "../etc/email_body.erb") ).read, nil, "%"
    mail = MailReport.new($config)
    mail.sendMail(template.result(binding))
end
main()