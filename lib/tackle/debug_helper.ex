defmodule Tackle.DebugHelper do
  @doc """
  Removes userinfo from given uri
  """
  def safe_uri(uri) do
    parsed = URI.parse(uri)
    userinfo = parsed.userinfo
    make_userinfo_anonymous(uri, userinfo)
  end

  defp make_userinfo_anonymous(uri, nil), do: uri

  defp make_userinfo_anonymous(uri, userinfo) do
    anonymous_userinfo = String.replace(userinfo, ~r/[^:]/, "*")
    String.replace(uri, userinfo, anonymous_userinfo)
  end
end
