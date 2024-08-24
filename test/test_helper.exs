Code.ensure_loaded(Plug.Test)

Application.put_env(:hedgex, :req_options, plug: {Req.Test, Hedgex})
Application.put_env(:hedgex, :public_endpoint, "https://foo.example.com/")
Application.put_env(:hedgex, :project_api_key, "abcde12345")

ExUnit.start()
