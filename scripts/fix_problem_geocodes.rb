#!/usr/bin/env ruby
# Script to fix profiles with problematic geocoding

# Define profile IDs and their simplified location formats
problem_profiles = {
  47 => { location: "Greenwich, CT", notes: "Had complex address format" },
  51 => { location: "Parker, CO", notes: "Had complex address format" },
  53 => { location: "Newnan, GA", notes: "Had complex address format" },
  68 => { location: "Weston, FL", notes: "Had complex address format" },
  85 => { location: "Barcelona, Spain", notes: "Had complex address format" }
}

puts "Fixing geocoding for problematic profiles..."

problem_profiles.each do |profile_id, data|
  profile = Profile.find_by(id: profile_id)

  if profile
    puts "Profile ##{profile_id} (#{profile.name}):"
    puts "  Original mailing: #{profile.mailing_address.inspect}"
    puts "  Setting location: #{data[:location]}"

    # Update the location field
    profile.location = data[:location]

    # Queue geocoding
    profile.save

    # Tell the user what we did
    puts "  ✓ Updated and queued for geocoding"
  else
    puts "  ✗ Profile ##{profile_id} not found"
  end
end

puts "\nRun 'rails profiles:geocode' to perform geocoding on these updated profiles."
