# frozen_string_literal: true

class ProfilesController < ApplicationController
  def index
    @profiles = Profile.guests
                       .includes(:specializations, headshot_attachment: :blob)
                       .search_by_name(params[:name])
                       .with_specialization(params[:specialization_id])
                       .filtered_by_guest_type(params[:guest_filter])
                       .then { |scope| apply_location_filter(scope) }
                       .default_order
                       .page(params[:page])
                       .per(20)

    @specializations = Specialization.order(:name)
  end

  def show
    @profile = Profile.includes(:specializations, :episodes).find(params[:id])
  end

  private

  # Apply location filtering with geocoding fallback
  def apply_location_filter(scope)
    return scope if params[:location].blank?

    # Try text-based search first
    text_results = scope.in_location(params[:location])

    # If few results, try geocoding fallback
    if text_results.count < 3
      geocoded_results = geocode_location_search(scope)
      return text_results.or(geocoded_results) if geocoded_results.any?
    end

    text_results
  end

  # Search for profiles near a geocoded location
  def geocode_location_search(base_scope)
    results = Geocoder.search(params[:location])
    return Profile.none unless results.present? && results.first&.coordinates.present?

    lat, lon = results.first.coordinates
    return Profile.none unless valid_coordinates?(lat, lon)

    Profile.guests
           .with_coordinates
           .with_specialization(params[:specialization_id])
           .filtered_by_guest_type(params[:guest_filter])
           .near([lat, lon], 80, units: :km)
  rescue => e
    Rails.logger.error "Error geocoding search input '#{params[:location]}': #{e.message}"
    Profile.none
  end

  def valid_coordinates?(lat, lon)
    lat.present? && lon.present? &&
      lat.to_f.between?(-90, 90) && lon.to_f.between?(-180, 180)
  end
end
