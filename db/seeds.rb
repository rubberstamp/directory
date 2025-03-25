# This file creates the initial seeds for the application

# Create admin user
admin = User.find_or_initialize_by(email: 'admin@example.com')
admin.password = 'password123'
admin.password_confirmation = 'password123'
admin.admin = true
admin.save!
puts "Admin user created: #{admin.email}"

# Create specializations
specializations = [
  { name: 'Startup Financing', description: 'Expertise in securing funding for early-stage startups and managing rapid growth.' },
  { name: 'SaaS', description: 'Specialized in subscription-based software companies and recurring revenue models.' },
  { name: 'Manufacturing', description: 'Experience with cost accounting, inventory management, and supply chain optimization.' },
  { name: 'Non-Profit', description: 'Knowledge of grant management, donor relations, and non-profit compliance.' },
  { name: 'E-commerce', description: 'Expertise in digital retail operations, marketplace financials, and scaling online businesses.' },
  { name: 'Healthcare', description: 'Experience with medical billing, healthcare regulations, and practice management.' },
  { name: 'Real Estate', description: 'Specialized in property portfolio management, REITs, and development project financing.' },
  { name: 'Tech Scale-up', description: 'Focused on helping technology companies scale from startup to growth stage.' }
]

specializations.each do |spec|
  Specialization.find_or_create_by!(name: spec[:name]) do |s|
    s.description = spec[:description]
  end
end
puts "#{specializations.count} specializations created"

# Create sample profiles if in development environment
if Rails.env.development?
  startup = Specialization.find_by(name: 'Startup Financing')
  saas = Specialization.find_by(name: 'SaaS')
  nonprofit = Specialization.find_by(name: 'Non-Profit')
  
  profiles = [
    {
      name: 'Sarah Johnson',
      headline: 'Fractional CFO for Tech Startups',
      bio: 'Over 15 years of experience helping startups optimize their financial operations and secure funding.',
      location: 'San Francisco, CA',
      email: 'sarah@example.com',
      linkedin_url: 'https://linkedin.com/in/sarahjohnson',
      youtube_url: 'https://youtube.com/watch?v=abc123',
      specializations: [startup, saas]
    },
    {
      name: 'Michael Chen',
      headline: 'SaaS Financial Expert & Fractional CFO',
      bio: 'Former CFO of two successful SaaS companies with expertise in subscription economics and growth strategy.',
      location: 'New York, NY',
      email: 'michael@example.com',
      linkedin_url: 'https://linkedin.com/in/michaelchen',
      youtube_url: 'https://youtube.com/watch?v=def456',
      specializations: [saas]
    },
    {
      name: 'Jessica Martinez',
      headline: 'Non-Profit Finance Specialist',
      bio: 'Dedicated to helping non-profits maximize their financial efficiency and achieve their mission.',
      location: 'Chicago, IL',
      email: 'jessica@example.com',
      linkedin_url: 'https://linkedin.com/in/jessicamartinez',
      youtube_url: 'https://youtube.com/watch?v=ghi789',
      specializations: [nonprofit]
    }
  ]
  
  profiles.each do |profile_data|
    specializations = profile_data.delete(:specializations)
    profile = Profile.find_or_initialize_by(email: profile_data[:email])
    profile.update!(profile_data)
    profile.specializations = specializations
  end
  puts "#{profiles.count} sample profiles created"
end
