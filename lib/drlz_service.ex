defmodule DRLZ.Service do
  require Logger

  def verify(), do: {:ssl, [{:verify, :verify_none}]}
  def find(id, listOfMaps), do:
       :lists.flatten(
       :lists.map(fn x ->
           case :maps.get("id", x, []) do
                a when a == id -> x
                _ -> [] end end, listOfMaps))

  @page_bulk 100
  @endpoint (:application.get_env(:mrs, :endpoint, "https://drlz.info/api"))

  def pages(url) do
      bearer = :application.get_env(:drlz, :bearer, '')
      accept = 'application/json'
      headers = [{'Authorization',bearer},{'accept',accept}]
      address = '#{@endpoint}#{url}?page=1&limit=#{@page_bulk}'
      {:ok,{{_,status,_},_headers,body}} =
         :httpc.request(:get, {address, headers},
           [{:timeout,100000},verify()], [{:body_format,:binary}])
      case status do
           _ when status >= 100 and status < 200 -> :io.format 'WebSockets not supported: ~p', [body] ; 0
           _ when status >= 500 and status < 600 -> :io.format 'Fatal Error: ~p',              [body] ; 0
           _ when status >= 400 and status < 500 -> :io.format 'Resource not available: ~p',   [address] ; 0
           _ when status >= 300 and status < 400 -> :io.format 'Go away: ~p',                  [body] ; 0
           _ when status >= 200 and status < 300 ->
                  res     = :jsone.decode(body)
                  Map.get(res, "pages", 0)
      end
  end

  def reduceGet(url, pageRequested, count) do
      bearer = :application.get_env(:drlz, :bearer, '')
      accept = 'application/json'
      headers = [{'Authorization',bearer},{'accept',accept}]
      address = '#{@endpoint}#{url}?page=#{pageRequested}&limit=#{count}'
      {:ok,{{_,status,_},_headers,body}} =
         :httpc.request(:get, {address, headers},
           [{:timeout,100000},verify()], [{:body_format,:binary}])
      case status do
           _ when status >= 100 and status < 200 -> :io.format 'WebSockets not supported: ~p', [body] ; []
           _ when status >= 500 and status < 600 -> :io.format 'Fatal Error: ~p',              [body] ; []
           _ when status >= 400 and status < 500 -> :io.format 'Resource not available: ~p',   [address] ; []
           _ when status >= 300 and status < 400 -> :io.format 'Go away: ~p',                  [body] ; []
           _ when status >= 200 and status < 300 ->
                  res     = :jsone.decode(body)
                  Map.get(res, "items", [])
      end
  end

  def writeFile(record, name) do
      :file.write_file("priv/#{name}.csv", record, [:append, :raw, :binary])
      record
  end

  def readIngredient(inn) do
      %{"for" => references, "pk" => pk, "substance" => %{"coding" => [%{"code" => code, "display" => display, "system" => _system}]}} = inn
      man = Enum.join(Enum.map(references, & &1["reference"]), ",")
      man = String.replace(man, "ManufacturedItemDefinition", "")
      man = String.replace(man, "MedicinalProductDefinition", "")
      "#{pk},#{code},#{display},#{man}\n"
  end

  def registry(),      do: reduceGet("/registry/",                        1, 500)
  def changes(),       do: reduceGet("/registry/changes" ,                1, 500)
  def sku(),           do: reduceGet("/registry/sku",                     1, 1000)
  def packages(),      do: reduceGet("/dictionaries/packagetype",         1, 1000)
  def ingredients()   do
      pgs = pages("/fhir/ingredients")
       Enum.each(1..pgs, fn y ->
       recs = reduceGet("/fhir/ingredients", y, @page_bulk)
       Logger.warn("Page: #{y}/#{pgs}/#{length(recs)}")
       flat = :lists.foldl(fn x, acc ->
         acc <> readIngredient(x)
       end, "", recs)
       writeFile(flat,"ingredients") end)
  end
  def atc(),           do: reduceGet("/dictionaries/atc_codes",           1, 1000)
  def manufacturers(), do: reduceGet("/dictionaries/manufacturer",        1, 1000)
  def authholders(),   do: reduceGet("/dictionaries/authorizationholder", 1, 1000)

end

