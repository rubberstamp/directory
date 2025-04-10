class TestimonialsController < ApplicationController
  def index
    @profiles = Profile.where.not(testimonial: [ nil, "" ]).with_attached_headshot.includes(:episodes).order(submission_date: :desc)
    @testimonials_count = @profiles.count
  end
end
