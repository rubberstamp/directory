require "csv"

namespace :test do
  desc "Clean parse of production CSV"
  task clean_csv: :environment do
    file_path = "data/production_sheet.csv"

    puts "Cleaning and parsing production sheet CSV..."

    content = File.read(file_path, encoding: "ISO-8859-1:UTF-8")

    # Join the first two lines which contain the header
    lines = content.split(/\r?\n/)
    header_text = lines[0].tr("\r\n", " ") + " " + lines[1].tr("\r\n", " ")

    # Extract headers
    headers = header_text.split(",")
    headers = headers.map(&:strip)

    puts "Headers:"
    headers.each_with_index do |h, i|
      puts "#{i}: #{h}"
    end

    # Process data rows
    data_rows = []

    lines[2..-1].each_with_index do |line, index|
      # Skip empty lines
      next if line.strip.empty?

      # Basic split by comma
      values = line.split(",").map(&:strip)

      # Extract key fields
      episode_number = values[1].to_i
      title = values[2]

      # Skip rows that don't have a numeric episode number
      next if episode_number <= 0

      puts "Row #{index+3}: Episode ##{episode_number} - #{title}"
      data_rows << values
    end

    puts "Found #{data_rows.count} valid data rows"
  end
end
