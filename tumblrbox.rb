#!/usr/bin/env ruby

require 'dropbox_sdk'
require 'tumblr_client'
require 'yaml'

blarg = "droppindabox.tumblr.com"
app_home = File.join ENV['HOME'], 'Dropbox', 'Apps', 'TumblrBox'

configuration = YAML.load_file File.join ENV['HOME'], '.tumblr' rescue {}
Tumblr.configure do |config|
    config.consumer_key = configuration['consumer_key']
    config.consumer_secret = configuration['consumer_secret']
    config.oauth_token = configuration['oauth_token']
    config.oauth_token_secret = configuration['oauth_token_secret']
end

data = YAML.load_file File.join ENV['HOME'], '.tumblrbox' rescue {}

session = DropboxSession.new(data['consumer_key'], data['consumer_secret'])
session.set_request_token(data['request_token'], data['request_secret'])
session.set_access_token(data['access_token'], data['access_secret'])
client = DropboxClient.new(session, :app_folder)
client.file_create_folder 'Posted' rescue {}

tumblr = Tumblr.new

puts "Starting up!"
while true
    files = client.delta
    posts = files['entries'].select {|filename, metadata| !filename.include?('posted')}
    puts "Checking Posts..."
    posts.each { |filename, metadata|
        ending = filename.split(".")[-1]
        file = File.join app_home, filename 
        puts "Uploading post....#{filename}"
        case ending
        when "txt", "text"
            tumblr.text(blarg, :body => File.open(file).read())
        when "jpg", "jpeg", "gif", "png"
            tumblr.photo(blarg, :data => file)
        when "youtube"
            url = File.open(file).read().chomp
            tumblr.video(blarg, :embed => url)
        when "link"
            link = File.open(file).read().chomp
            tumblr.link(blarg, :url => link)
        when 'soundcloud', 'spotify'
            url = File.open(file).read().chomp
            tumblr.audio(blarg, :external_url => url)
        when 'mp3'
            tumblr.audio(blarg, :data => file)
        when 'quote'
            source = metadata['path'].split(".")[0].sub("/", "")
            quote = File.open(file).read().chomp
            tumblr.quote(blarg, :quote => quote, :source => source)
        when 'chat'
            title = metadata['path'].split(".")[0].sub("/", "")
            conversation = File.open(file).read.chomp
            tumblr.chat(blarg, :title => title, :conversation => conversation)
        end
        puts "Update finished. POW! Right in the kisser!"
        client.file_move filename, "/posted/#{filename}"
    }
    puts "Finished Checking..Sleeping for 60"
    sleep(60)
end
