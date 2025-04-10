class EventsController < ApplicationController
  def index
    # Calculate the date for the last Wednesday of the next month
    today = Date.today
    next_month = today.next_month
    last_day = Date.new(next_month.year, next_month.month, -1)
    last_wednesday = last_day - ((last_day.wday - 3) % 7)

    @next_mastermind_date = last_wednesday
    @mastermind_time_gmt = Time.new(last_wednesday.year, last_wednesday.month, last_wednesday.day, 16, 30, 0, "+00:00")

    # Calculate Eastern time (GMT-4 or GMT-5 depending on DST)
    @mastermind_time_eastern = @mastermind_time_gmt.getlocal("-04:00")

    # Calculate Pacific time (GMT-7 or GMT-8 depending on DST)
    @mastermind_time_pacific = @mastermind_time_gmt.getlocal("-07:00")
  end
end
