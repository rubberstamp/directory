namespace :import do
  desc "Import guests from the guest_list.csv file"
  task guests: :environment do
    require 'csv'
    
    puts "Importing guests from guest_list.csv..."
    
    file_path = "#{Rails.root}/data/guest_list.csv"
    
    unless File.exist?(file_path)
      puts "File not found at #{file_path}"
      exit
    end
    
    guest_count = 0
    
    begin
      # Convert the file to use LF line endings and parse manually
      csv_text = File.read(file_path).encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      csv_text.gsub!("\r\n", "\n") # Convert CRLF to LF
      
      CSV.parse(csv_text, headers: true) do |row|
        # Skip empty rows
        next if row['Guest Name'].blank?
        
        name = row['Guest Name']
        company = row['Company']
        website = row['Website Address']
        address = row['Physical Mailing Address']
        linkedin = row['LinkedIn']
        facebook = row['Facebook']
        twitter = row['Twitter']
        instagram = row['Instagram']
        tiktok = row['Tiktok']
        testimonial = row['What would you say to a potential guest of the podcast regarding your experience as a guest?']
        headshot = row['Headshot (optional)']
        interested = row['Do you have a client who could benefit from ProcurementExpress.com?'].to_s.strip.downcase == 'yes'
        
        # Generate an email if not provided (for validation purposes)
        email = "#{name.downcase.gsub(/\s+/, '.')}@example.com"
        
        # Create or update the profile
        profile = Profile.find_by(name: name) || Profile.new(name: name)
        
        # Update fields
        profile.assign_attributes(
          email: email,
          company: company,
          website: website,
          mailing_address: address,
          linkedin_url: linkedin,
          facebook_url: facebook == 'n/a' ? nil : facebook,
          twitter_url: twitter == 'n/a' ? nil : twitter,
          instagram_url: instagram == 'n/a' ? nil : instagram,
          tiktok_url: tiktok == 'n/a' ? nil : tiktok,
          testimonial: testimonial,
          headshot_url: headshot,
          interested_in_procurement: interested,
          submission_date: (row['Timestamp'].present? ? (Date.parse(row['Timestamp'].split(' ').first) rescue nil) : nil)
        )
        
        # Save profile
        if profile.save
          guest_count += 1
          puts "Imported #{name} (#{company})"
        else
          puts "ERROR importing #{name}: #{profile.errors.full_messages.join(', ')}"
        end
      end
      
      puts "Successfully imported #{guest_count} guests!"
    rescue => e
      puts "Error importing data: #{e.message}"
      puts e.backtrace
    end
  end
end