require 'open-uri'
require 'nokogiri'
require 'fileutils'
require 'net/http'

namespace :headshots do
  desc 'Try to find headshots from social media profiles'
  task from_social: :environment do
    # Ensure storage directory exists
    storage_dir = Rails.root.join('public', 'uploads', 'headshots')
    FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)
    
    # Find profiles with placeholder avatars (UI Avatars service)
    profiles_with_placeholders = Profile.where("headshot_url LIKE ?", "%ui-avatars.com%")
    
    puts "Found #{profiles_with_placeholders.count} profiles with placeholder avatars"
    
    success_count = 0
    
    profiles_with_placeholders.each do |profile|
      puts "\nProcessing profile: #{profile.name}"
      
      # Try LinkedIn first
      if profile.linkedin_url.present?
        puts "  Checking LinkedIn profile: #{profile.linkedin_url}"
        if fetch_linkedin_photo(profile, storage_dir)
          success_count += 1
          next
        end
      end
      
      # Try Twitter second
      if profile.twitter_url.present?
        puts "  Checking Twitter profile: #{profile.twitter_url}"
        if fetch_twitter_photo(profile, storage_dir)
          success_count += 1
          next
        end
      end
      
      # Try Instagram third
      if profile.instagram_url.present?
        puts "  Checking Instagram profile: #{profile.instagram_url}"
        if fetch_instagram_photo(profile, storage_dir)
          success_count += 1
          next
        end
      end
      
      # Try Facebook as a last resort
      if profile.facebook_url.present?
        puts "  Checking Facebook profile: #{profile.facebook_url}"
        if fetch_facebook_photo(profile, storage_dir)
          success_count += 1
          next
        end
      end
      
      puts "  Could not find a photo for #{profile.name} from social media"
    end
    
    puts "\nHeadshot import completed. Found photos for #{success_count} out of #{profiles_with_placeholders.count} profiles"
    
    # Provide tips for the remaining profiles
    remaining = profiles_with_placeholders.count - success_count
    if remaining > 0
      puts "\nTo find photos for the remaining #{remaining} profiles:"
      puts "1. Manually visit their LinkedIn/Twitter/Instagram profiles"
      puts "2. Download their profile pictures"
      puts "3. Place them in public/uploads/headshots/ with proper filenames"
      puts "4. Update the database records with the new paths"
    end
  end
  
  desc 'Generate a report of all social media links for profiles'
  task social_report: :environment do
    puts "\n========= SOCIAL MEDIA LINKS REPORT =========\n\n"
    
    profiles = Profile.where.not(linkedin_url: [nil, ""]).or(
      Profile.where.not(twitter_url: [nil, ""])).or(
      Profile.where.not(instagram_url: [nil, ""])).or(
      Profile.where.not(facebook_url: [nil, ""]))
    
    puts "Found #{profiles.count} profiles with social media links\n\n"
    
    profiles.each do |profile|
      puts "#{profile.name}:"
      puts "  LinkedIn:  #{profile.linkedin_url}" if profile.linkedin_url.present?
      puts "  Twitter:   #{profile.twitter_url}" if profile.twitter_url.present?
      puts "  Instagram: #{profile.instagram_url}" if profile.instagram_url.present?
      puts "  Facebook:  #{profile.facebook_url}" if profile.facebook_url.present?
      puts "  Website:   #{profile.website}" if profile.website.present?
      puts ""
    end
    
    puts "========= END OF REPORT =========\n\n"
  end
  
  private
  
  # Try to get a LinkedIn profile photo
  # Note: This is challenging because LinkedIn restricts scraping
  # This method will only work for some public profiles
  def fetch_linkedin_photo(profile, storage_dir)
    begin
      uri = URI(profile.linkedin_url)
      
      # Make sure it's a valid LinkedIn URL
      return false unless uri.host&.include?('linkedin.com')
      
      # Fetch the page content
      response = fetch_with_headers(profile.linkedin_url)
      return false unless response
      
      doc = Nokogiri::HTML(response)
      
      # Try several common patterns for LinkedIn profile images
      image_url = nil
      
      # Try meta tags first (most reliable)
      doc.css('meta[property="og:image"]').each do |meta|
        if meta['content'] && meta['content'].include?('linkedin.com/') && meta['content'].end_with?('.jpg')
          image_url = meta['content']
          break
        end
      end
      
      # Try image tags if meta tags don't work
      if image_url.nil?
        doc.css('img.pv-top-card-profile-picture__image, img.profile-picture-image').each do |img|
          if img['src'] && img['src'].include?('linkedin.com/')
            image_url = img['src']
            break
          end
        end
      end
      
      return false unless image_url
      
      # Download and save the image
      filename = "#{profile.name.parameterize}-linkedin.jpg"
      local_path = File.join(storage_dir, filename)
      
      if download_image(image_url, local_path)
        # Update the profile with the new local URL
        new_url = "/uploads/headshots/#{filename}"
        profile.update(headshot_url: new_url)
        puts "  Successfully downloaded LinkedIn photo for #{profile.name}"
        return true
      end
    rescue StandardError => e
      puts "  Error getting LinkedIn photo for #{profile.name}: #{e.message}"
    end
    
    false
  end
  
  # Try to get a Twitter profile photo
  def fetch_twitter_photo(profile, storage_dir)
    begin
      uri = URI(profile.twitter_url)
      
      # Make sure it's a valid Twitter URL
      return false unless uri.host&.include?('twitter.com') || uri.host&.include?('x.com')
      
      # Fetch the page content
      response = fetch_with_headers(profile.twitter_url)
      return false unless response
      
      doc = Nokogiri::HTML(response)
      
      # Try to find the profile image URL
      image_url = nil
      
      # Try meta tags first
      doc.css('meta[property="og:image"]').each do |meta|
        if meta['content'] && (meta['content'].include?('pbs.twimg.com/') || meta['content'].include?('twitter.com/'))
          image_url = meta['content']
          break
        end
      end
      
      # Twitter profile images are usually in this format, we can try to guess it
      if image_url.nil? && profile.twitter_url.match(/twitter\.com\/([^\/\?]+)/)
        username = $1
        # Try to construct a likely profile image URL
        image_url = "https://pbs.twimg.com/profile_images/#{username}_400x400.jpg"
      end
      
      return false unless image_url
      
      # Download and save the image
      filename = "#{profile.name.parameterize}-twitter.jpg"
      local_path = File.join(storage_dir, filename)
      
      if download_image(image_url, local_path)
        # Update the profile with the new local URL
        new_url = "/uploads/headshots/#{filename}"
        profile.update(headshot_url: new_url)
        puts "  Successfully downloaded Twitter photo for #{profile.name}"
        return true
      end
    rescue StandardError => e
      puts "  Error getting Twitter photo for #{profile.name}: #{e.message}"
    end
    
    false
  end
  
  # Try to get an Instagram profile photo
  def fetch_instagram_photo(profile, storage_dir)
    begin
      uri = URI(profile.instagram_url)
      
      # Make sure it's a valid Instagram URL
      return false unless uri.host&.include?('instagram.com')
      
      # Fetch the page content
      response = fetch_with_headers(profile.instagram_url)
      return false unless response
      
      doc = Nokogiri::HTML(response)
      
      # Try to find the profile image URL
      image_url = nil
      
      # Try meta tags
      doc.css('meta[property="og:image"]').each do |meta|
        if meta['content'] && meta['content'].include?('cdninstagram.com')
          image_url = meta['content']
          break
        end
      end
      
      return false unless image_url
      
      # Download and save the image
      filename = "#{profile.name.parameterize}-instagram.jpg"
      local_path = File.join(storage_dir, filename)
      
      if download_image(image_url, local_path)
        # Update the profile with the new local URL
        new_url = "/uploads/headshots/#{filename}"
        profile.update(headshot_url: new_url)
        puts "  Successfully downloaded Instagram photo for #{profile.name}"
        return true
      end
    rescue StandardError => e
      puts "  Error getting Instagram photo for #{profile.name}: #{e.message}"
    end
    
    false
  end
  
  # Try to get a Facebook profile photo
  def fetch_facebook_photo(profile, storage_dir)
    begin
      uri = URI(profile.facebook_url)
      
      # Make sure it's a valid Facebook URL
      return false unless uri.host&.include?('facebook.com')
      
      # Fetch the page content
      response = fetch_with_headers(profile.facebook_url)
      return false unless response
      
      doc = Nokogiri::HTML(response)
      
      # Try to find the profile image URL
      image_url = nil
      
      # Try meta tags
      doc.css('meta[property="og:image"]').each do |meta|
        if meta['content'] && meta['content'].include?('fbcdn.net')
          image_url = meta['content']
          break
        end
      end
      
      return false unless image_url
      
      # Download and save the image
      filename = "#{profile.name.parameterize}-facebook.jpg"
      local_path = File.join(storage_dir, filename)
      
      if download_image(image_url, local_path)
        # Update the profile with the new local URL
        new_url = "/uploads/headshots/#{filename}"
        profile.update(headshot_url: new_url)
        puts "  Successfully downloaded Facebook photo for #{profile.name}"
        return true
      end
    rescue StandardError => e
      puts "  Error getting Facebook photo for #{profile.name}: #{e.message}"
    end
    
    false
  end
  
  # Helper method to fetch a URL with browser-like headers
  def fetch_with_headers(url)
    begin
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      
      # Set headers to mimic a browser
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36'
      request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8'
      request['Accept-Language'] = 'en-US,en;q=0.9'
      
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end
      
      if response.is_a?(Net::HTTPSuccess)
        return response.body
      else
        puts "  HTTP Error: #{response.code} - #{response.message}"
        return nil
      end
    rescue StandardError => e
      puts "  Error fetching URL #{url}: #{e.message}"
      return nil
    end
  end
  
  # Helper method to download an image
  def download_image(url, local_path)
    begin
      # Download the image
      image_data = URI.open(
        url,
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36",
        "Accept" => "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"
      ).read
      
      # Save the downloaded file
      File.open(local_path, 'wb') do |file|
        file.write(image_data)
      end
      
      # Verify the file was saved and has content
      if File.exist?(local_path) && File.size(local_path) > 0
        return true
      else
        puts "  Error: Downloaded file is empty or doesn't exist."
        return false
      end
    rescue StandardError => e
      puts "  Error downloading image: #{e.message}"
      return false
    end
  end
end