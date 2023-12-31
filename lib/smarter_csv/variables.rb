# frozen_string_literal: true

module SmarterCSV
  class << self
    attr_reader :has_rails, :csv_line_count, :chunk_count, :errors, :file_line_count, :headers, :raw_header, :result, :warnings

    def initialize_variables
      @has_rails = !!defined?(Rails)
      @csv_line_count = 0
      @chunk_count = 0
      @errors = {}
      @file_line_count = 0
      @headerA = []
      @headers = nil
      @raw_header = nil # header as it appears in the file
      @result = []
      @warnings = {}
      @v2_mode = false
    end

    # :nocov:
    def headerA
      warn "Deprecarion Warning: 'headerA' will be removed in future versions. Use 'headders'"
      @headerA
    end
    # :nocov:
  end
end
