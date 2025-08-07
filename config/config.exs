import Config

config :drlz,
  load_on_start: false,
  bearer: 'eH7JS2WYTsNtRTxgUbWxHtaHTKAcWJEyhdaFokatRXdBJQaWQBlJQ33tNCd9IFp6646lRYZ3AzweH-_z8yu08THrXq5t5lKlZgUpRKr85bFxlnawTQRZnyYg1_mXtmS7yJte45SC5HzHo30h-ntW7miD65eHihrPx3Tyw3a6pik',
  logger_level: :info,
  logger: [{:handler, :default2, :logger_std_h,
            %{level: :debug,
              id: :synrc,
              max_size: 2000,
              module: :logger_std_h,
              config: %{type: :file, file: 'drlz.log'},
              formatter: {:logger_formatter,
                          %{template: [:time,' ',:pid,' ',:module,' ',:msg,'\n'],
                            single_line: true,}}}}]

