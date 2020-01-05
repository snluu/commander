# commander

Commander is a simple shard that lets you dispatch many concurrent calls at once,
then collect the result afterwards.

Commander also allows the caller to choose the maximum concurrency for the given job.

API doc can be found at https://www.luu.io/projects/commander/api/

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  commander:
    github: snluu/commander
```

2. Run `shards install`

## Usage

See the spec for more details/examples.

```crystal
require "commander"

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

```
