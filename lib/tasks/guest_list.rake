require "csv"

namespace :guest_list do
  desc "Import guest list from CSV file"
  task import: :environment do
    # First, clear existing profiles
    if ENV["RESET"] == "true"
      puts "Clearing existing profiles..."
      Profile.destroy_all
    end

    csv_file_path = Rails.root.join("data", "guest_list_fixed.csv")

    if File.exist?(csv_file_path)
      puts "Importing guest list from #{csv_file_path}..."

      # Read the file content and fix line endings
      content = File.read(csv_file_path)
      content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

      # Parse CSV content manually
      csv = CSV.parse(content, headers: true)

      success_count = 0
      error_count = 0

      csv.each do |row|
        next if row["Guest Name"].blank?

        # Parse and clean data
        email = row["Physical Mailing Address"]&.include?("@") ? row["Physical Mailing Address"] : nil
        submission_date = parse_date(row["Timestamp"]) if row["Timestamp"].present?

        # Parse social media URLs
        linkedin = clean_url(row["LinkedIn"])
        facebook = clean_url(row["Facebook"])
        twitter = clean_url(row["Twitter"])
        instagram = clean_url(row["Instagram"])
        tiktok = clean_url(row["Tiktok"])

        # Handle specific problem cases
        website_url = row["Website Address"]
        case row["Guest Name"]
        when "Steve McLeod"
          website_url = "https://featureupvote.com/"
        when "Colin Hewitt"
          website_url = "https://floatapp.com/"
        when "Haim Ratzabi"
          website_url = "https://www.hrcfoservices.com/"
        end

        profile = Profile.find_or_initialize_by(name: row["Guest Name"])
        profile.assign_attributes(
          company: row["Company"],
          website: clean_url(website_url),
          mailing_address: email ? nil : row["Physical Mailing Address"],
          email: email || "#{row['Guest Name'].downcase.gsub(/[^a-z0-9]/, '')}@example.com",
          linkedin_url: linkedin,
          facebook_url: facebook,
          twitter_url: twitter,
          instagram_url: instagram,
          tiktok_url: tiktok,
          testimonial: row["What would you say to a potential guest of the podcast regarding your experience as a guest?"],
          headshot_url: row["Headshot (optional)"],
          interested_in_procurement: row["Do you have a client who could benefit from ProcurementExpress.com?"] == "Yes",
          submission_date: submission_date
        )

        if profile.save
          success_count += 1
          puts "Created profile for #{profile.name}"
        else
          error_count += 1
          puts "Failed to create profile for #{row['Guest Name']}: #{profile.errors.full_messages.join(', ')}"
        end
      end

      puts "Import completed. Successfully imported #{success_count} profiles. #{error_count} failed."
    else
      puts "CSV file not found at #{csv_file_path}"
    end
  end
end

def parse_date(date_string)
  return nil if date_string.blank?

  # Try different date formats
  begin
    Date.strptime(date_string, "%m/%d/%Y %H:%M:%S")
  rescue ArgumentError
    begin
      Date.strptime(date_string, "%m/%d/%Y")
    rescue ArgumentError
      nil
    end
  end
end

def clean_url(url)
  return nil if url.blank? || url == "n/a" || url == "N/A" || url == "-" || url == "NA" || url.downcase.include?("not on")

  # Handle Twitter handles (convert @handle to https://twitter.com/handle)
  if url.start_with?("@")
    return "https://twitter.com/#{url[1..]}"
  end

  # Special case for website URLs
  if url.include?(",")
    # If there's a comma, it might be a malformed URL or multiple URLs
    url = url.split(",").first.strip
  end

  # Fix common issues with URLs
  url = url.sub(/^www,/, "www.") if url.start_with?("www,")

  # Add https:// if missing
  if url.present? && !url.match?(/\A(https?:\/\/)/)
    "https://#{url}"
  else
    url
  end
end
