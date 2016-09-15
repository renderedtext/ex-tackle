defmodule Tackle.ThriftSerializer do

  defmacro __using__(file: [file], structs: [structs]) do

    quote do

      use ElixirThriftSerializer, file: [unquote(file)], structs: [unquote_splicing(structs)]

      def before_consume(message) do
        {ok, deserialized_message} = deserialize(message, unquote(structs))
        deserialized_message
      end
    end

  end

end
