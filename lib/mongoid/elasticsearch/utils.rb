# coding: utf-8
# source: https://github.com/karmi/retire/blob/master/lib/tire/utils.rb
require 'uri'

module Mongoid
  module Elasticsearch
    module Utils
      def clean(s)
        s.to_s.gsub(/\P{Word}+/, ' ').gsub(/ +/, ' ').strip
      end

      extend self
    end
  end
end
