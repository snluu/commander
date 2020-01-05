# A commander can dispatch blocks to run concurrently.
# The caller can dictate the number of concurrent jobs by
# passing in a max concurrency at the time of initialization.
class Commander(T)
  @result_ch : Channel(Commander::Try(T))
  @concurrency_ch : Channel(Nil)?

  DEFAULT_RESULT_CAPACITY = 1024

  # Gets the number of dispatched jobs
  getter size : Int32

  # Creates a new instance with a concurrency limit,
  # using the default result capacity.
  def self.with_concurrency_limit(max_concurrency)
    new(DEFAULT_RESULT_CAPACITY, max_concurrency)
  end

  # Creates a new instance with the given result capacity,
  # without concurrency limit.
  def self.with_capacity(result_capacity)
    new(result_capacity, 0)
  end

  # Initializes a new instance with the default result capacity,
  # and no concurrency limit.
  def initialize
    initialize(DEFAULT_RESULT_CAPACITY, 0)
  end

  # Initializes a new instance of this class with the given max concurrency.
  # Max concurrency will dictate the number of concurrent jobs.
  # All dispatched job will run concurrently if max concurrency is set to zero.
  def initialize(result_capacity, max_concurrency)
    max_concurrency = 0 if max_concurrency < 0
    @result_ch = Channel(Commander::Try(T)).new(result_capacity)
    @size = 0

    if max_concurrency > 0
      cch = Channel(Nil).new(max_concurrency)
      max_concurrency.times do
        cch.send(nil)
      end

      @concurrency_ch = cch
    end
  end

  # Dispatches the given block to run in a new fiber.
  # **Note**: the spawned fiber will block if max concurrency is hit,
  # and will only proceed to invoke the given block when previously spawned fibers finishes.
  def dispatch(&block : -> T)
    raise "Cannot dispatch after calling collect" if @result_ch.closed?

    @size += 1
    spawn do
      cch = @concurrency_ch
      cch.receive unless cch.nil?

      try = Commander::Try(T).new
      begin
        try.result = block.call
      rescue ex
        try.error = ex
        try.result = nil
      end

      # unblock if there's another fiber waiting
      cch.send(nil) unless cch.nil?

      @result_ch.send(try)
    end
  end

  # Collects the result of the dispatched calls.
  # This function will only return once all the dispatched calls are finished.
  # This function does not raise any exception from the dispatched calls.
  # The exceptions are wrapped in `Try(T)`, with `has_result` set to false.
  def collect_tries
    result = [] of Try(T)

    @size.times do
      result << @result_ch.receive
    end

    @result_ch.close
    return result
  end

  # Collects the result of the dispatched calls.
  # This function will only return once all the dispatched calls are finished.
  # This function will raise the first error that it received from any of the dispatched calls.
  def collect
    result = [] of T

    @size.times do
      try = @result_ch.receive
      raise try.error.not_nil! if try.has_error?

      result << try.result.as(T)
    end

    @result_ch.close
    return result
  end
end

# Indicates the result of a dispatched call.
class Commander::Try(T)
  property result : T?
  property error : Exception?

  def has_error?
    !@error.nil?
  end

  def has_result?
    !@result.nil?
  end

  def initialize
    @has_result = false
  end
end
