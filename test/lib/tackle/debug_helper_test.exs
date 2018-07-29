defmodule Tackle.DebugHelperTest do
  use ExSpec

  describe "Logging of rabbitmq urls" do
    it "makes userinfo anonymous" do
      uri =
        "amqp://my_user-name:FY4BLqUn8UW2KQzBRr327sWU@voyager.rmq.cloudamqp.com:8888/my_path?foo=bar"

      anonymous_uri = Tackle.DebugHelper.safe_uri(uri)

      assert anonymous_uri ==
               "amqp://************:************************@voyager.rmq.cloudamqp.com:8888/my_path?foo=bar"
    end

    it "does nothing on uri without userinfo" do
      uri = "amqp://voyager.rmq.cloudamqp.com:8888/my_path?foo=bar"
      assert Tackle.DebugHelper.safe_uri(uri) == uri
    end
  end
end
