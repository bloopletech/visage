#!/usr/bin/env ruby

require_relative 'graph'
require_relative 'patches'
require 'digest/md5'

module Visage
  class Profile
    attr_reader :options, :selected_hosts, :hosts, :selected_metrics, :metrics,
                :name, :errors

    def initialize(opts={})
      @options = opts
      @options[:url] = @options[:profile_name] ? @options[:profile_name].downcase.gsub(/[^\w]+/, "+") : nil
      @errors = {}

      # FIXME: this is nasty
      # FIXME: doesn't work if there's only one host
      # FIXME: add regex matching option
      if @options[:hosts].blank?
        @selected_hosts = []
        @hosts = Collectd::RRDs.hosts
      else
        @selected_hosts = Collectd::RRDs.hosts(:hosts => @options[:hosts])
        @hosts = Collectd::RRDs.hosts - @selected_hosts
      end

      if @options[:metrics].blank?
        @selected_metrics = []
        @metrics = Collectd::RRDs.metrics
      else
        @selected_metrics = Collectd::RRDs.metrics(:metrics => @options[:metrics])
        @metrics = Collectd::RRDs.metrics - @selected_metrics
      end
    end

    # Hashed based access to @options.
    def method_missing(method)
      @options[method]
    end

    def graphs
      graphs = []

      hosts = Collectd::RRDs.hosts(:hosts => @options[:hosts])
      metrics = @options[:metrics]
      hosts.each do |host|
        attrs = {}
        globs = Collectd::RRDs.metrics(:host => host, :metrics => metrics)
        globs.each do |n|
          parts    = n.split('/')
          plugin   = parts[0]
          instance = parts[1]
          attrs[plugin] ||= []
          attrs[plugin] << instance
        end

        attrs.each_pair do |plugin, instances|
          graphs << Graph.new(:host => host,
                                      :plugin => plugin,
                                      :instances => instances)
        end
      end

      graphs
    end

    def private_id
      Digest::MD5.hexdigest("#{@options[:url]}\n")
    end

    private

    def valid_profile_name?
      if @options[:profile_name].blank?
        @errors[:profile_name] = "Profile name must not be blank."
        false
      else
        true
      end
    end

  end
end