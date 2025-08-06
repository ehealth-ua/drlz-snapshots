defmodule DRLZ.Service do
  require Logger

  @page_bulk 100
  @endpoint (:application.get_env(:drlz, :endpoint, "https://drlz.info/api"))

  def verify(), do: {:ssl, [{:verify, :verify_none}]}

  def pages(url) do
      bearer = :application.get_env(:drlz, :bearer, '')
      accept = 'application/json'
      headers = [{'Authorization','Bearer ' ++ bearer},{'accept',accept}]
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
      headers = [{'Authorization','Bearer ' ++ bearer},{'accept',accept}]
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

  def readForm(form) do
      %{"pk" => pk, "ingredient" => ingredients} = form
      Enum.join(:lists.map(fn x -> %{"coding" => [%{"display" => display}]} = x
          "#{pk},#{display}\n" end, ingredients))
  end

  def readLicense(license) do
      %{"pk" => pk, "identifier" => %{"identifier" => [%{"value" => value}]}, "subject" => [%{"reference" => ref}],
        "validityPeriod" => %{"start" => start, "end" => finish}} = license
      pkg = String.replace(ref,"PackagedProductDefinition","package")
      pkg = String.replace(pkg,"MedicinalProductDefinition","product")
      "#{pk},#{value},#{pkg},#{start},#{finish}\n"
  end

  def unrollPackage([]) do [] end
  def unrollPackage([pkg]) do unrollPackage(pkg) end
  def unrollPackage(%{"containedItem" => item, "packaging" => []}) do item end
  def unrollPackage(%{"packaging" => packaging}) do unrollPackage(hd(packaging)) end

  def readPackage(pkg) do
      %{"pk" => pk,  "manufacturer" => manu_list, "packageFor" => [%{"reference" => product}], "packaging" => packaging} = pkg
      manu = case manu_list do
         [] -> ""
         mlist ->
           %{"manufacturer" => %{"reference" => r}} = hd(mlist)
           r
      end
      prod = String.replace(product, "MedicinalProductDefinition", "")
      man = String.replace(manu, "Organization", "")
      form = :lists.foldl(fn x,acc ->
           case unrollPackage(x) do [] -> acc
                 [item|_] -> %{"item" => %{"reference" => reference}} = item
                             [_,f] = String.split(reference,"/")
                             f
           end end, "", packaging)
      "#{pk},#{prod},#{form},#{man}\n"
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
       Enum.each(1..pgs, fn y ->
       recs = items("/fhir/medicinal-product", y, @page_bulk)
       Logger.warn("Page: #{y}/#{pgs}/#{length(recs)}")
       flat = :lists.foldl(fn x, acc ->
         acc <> readProduct(x)
       end, "", recs)
       writeFile(flat,"products") end)
  end

  def forms() do
      pgs = pages("/fhir/manufactured-items")
       Enum.each(1..pgs, fn y ->
       recs = items("/fhir/manufactured-items", y, 50)
       Logger.warn("Page: #{y}/#{pgs}/#{length(recs)}")
       flat = :lists.foldl(fn x, acc ->
         acc <> readForm(x)
       end, "", recs)
       writeFile(flat,"forms") end)
  end

  def packages() do
      pgs = pages("/fhir/package-medicinal-products")
       Enum.each(75..pgs, fn y ->
       recs = items("/fhir/package-medicinal-products", y, 20)
       Logger.warn("Page: #{y}/#{pgs}/#{length(recs)}")
       flat = :lists.foldl(fn x, acc ->
         acc <> readPackage(x)
       end, "", recs)
       writeFile(flat,"packages") end)
  end

  def licenses() do
      pgs = pages("/fhir/authorisations")
       Enum.each(1..pgs, fn y ->
       recs = items("/fhir/authorisations", y, 20)
       Logger.warn("Page: #{y}/#{pgs}/#{length(recs)}")
       flat = :lists.foldl(fn x, acc ->
         acc <> readLicense(x)
       end, "", recs)
       writeFile(flat,"licenses") end)
  end

end

