# ParserTest

Shows an issue if a client sends an invalid JSON using keep-alive connections:

```bash
  curl -X 'POST' \
  'http://localhost:4000/api' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{"hello": broken}' \
  --next -X 'POST' \
  'http://localhost:4000/api' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{"hello": "world"}'
```
sends two requests using the same keepalive connection. The first request is invalid
while the second is valid. It results in two errors:

```
[info] POST /api
[debug] ** (Plug.Parsers.ParseError) malformed request, a Jason.DecodeError exception was raised with message "unexpected byte at position 10: 0x62 (\"b\")"
    (plug 1.16.1) lib/plug/parsers/json.ex:95: Plug.Parsers.JSON.decode/3
    (plug 1.16.1) lib/plug/parsers.ex:340: Plug.Parsers.reduce/8
    (parser_test 0.1.0) lib/parser_test_web/endpoint.ex:1: ParserTestWeb.Endpoint.plug_builder_call/2
    (parser_test 0.1.0) deps/plug/lib/plug/debugger.ex:136: ParserTestWeb.Endpoint."call (overridable 3)"/2
    (parser_test 0.1.0) lib/parser_test_web/endpoint.ex:1: ParserTestWeb.Endpoint.call/2
    (phoenix 1.7.18) lib/phoenix/endpoint/sync_code_reload_plug.ex:22: Phoenix.Endpoint.SyncCodeReloadPlug.do_call/4
    (bandit 1.6.2) lib/bandit/pipeline.ex:129: Bandit.Pipeline.call_plug!/2
    (bandit 1.6.2) lib/bandit/pipeline.ex:40: Bandit.Pipeline.run/4
    (bandit 1.6.2) lib/bandit/http1/handler.ex:12: Bandit.HTTP1.Handler.handle_data/3
    (bandit 1.6.2) lib/bandit/delegating_handler.ex:18: Bandit.DelegatingHandler.handle_data/3
    (bandit 1.6.2) lib/bandit/delegating_handler.ex:8: Bandit.DelegatingHandler.handle_continue/2
    (stdlib 6.0.1) gen_server.erl:2163: :gen_server.try_handle_continue/3
    (stdlib 6.0.1) gen_server.erl:2072: :gen_server.loop/7
    (stdlib 6.0.1) proc_lib.erl:329: :proc_lib.init_p_do_apply/3

[error] ** (Bandit.HTTPError) Request line HTTP error: "{\"hello\": broken}POST /api HTTP/1.1\r\n"
```
Plug uses an exception and a 400 status code. 
While throwing the exception the changes to the buffer used to parse the invalid JSON is dropped. 
When using keepalive connections, Bandit does not close the connection in case of this status code, 
the buffer is reused for the next request

The next request is added to the buffer. This leads to a wrong request and the connection is closed:

```elixir
  defp handle_error(kind, reason, stacktrace, transport, span, opts, metadata) do
    Bandit.Telemetry.span_exception(span, kind, reason, stacktrace)
    status = reason |> Plug.Exception.status() |> Plug.Conn.Status.code()

    if status in Keyword.get(opts.http, :log_exceptions_with_status_codes, 500..599) do
      logger_metadata = Bandit.Logger.logger_metadata_for(kind, reason, stacktrace, metadata)
      Logger.error(Exception.format(kind, reason, stacktrace), logger_metadata)

      Bandit.HTTPTransport.send_on_error(transport, reason)
      {:error, reason}
    else
      Bandit.HTTPTransport.send_on_error(transport, reason)
      {:ok, transport}
    end
  end
```

When changing the default status code to 500:

```elixir
    try do
      apply(module, fun, [body | args])
    rescue
      e -> raise Plug.Parsers.ParseError, exception: e, plug_status: 500
    else
```

the connection is closed and the second request is processed successfully:

```
[info] POST /api
[error] ** (Plug.Parsers.ParseError) malformed request, a Jason.DecodeError exception was raised with message "unexpected byte at position 10: 0x62 (\"b\")"
    (parser_test 0.1.0) lib/parser_test_web/json_parser.ex:95: JSON.decode/3
    (plug 1.16.1) lib/plug/parsers.ex:340: Plug.Parsers.reduce/8
    (parser_test 0.1.0) lib/parser_test_web/endpoint.ex:1: ParserTestWeb.Endpoint.plug_builder_call/2
    (parser_test 0.1.0) deps/plug/lib/plug/debugger.ex:136: ParserTestWeb.Endpoint."call (overridable 3)"/2
    (parser_test 0.1.0) lib/parser_test_web/endpoint.ex:1: ParserTestWeb.Endpoint.call/2
    (phoenix 1.7.18) lib/phoenix/endpoint/sync_code_reload_plug.ex:22: Phoenix.Endpoint.SyncCodeReloadPlug.do_call/4
    (bandit 1.6.2) lib/bandit/pipeline.ex:129: Bandit.Pipeline.call_plug!/2
    (bandit 1.6.2) lib/bandit/pipeline.ex:40: Bandit.Pipeline.run/4
    (bandit 1.6.2) lib/bandit/http1/handler.ex:12: Bandit.HTTP1.Handler.handle_data/3
    (bandit 1.6.2) lib/bandit/delegating_handler.ex:18: Bandit.DelegatingHandler.handle_data/3
    (bandit 1.6.2) lib/bandit/delegating_handler.ex:8: Bandit.DelegatingHandler.handle_continue/2
    (stdlib 6.0.1) gen_server.erl:2163: :gen_server.try_handle_continue/3
    (stdlib 6.0.1) gen_server.erl:2072: :gen_server.loop/7
    (stdlib 6.0.1) proc_lib.erl:329: :proc_lib.init_p_do_apply/3

[info] POST /api
[debug] Processing with ParserTestWeb.PageController.home/2
  Parameters: %{"hello" => "world"}
  Pipelines: [:api]
[info] Sent 200 in 7ms

```

