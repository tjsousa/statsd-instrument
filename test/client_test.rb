# frozen_string_literal: true

require 'test_helper'

require 'statsd/instrument/client'

class ClientTest < Minitest::Test
  def setup
    @client = StatsD::Instrument::Client.new
  end

  def test_capture
    inner_datagrams = nil

    @client.increment('foo')
    outer_datagrams = @client.capture do
      @client.increment('bar')
      inner_datagrams = @client.capture do
        @client.increment('baz')
      end
    end
    @client.increment('quc')

    assert_equal ['bar', 'baz'], outer_datagrams.map(&:name)
    assert_equal ['baz'], inner_datagrams.map(&:name)
  end

  def test_metric_methods_return_nil
    assert_nil @client.increment('foo')
    assert_nil @client.measure('bar', 122.54)
    assert_nil @client.set('baz', 123)
    assert_nil @client.gauge('baz', 12.3)
  end

  def test_increment_with_default_value
    datagrams = @client.capture { @client.increment('foo') }
    assert_equal 1, datagrams.size
    assert_equal 'foo:1|c', datagrams.first.source
  end

  def test_measure_with_value
    datagrams = @client.capture { @client.measure('foo', 122.54) }
    assert_equal 1, datagrams.size
    assert_equal 'foo:122.54|ms', datagrams.first.source
  end

  def test_gauge
    datagrams = @client.capture { @client.gauge('foo', 123) }
    assert_equal 1, datagrams.size
    assert_equal 'foo:123|g', datagrams.first.source
  end

  def test_set
    datagrams = @client.capture { @client.set('foo', 12345) }
    assert_equal 1, datagrams.size
    assert_equal 'foo:12345|s', datagrams.first.source
  end

  def test_histogram
    datagrams = dogstatsd_client.capture { dogstatsd_client.histogram('foo', 12.44) }
    assert_equal 1, datagrams.size
    assert_equal 'foo:12.44|h', datagrams.first.source
  end

  def test_distribution
    datagrams = dogstatsd_client.capture { dogstatsd_client.distribution('foo', 12.44) }
    assert_equal 1, datagrams.size
    assert_equal 'foo:12.44|d', datagrams.first.source
  end

  def test_clone_with_prefix_option
    datagrams = []
    original_client = StatsD::Instrument::Client.new(sink: datagrams)
    client_with_other_options = original_client.clone_with_options(prefix: 'foo')

    original_client.increment('metric')
    client_with_other_options.increment('metric')

    assert_equal 2, datagrams.size, "Message both client should use the same sink"
    assert_equal 'metric', StatsD::Instrument::Datagram.new(datagrams[0]).name
    assert_equal 'foo.metric', StatsD::Instrument::Datagram.new(datagrams[1]).name
  end

  private

  def dogstatsd_client
    @dogstatsd_client ||= StatsD::Instrument::Client.new(datagram_builder_class:
      StatsD::Instrument::DogStatsDDatagramBuilder)
  end
end
