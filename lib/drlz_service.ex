defmodule DRLZ.Service do
  require Logger

  @page_bulk 100
  @endpoint (:application.get_env(:drlz, :endpoint, "https://drlz.info/api"))

  def verify(), do: {:ssl, [{:verify, :verify_none}]}

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

  def items(url, pageRequested, count) do
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

  def readOrganization(company) do
      %{"pk" => pk, "name" => name, "identifier" => ident , "type" => [%{"coding" => [%{"code" => type}]}]} = company
      [%{"display" => disp},%{"code" => code}] = ident
      "#{pk},#{code},#{disp},#{type},#{name}\n"
  end

  def readSubstance(molecule) do
      %{"name" => name, "identifier" => [%{"value" => code}]} = molecule
      "#{code},#{name}\n"
  end

  def readProduct(prod) do
      %{"pk" => pk, "identifier" => ident, "type" => %{"coding" => [%{"code" => code}]}, "name" => names} = prod
      [%{"value" => license}] = :lists.filter(fn %{"system" => sys} -> sys == "mpid" end, ident)
      Enum.join(:lists.map(fn x -> %{"productName" => name, "usage" => usage } = x
           %{"language" => %{"coding" => [%{"display" => country}]}} = hd(usage)
           "#{pk},#{license},#{code},#{country}-#{name}\n" end, names))
  end

  def ingredients()   do
      pgs = pages("/fhir/ingredients")
       Enum.each(1..pgs, fn y ->
       recs = items("/fhir/ingredients", y, @page_bulk)
       Logger.warn("Page: #{y}/#{pgs}/#{length(recs)}")
       flat = :lists.foldl(fn x, acc ->
         acc <> readIngredient(x)
       end, "", recs)
       writeFile(flat,"ingredients") end)
  end

  def organizations() do
      pgs = pages("/fhir/organization")
       Enum.each(1..pgs, fn y ->
       recs = items("/fhir/organization", y, @page_bulk)
       Logger.warn("Page: #{y}/#{pgs}/#{length(recs)}")
       flat = :lists.foldl(fn x, acc ->
         acc <> readOrganization(x)
       end, "", recs)
       writeFile(flat,"organizations") end)
  end

  def substances() do
      pgs = pages("/fhir/substance-definitions")
       Enum.each(1..pgs, fn y ->
       recs = items("/fhir/substance-definitions", y, @page_bulk)
       Logger.warn("Page: #{y}/#{pgs}/#{length(recs)}")
       flat = :lists.foldl(fn x, acc ->
         acc <> readSubstance(x)
       end, "", recs)
       writeFile(flat,"substances") end)
  end

  def products() do
      pgs = pages("/fhir/medicinal-product")
       Enum.each(156..pgs, fn y ->
       recs = items("/fhir/medicinal-product", y, @page_bulk)
       Logger.warn("Page: #{y}/#{pgs}/#{length(recs)}")
       flat = :lists.foldl(fn x, acc ->
         acc <> readProduct(x)
       end, "", recs)
       writeFile(flat,"products") end)
  end

end

