defmodule Feb do
  # This is what the call
  #
  #    use Feb, root: "assets"
  #
  # expands to.
  defmacro __using__(module, opts) do
    Module.add_compile_callback module, __MODULE__, :default_handle

    root_val = Keyword.get(opts, :root, ".")

    quote do
      import Feb

      def start do
        Feb.start unquote(module)
      end

      defp static_root, do: unquote(root_val)
    end
  end

  def start(_) do
    IO.puts "Executing Feb.start"
  end

  ###

  # GET request handler. It has two forms.
  defmacro get(path, [do: code]) do
    quote do
      def handle(:get, unquote(path), _query) do
        unquote(code)
      end
    end
  end

  defmacro get(path, [file: bin]) when is_binary(bin) do
    quote do
      def handle(:get, unquote(path), _query) do
        full_path = File.join([static_root(), unquote(bin)])
        case File.read(full_path) do
        match: { :ok, data }
          { :ok, data }
        else:
          format_error(404)
        end
      end
    end
  end

  # A 2-argument handler that also receives a query along with the path
  defmacro get(path, query, [do: code]) do
    quote do
      def handle(:get, unquote(path), unquote(query)) do
        unquote(code)
      end
    end
  end

  # POST request handler
  defmacro post(path, [do: code]) do
    # Disable hygiene so that `_data` is accessible in the client code
    quote hygiene: false do
      def handle(:post, unquote(path), _data) do
        unquote(code)
      end
    end
  end

  # Generic request handler
  defmacro multi_handle(path, blocks) do
    # Remove the entry for `:do` which is nil in this case
    blocks = Keyword.delete blocks, :do

    # Iterate over each block in `blocks` and produce a separate `handle`
    # clause for it
    Enum.map blocks, fn ->
    match: {:get, code}
      quote hygiene: false do
        def handle(:get, unquote(path), _query) do
          unquote(code)
        end
      end

    match: {:post, code}
      quote hygiene: false do
        def handle(:post, unquote(path), _data) do
          unquote(code)
        end
      end
    end
  end

  ###

  # Return { path, query } where `query` is an orddict.
  def split_path(path_with_query) do
    uri_info = URI.parse path_with_query
    { uri_info.path, URI.decode_query(uri_info.query || "") }
  end

  ###

  # Default catch-all handler for request not handled explicitly by the client
  # code
  defmacro default_handle(_) do
    quote do
      def handle(method, path, data // "")
      def handle(method, path, data) do
        # Allow only the listed methods
        if not (method in [:get, :post]) do
          format_error(400)

        # Path should always start with a slash (/)
        elsif: not match?("/" <> _, path)
          format_error(400)

        # Otherwise, the request is assumed to be valid but the requested
        # resource cannot be found
        else:
          format_error(404)
        end
      end
    end
  end

  ###

  # Return a { :error, <binary> } tuple with error description
  def format_error(code) do
    { :error, case code do
    match: 400
      "400 Bad Request"
    match: 404
      "404 Not Found"
    else:
      "503 Internal Server Error"
    end }
  end
end
