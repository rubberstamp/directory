class TestimonialsController < ApplicationController
  def index
    @profiles = Profile.where.not(testimonial: [nil, ""]).order(submission_date: :desc)
    @testimonials_count = @profiles.count
  end
end