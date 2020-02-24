defmodule Shopify.REST.Request do
  alias Shopify.REST.{ Config, Helpers, Operation, Response }

  @spec send(Operation.t(), Config.t()) :: Shopify.REST.response_t()
  def send(operation, config) do
    send(operation, config, %{})
  end

  @spec send(Operation.t(), Config.t(), map) :: Shopify.REST.response_t()
  def send(operation, %{ retry: true } = config, private) do
    private = Map.put_new(private, :attempts, 0)

    attempt = Map.get(private, :attempts) + 1

    max_attempts = Keyword.get(config.retry_opts, :max_attempts, 3)

    private = %{ private | attempts: attempt }

    result = do_send(operation, config, private)

    if retryable?(result) && max_attempts > attempt do
      send(operation, config, private)
    else
      result
    end
  end

  def send(operation, config, private) do
    do_send(operation, config, private)
  end

  defp do_send(operation, config, private) do
    http_client_opts = config.http_client_opts

    body = Helpers.JSON.encode(operation.params, config)

    headers = [{ "content-type", "application/json" }] ++ config.headers

    method = operation.method

    url = Helpers.URL.to_string(operation, config)

    result =
      config.http_client.request(
        method,
        url,
        headers,
        body,
        http_client_opts
      )

    case result do
      { :ok, %{ status_code: status_code } = response}
        when status_code >= 400 ->
        { :error, Response.new(response, private, config) }
      { :ok, %{ status_code: status_code } = response}
        when status_code >= 200 ->
        { :ok, Response.new(response, private, config) }
      _otherwise ->
        result
    end
  end

  defp retryable?(result) do
    case result do
      { :ok, _response } ->
        false
      { :error, %Response{ status_code: status_code } } when status_code >= 500 ->
        true
      { :error, %Response{} } ->
        false
      _otherwise ->
        true
    end
  end
end
