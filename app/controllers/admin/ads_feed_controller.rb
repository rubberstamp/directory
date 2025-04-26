require 'csv'
module Admin
  # Exposes a CSV feed of profiles for Google Ads / Merchant Center.
  # Requires admin authentication via Admin::BaseController.
  class AdsFeedController < BaseController
    def show
      respond_to do |format|
        format.csv { send_data generate_csv, filename: "profiles_ads_feed_#{Time.current.to_i}.csv" }
      end
    end

    private

    def generate_csv
      profiles = Profile.active_for_ads.includes(:specializations)

      CSV.generate(headers: true) do |csv|
        csv << %w[id name final_url image_url city country specialization short_bio youtube_url]

        profiles.find_each do |profile|
          csv << [
            profile.id,
            profile.name,
            profile.ad_final_url,
            profile.ad_image_url,
            profile.cached_city || profile.location,
            profile.cached_country,
            profile.ad_specializations,
            profile.bio.to_s.truncate(120, omission: ''),
            profile.youtube_url
          ]
        end
      end
    end
  end
end
