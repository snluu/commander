require "./spec_helper"

describe Commander do
  it "should spawn everything immediately if there if max concurrency < 1" do
    cmd = Commander(Int32).new
    result = nil

    elapsed = Time.measure do
      1000.times do |x|
        cmd.dispatch do
          sleep 1.seconds
          x
        end
      end

      result = cmd.collect
    end

    result = result.not_nil!
    result.size.should eq(1000)
    1000.times do |x|
      result.should contain(x)
    end

    # 5 seconds is a very generous buffer.
    # The point is it should not take 1000 seconds
    elapsed.should be < 5.seconds
  end

  it "should respect max concurrency" do
    cmd = Commander(Int32).with_concurrency_limit(1)
    result = nil

    elapsed = Time.measure do
      3.times do |x|
        cmd.dispatch do
          sleep 1.seconds
          x
        end
      end

      result = cmd.collect
    end

    result = result.not_nil!
    result.size.should eq(3)

    3.times do |x|
      result.should contain(x)
    end

    elapsed.should be >= 3.seconds
  end

  it "should capture errors raised by dispatched calls" do
    cmd = Commander(Int32).new

    1000.times do |x|
      cmd.dispatch do
        if x % 2 != 0
          raise "Odd number"
        end
        x
      end
    end

    result = cmd.collect_tries
    result.size.should eq(1000)
    result.each do |try|
      if try.has_result?
        (try.result.not_nil! % 2).should eq(0)
      else
        try.error.not_nil!.message.should eq("Odd number")
      end
    end
  end

  it "should raise the first error received from a dispatched call" do
    cmd = Commander(Int32).new

    10.times do |x|
      cmd.dispatch do
        if x % 2 != 0
          raise "Odd number"
        end
        x
      end
    end

    expect_raises Exception, "Odd number" do
      cmd.collect
    end
  end

  it "should work with void or nil" do
    cmd = Commander(Nil).new

    10.times do |x|
      cmd.dispatch do
        nil
      end
    end

    result = cmd.collect
    result.size.should eq(10)

    result.each do |x|
      x.should be_nil
    end
  end
end
