#!/usr/bin/env ruby

module Kernel
  def __DIRNAME__
    File.dirname(File.expand_path(caller.first.match(/^(.*?):/)[1]))
  end
end

class String
  def /(name)
    self + "/" + name
  end
end

require 'sinatra/base'
require 'haml'
require_relative 'visage/profile'
require_relative 'visage/config'
require_relative 'visage/helpers'
require_relative 'visage/config/init'
require_relative 'visage/collectd/rrds'
require_relative 'visage/collectd/json'
require 'yajl/json_gem'

module Visage
  class Visage < Sinatra::Base
    set :public, "#{__DIRNAME__}/visage/public"
    set :views,  "#{__DIRNAME__}/visage/views"

    helpers Sinatra::LinkToHelper
    helpers Sinatra::PageTitleHelper
  end

  class Visage
    get '/' do
      redirect '/profiles'
    end

    get '/profiles/:url' do
      @profile = Profile.get(params[:url])
      raise Sinatra::NotFound unless @profile
      @start = params[:start]
      @finish = params[:finish]
      haml :profile
    end

    get '/profiles' do
      @profiles = Profile.all
      haml :profiles
    end
  end


  class Visage

    get "/builder" do
      if params[:submit] == "create"
        @profile = Profile.new(params)

        if @profile.save
          redirect "/profiles/#{@profile.url}"
        else
          haml :builder
        end
      else
        @profile = Profile.new(params)

        haml :builder
      end
    end

    # infrastructure for embedding
    get '/javascripts/visage.js' do
      javascript = ""
      %w{raphael-min g.raphael g.line mootools-1.2.3-core mootools-1.2.3.1-more graph}.each do |js|
        javascript += File.read(__DIRNAME__ / 'visage/public/javascripts' / "#{js}.js")
      end
      javascript
    end

  end

  class Visage

    # JSON data backend

    # /data/:host/:plugin/:optional_plugin_instance
    get %r{/data/([^/]+)/([^/]+)((/[^/]+)*)} do
      host = params[:captures][0].gsub("\0", "")
      plugin = params[:captures][1].gsub("\0", "")
      plugin_instances = params[:captures][2].gsub("\0", "")

      collectd = CollectdJSON.new(:rrddir => Config.rrddir,
                                  :fallback_colors => Config.fallback_colors)
      json = collectd.json(:host => host,
                           :plugin => plugin,
                           :plugin_instances => plugin_instances,
                           :start => params[:start],
                           :finish => params[:finish],
                           :plugin_colors => Config.plugin_colors)
      # if the request is cross-domain, we need to serve JSONP
      maybe_wrap_with_callback(json)
    end

    get %r{/data/([^/]+)} do
      host = params[:captures][0].gsub("\0", "")
      metrics = Collectd::RRDs.metrics(:host => host)

      json = { host => metrics }.to_json
      maybe_wrap_with_callback(json)
    end

    get %r{/data(/)*} do
      hosts = Collectd::RRDs.hosts
      json = { :hosts => hosts }.to_json
      maybe_wrap_with_callback(json)
    end

    # wraps json with a callback method that JSONP clients can call
    def maybe_wrap_with_callback(json)
      params[:callback] ? params[:callback] + '(' + json + ')' : json
    end

  end
end
