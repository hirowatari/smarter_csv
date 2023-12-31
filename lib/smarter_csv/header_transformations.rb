# frozen_string_literal: true

module SmarterCSV
  class << self
    # this is processing the headers from the input file
    def header_transformations(header_array, options)
      if options[:v2_mode]
        header_transformations_v2(header_array, options)
      else
        header_transformations_v1(header_array, options)
      end
    end

    # ---- V1.x Version: transform the headers that were in the file: ------------------------------------------
    #
    def header_transformations_v1(header_array, options)
      header_array.map!{|x| x.gsub(%r/#{options[:quote_char]}/, '')}
      header_array.map!{|x| x.strip} if options[:strip_whitespace]

      unless options[:keep_original_headers]
        header_array.map!{|x| x.gsub(/\s+|-+/, '_')}
        header_array.map!{|x| x.downcase} if options[:downcase_header]
      end

      # detect duplicate headers and disambiguate
      header_array = disambiguate_headers(header_array, options) if options[:duplicate_header_suffix]
      # symbolize headers
      header_array = header_array.map{|x| x.to_sym } unless options[:strings_as_keys] || options[:keep_original_headers]
      # doesn't make sense to re-map when we have user_provided_headers
      header_array = remap_headers(header_array, options) if options[:key_mapping]

      header_array
    end

    def disambiguate_headers(headers, options)
      counts = Hash.new(0)
      headers.map do |header|
        counts[header] += 1
        counts[header] > 1 ? "#{header}#{options[:duplicate_header_suffix]}#{counts[header]}" : header
      end
    end

    # do some key mapping on the keys in the file header
    # if you want to completely delete a key, then map it to nil or to ''
    def remap_headers(headers, options)
      key_mapping = options[:key_mapping]
      if key_mapping.empty? || !key_mapping.is_a?(Hash) || key_mapping.keys.empty?
        raise(SmarterCSV::IncorrectOption, "ERROR: incorrect format for key_mapping! Expecting hash with from -> to mappings")
      end

      key_mapping = options[:key_mapping]
      # if silence_missing_keys are not set, raise error if missing header
      missing_keys = key_mapping.keys - headers
      # if the user passes a list of speciffic mapped keys that are optional
      missing_keys -= options[:silence_missing_keys] if options[:silence_missing_keys].is_a?(Array)

      unless missing_keys.empty? || options[:silence_missing_keys] == true
        raise SmarterCSV::KeyMappingError, "ERROR: can not map headers: #{missing_keys.join(', ')}"
      end

      headers.map! do |header|
        if key_mapping.has_key?(header)
          key_mapping[header].nil? ? nil : key_mapping[header]
        elsif options[:remove_unmapped_keys]
          nil
        else
          header
        end
      end
      headers
    end

    # ---- V2.x Version: transform the headers that were in the file: ------------------------------------------
    #
    def header_transformations_v2(header_array, options)
      return header_array if options[:header_transformations].nil? || options[:header_transformations].empty?

      # do the header transformations the user requested:
      if options[:header_transformations]

        options[:header_transformations].each do |transformation|
          # the .each will always treat a hash argument as an array 🤪
          case transformation
          when Symbol # this is used for pre-defined transformations that are defined in the SmarterCSV module
            header_array = public_send(transformation, header_array, options)
          # when Hash # this would never be called, because we iterate with .each
          #   trans, *args = transformation.first # .first treats the hash first element as an array
          #   header_array = apply_transformation(trans, header_array, args, options)
          when Array # this can be used for passing additional arguments in to a proc
            trans, *args = transformation
            header_array = apply_transformation(trans, header_array, args, options)
          else # this is used when a user-provided Proc is passed in
            if transformation.respond_to?(:call)
              header_array = transformation.call(header_array, options)
            else
              raise ArgumentError, "Invalid transformation type: #{transformation.class}"
            end
          end
        end
      end

      header_array
    end

    def apply_transformation(transformation, header_array, args, options)
      if transformation.respond_to?(:call)
        # If transformation is a callable object (like a Proc)
        transformation.call(header_array, args, options)
      else
        # If transformation is a symbol (method name)
        public_send(transformation, header_array, args, options)
      end
    end

    # pre-defined v2 header transformations:

    # these are some pre-defined header transformations which can be used
    # all these take the headers array as the input
    #
    # the computed options can be accessed via @options

    @keys_as_symbols = nil
    @keys_as_strings = nil
    @key_mapping = nil

    def keys_as_symbols(headers, options)
      headers.map do |header|
        header.strip.downcase.gsub(%r{#{options[:quote_char]}}, '').gsub(/(\s|-)+/, '_').to_sym
      end
    end

    def keys_as_strings(headers, options)
      headers.map do |header|
        header.strip.gsub(%r{#{options[:quote_char]}}, '').downcase.gsub(/(\s|-)+/, '_')
      end
    end

    def downcase_headers(headers, options)
      headers.map do |header|
        header.strip.downcase!
      end
    end

    # this is a convenience function for supporting v1 feature parity

    def key_mapping(array, mapping = {})
      @key_mapping ||= proc {|headers, mapping = {}|
        raise(SmarterCSV::IncorrectOption, "ERROR: key_mapping header transformation needs a hash argument") unless mapping.is_a?(Hash)

        new_headers = []
        headers.each do |key|
          new_headers << (mapping.keys.include?(key) ? mapping[key] : key) # we need to map to nil as well!
        end
        new_headers
      }
      @key_mapping.call(array, mapping)
    end
  end
end
